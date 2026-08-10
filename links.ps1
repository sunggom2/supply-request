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

# 한글은 터미널에서 두 칸을 차지한다. Length 로 폭을 재면 정렬이 어긋난다.
function Get-Width([string]$s) {
  $n = 0
  foreach ($c in $s.ToCharArray()) {
    $code = [int]$c
    if (($code -ge 0x1100 -and $code -le 0x115F) -or ($code -ge 0x2E80 -and $code -le 0xA4CF) -or
        ($code -ge 0xAC00 -and $code -le 0xD7A3) -or ($code -ge 0xF900 -and $code -le 0xFAFF) -or
        ($code -ge 0xFF00 -and $code -le 0xFF60)) { $n += 2 } else { $n += 1 }
  }
  return $n
}

$rows = @()
foreach ($m in [regex]::Matches($block, '"([a-z0-9\-]+)"\s*:\s*\[([^\]]*)\]')) {
  $slug = $m.Groups[1].Value
  $names = [regex]::Matches($m.Groups[2].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
  # all 은 7곳 전부라 이름을 그대로 이으면 줄이 너무 길어진다.
  $label = if ($slug -eq 'all') { '전 근무지 (교체 시 만료)' } else { ($names -join ' / ') }
  $rows += [pscustomobject]@{ 근무지 = $label; 링크 = ($base + '?w=' + $slug) }
}

# 관리자 주소는 슬롯 밖에 있어 주소를 교체해도 그대로 살아 있다.
# 그래서 회수가 불가능하다 — 남에게 주지 말고 ?w=all 을 줄 것.
$admin = Get-ChildItem -Path $root -Directory | Where-Object { $_.Name -match '^manage-' }
if ($admin.Count -eq 1) {
  $rows += [pscustomobject]@{
    근무지 = '관리자 (고정 · 공유 금지)'
    링크   = "https://$User.github.io/$Repo/$($admin[0].Name)/"
  }
}

$w = ($rows | ForEach-Object { Get-Width $_.근무지 } | Measure-Object -Maximum).Maximum
foreach ($r in $rows) {
  Write-Host ("  " + $r.근무지 + (' ' * ($w - (Get-Width $r.근무지))) + "  " + $r.링크)
}

Write-Host ""
Write-Host "리더에게는 자기 근무지 링크만 공유하세요." -ForegroundColor Yellow
Write-Host "주소를 교체한 뒤에는 이 스크립트를 다시 돌려 새 링크를 뽑아야 합니다." -ForegroundColor Yellow
Write-Host ""
