<#
  주소 교체 (리더 교체 시점마다 실행)

  하는 일:
    1. 슬롯 폴더 이름을 새 이름으로 바꾼다  → 옛 링크가 404가 된다
    2. 관리자 고정 주소가 새 슬롯을 가리키도록 갱신한다
    3. 커밋하고 GitHub에 올린다
    4. 실제로 반영될 때까지 기다렸다 확인한다
    5. 새 링크를 출력한다

  구글폼은 건드리지 않는다. 인증 코드도 그대로다.
  따라서 "조용한 실패" 위험이 없다.

  사용법:
    .\rotate.ps1                          이름 자동 생성
    .\rotate.ps1 -NewSlot 2026-4q-a1b2c3  이름 직접 지정
    .\rotate.ps1 -NoPush                  올리지 않고 로컬에서만 바꿔보기
#>
param(
  [string]$NewSlot,
  [string]$User = 'sunggom2',
  [string]$Repo = 'supply-request',
  [switch]$NoPush
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Fail($msg) { Write-Host ""; Write-Host "  $msg" -ForegroundColor Red; exit 1 }

# ── 현재 슬롯 찾기 ────────────────────────────────
$slots = Get-ChildItem -Path $root -Directory | Where-Object { $_.Name -match '^\d{4}-\dq-' }
if ($slots.Count -ne 1) { Fail "슬롯 폴더가 $($slots.Count)개입니다. 하나여야 합니다." }
$old = $slots[0].Name

# ── 새 이름 정하기 ────────────────────────────────
if (-not $NewSlot) {
  $now = Get-Date
  $q = [math]::Ceiling($now.Month / 3)
  $rand = -join ((1..6) | ForEach-Object { '0123456789abcdef'[(Get-Random -Max 16)] })
  $NewSlot = "{0}-{1}q-{2}" -f $now.Year, $q, $rand
}
if ($NewSlot -notmatch '^\d{4}-\dq-[0-9a-f]{6}$') { Fail "이름 형식이 맞지 않습니다: $NewSlot (예: 2026-4q-a1b2c3)" }
if ($NewSlot -eq $old) { Fail "새 이름이 현재 이름과 같습니다." }
if (Test-Path -LiteralPath (Join-Path $root $NewSlot)) { Fail "이미 있는 폴더입니다: $NewSlot" }

# 슬롯 밖에서 현재 슬롯을 가리키고 있는 고정 주소 페이지들(manage-*, staff-* …).
# 폴더 이름을 하드코딩하지 않고 내용으로 찾는다.
$stubs = Get-ChildItem -Path $root -Directory |
  Where-Object { $_.Name -ne $old } |
  ForEach-Object { Join-Path $_.FullName 'index.html' } |
  Where-Object { Test-Path -LiteralPath $_ } |
  Get-Item |
  Where-Object { [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8) -match '\.\./\d{4}-\dq-[0-9a-f]+/' }

if ($stubs.Count -lt 1) { Fail "고정 주소 페이지를 하나도 찾지 못했습니다." }

Write-Host ""
Write-Host "  $old  →  $NewSlot"
Write-Host ""

# ── 1. 폴더 이름 변경 ─────────────────────────────
& git -C $root mv $old $NewSlot
if ($LASTEXITCODE -ne 0) { Fail "폴더 이름 변경에 실패했습니다." }
Write-Host "  [1/5] 슬롯 폴더 이름 변경" -ForegroundColor Green

# ── 2. 고정 주소 stub 전부 갱신 ───────────────────
# 폴더 이름으로 찾지 않고 "슬롯 경로를 담고 있는 index.html"을 전부 찾는다.
# 나중에 고정 주소가 하나 더 늘어도 이 스크립트를 고칠 필요가 없다.
$done = @()
foreach ($p in $stubs) {
  $html = [System.IO.File]::ReadAllText($p.FullName, [System.Text.Encoding]::UTF8)
  $updated = [regex]::Replace($html, '\.\./\d{4}-\dq-[0-9a-f]+/', "../$NewSlot/")
  if ($updated -eq $html) { Fail "stub에서 슬롯 경로를 찾지 못했습니다: $($p.FullName)" }
  [System.IO.File]::WriteAllText($p.FullName, $updated, (New-Object System.Text.UTF8Encoding($false)))
  $done += $p.Directory.Name
}
Write-Host "  [2/5] 고정 주소 갱신 ($($done -join ', '))" -ForegroundColor Green

if ($NoPush) {
  Write-Host ""
  Write-Host "  -NoPush 지정: 커밋/업로드를 건너뜁니다." -ForegroundColor Yellow
  Write-Host "  되돌리려면:  git -C `"$root`" reset --hard" -ForegroundColor Yellow
  Write-Host "  되돌린 뒤 빈 폴더 $NewSlot 이 남으니 같이 지우세요." -ForegroundColor Yellow
  Write-Host "  고정 주소 페이지들도 확인하세요 — reset 은 커밋된 내용까지만 되돌립니다." -ForegroundColor Yellow
  Write-Host ""
  exit 0
}

# ── 3. 커밋 & 업로드 ──────────────────────────────
& git -C $root add -A
& git -C $root commit -m "Rotate request URL to $NewSlot" | Out-Null
if ($LASTEXITCODE -ne 0) { Fail "커밋에 실패했습니다." }
& git -C $root push origin main 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Fail "업로드에 실패했습니다. git -C `"$root`" push origin main 을 직접 실행해 보세요." }
Write-Host "  [3/5] 커밋 및 업로드 완료" -ForegroundColor Green

# ── 4. 반영 확인 ──────────────────────────────────
$base = "https://$User.github.io/$Repo/"
$newUrl = $base + $NewSlot + '/'
$oldUrl = $base + $old + '/'
$tmp = [System.IO.Path]::GetTempFileName()

function Get-Status([string]$u) {
  (& curl.exe -s -o $tmp -w '%{http_code}' $u | Out-String).Trim()
}

Write-Host "  [4/5] 반영 대기 중 (보통 1~2분)" -NoNewline
$ok = $false
foreach ($i in 1..30) {
  Start-Sleep -Seconds 10
  Write-Host "." -NoNewline
  if ((Get-Status $newUrl) -eq '200' -and (Get-Status $oldUrl) -eq '404') { $ok = $true; break }
}
Write-Host ""
Remove-Item $tmp -Force -ErrorAction SilentlyContinue
if (-not $ok) {
  Write-Host "  아직 반영되지 않았습니다. 몇 분 뒤 새 주소로 직접 접속해 확인하세요." -ForegroundColor Yellow
} else {
  Write-Host "  [5/5] 새 주소 살아있음, 옛 주소 404 확인" -ForegroundColor Green
}

# ── 5. 새 링크 출력 ───────────────────────────────
Write-Host ""
# links.ps1 이 고정 주소까지 함께 출력하므로 여기서 따로 찍지 않는다.
& (Join-Path $root 'links.ps1') -User $User -Repo $Repo
