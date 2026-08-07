<#
  근무지별 공유 링크 생성

  슬롯 폴더명과 SITES 목록을 페이지에서 직접 읽어 링크를 만든다.
  주소를 교체(슬롯 폴더명 변경)한 뒤 이 스크립트를 다시 돌려
  나온 링크를 각 근무지 리더에게 공유하면 된다.

  사용법:
    .\links.ps1 -User 깃허브아이디
    .\links.ps1 -User 깃허브아이디 -Repo supply-request
#>
param(
  [Parameter(Mandatory = $true)][string]$User,
  [string]$Repo = 'supply-request',
  [string]$Slot
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
$html = [System.IO.File]::ReadAllText($page, [System.Text.Encoding]::UTF8)

if ($html -notmatch '(?s)var\s+SITES\s*=\s*\{(.*?)\};') { throw "SITES 목록을 찾지 못했습니다: $page" }
$block = $matches[1]

$base = "https://$User.github.io/$Repo/$Slot/"

Write-Host ""
Write-Host "슬롯: $Slot"
Write-Host ""

$rows = @()
foreach ($m in [regex]::Matches($block, '"([a-z0-9\-]+)"\s*:\s*\[([^\]]*)\]')) {
  $slug = $m.Groups[1].Value
  $names = [regex]::Matches($m.Groups[2].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
  $rows += [pscustomobject]@{ 근무지 = ($names -join ' / '); 링크 = ($base + '?w=' + $slug) }
}
$rows += [pscustomobject]@{ 근무지 = '(관리자 · 전체 선택)'; 링크 = $base }

$w = ($rows.근무지 | Measure-Object -Property Length -Maximum).Maximum
foreach ($r in $rows) { Write-Host ("  {0,-$w}  {1}" -f $r.근무지, $r.링크) }

Write-Host ""
Write-Host "리더에게는 자기 근무지 링크만 공유하세요." -ForegroundColor Yellow
Write-Host "주소를 교체한 뒤에는 이 스크립트를 다시 돌려 새 링크를 뽑아야 합니다." -ForegroundColor Yellow
Write-Host ""
