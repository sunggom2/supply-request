<#
  비품 신청 페이지 검증 스크립트

  인증 코드를 새로 넣거나 바꾼 뒤 반드시 실행할 것.

  왜 필요한가:
  페이지는 no-cors 방식으로 전송하기 때문에 구글이 400으로 거부해도
  그 사실을 알 수 없다. 리더 화면에는 "접수됐어요"가 그대로 뜬다.
  폼의 정규식과 페이지의 ACCESS_CODE가 어긋나면 신청이 전부 조용히
  사라지므로, 사람이 대신 확인해 주는 것이 이 스크립트다.

  사용법:
    .\verify.ps1          잠금 확인만 (시트에 아무것도 안 쌓임)
    .\verify.ps1 -Live    실제 신청까지 확인 (시트에 테스트 행 1개 생김)
#>
param(
  [string]$Slot,
  [switch]$Live
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $Slot) {
  $found = Get-ChildItem -Path $root -Directory | Where-Object { $_.Name -match '^\d{4}-\dq-' }
  if ($found.Count -ne 1) {
    throw "슬롯 폴더를 자동으로 찾지 못했습니다 ($($found.Count)개 발견). -Slot 으로 지정하세요."
  }
  $Slot = $found[0].Name
}

$page = Join-Path $root (Join-Path $Slot 'index.html')
if (-not (Test-Path -LiteralPath $page)) { throw "페이지를 찾을 수 없습니다: $page" }
$html = [System.IO.File]::ReadAllText($page, [System.Text.Encoding]::UTF8)

function Get-Const([string]$name) {
  if ($html -match ('var\s+' + $name + '\s*=\s*"([^"]*)"')) { return $matches[1] }
  return ''
}
$endpoint = Get-Const 'ENDPOINT'
$eRegion  = Get-Const 'ENTRY_REGION'
$eItems   = Get-Const 'ENTRY_ITEMS'
$eCode    = Get-Const 'ENTRY_CODE'
$code     = Get-Const 'ACCESS_CODE'

Write-Host ""
Write-Host "슬롯      : $Slot"
Write-Host "근무지역  : $eRegion"
Write-Host "요청물품  : $eItems"
if ($eCode -and $code) { Write-Host "인증코드  : $eCode = $code" }
else { Write-Host "인증코드  : (미설정 - 폼 잠금이 꺼져 있습니다)" -ForegroundColor Yellow }
Write-Host ""

function Invoke-Case([string]$label, [string[]]$pairs, [int]$expect, [string]$why) {
  $enc = ($pairs | ForEach-Object {
    $kv = $_ -split '=', 2
    [System.Uri]::EscapeDataString($kv[0]) + '=' + [System.Uri]::EscapeDataString($kv[1])
  }) -join '&'

  $tmp = [System.IO.Path]::GetTempFileName()
  $status = & curl.exe -s -o $tmp -w '%{http_code}' -X POST $endpoint `
              --data-raw $enc -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8'
  Remove-Item $tmp -Force -ErrorAction SilentlyContinue

  $ok = ([int]$status -eq $expect)
  $mark = if ($ok) { '통과' } else { '실패' }
  $color = if ($ok) { 'Green' } else { 'Red' }
  Write-Host ("  [{0}] {1,-16} HTTP {2} (기대 {3})" -f $mark, $label, $status, $expect) -ForegroundColor $color
  if (-not $ok) { Write-Host ("         → " + $why) -ForegroundColor Red }
  return $ok
}

$results = @()

if ($eCode -and $code) {
  Write-Host "잠금 확인 (행이 생기지 않아야 정상)"
  $results += Invoke-Case '코드 없음' @("$eRegion=서관 2", "$eItems=페이퍼 타올") 400 `
    '인증 코드 없이도 접수됩니다. 폼에서 인증 코드 질문이 필수인지 확인하세요.'
  $results += Invoke-Case '틀린 코드' @("$eRegion=서관 2", "$eItems=페이퍼 타올", "$eCode=WRONG-CODE-XX") 400 `
    '아무 코드나 통과합니다. 폼의 응답 확인이 정규식 "일치"인지 확인하세요.'
} else {
  Write-Host "인증 코드가 설정되지 않아 잠금 확인을 건너뜁니다." -ForegroundColor Yellow
}

Write-Host ""
if ($Live) {
  Write-Host "실제 신청 확인 (시트에 테스트 행이 1개 생깁니다)"
  $pairs = @("$eRegion=서관 2", "$eItems=페이퍼 타올")
  if ($eCode -and $code) { $pairs += "$eCode=$code" }
  $results += Invoke-Case '정상 신청' $pairs 200 `
    '정상 신청이 거부됩니다. 페이지의 ACCESS_CODE와 폼의 정규식이 어긋났습니다.'
  Write-Host ""
  Write-Host "  시트 '메인' 탭에 생긴 테스트 행(서관 2 / 페이퍼 타올)을 지우세요." -ForegroundColor Yellow
  Write-Host "  텔레그램 알림도 발송됩니다." -ForegroundColor Yellow
} else {
  Write-Host "정상 신청 확인은 건너뛰었습니다. 전체 확인은 -Live 를 붙여 실행하세요." -ForegroundColor Yellow
}

Write-Host ""
if ($results -contains $false) {
  Write-Host "실패한 항목이 있습니다. 리더에게 새 주소를 공유하지 마세요." -ForegroundColor Red
  exit 1
}
Write-Host "모두 통과했습니다." -ForegroundColor Green
