# 소통총관제 표준 운영 빌드·배포
# 사용법:
#   .\scripts\deploy_control.ps1
#   .\scripts\deploy_control.ps1 -IncludeRelay
#   .\scripts\deploy_control.ps1 -PlanOnly
#   .\scripts\deploy_control.ps1 -IncludeRelay -PlanOnly
#
# 기본: Hosting only (기존 안전 경로)
# -IncludeRelay: Hosting + functions:sotong24Relay 만 (전체 functions 금지)
# -PlanOnly: preflight + 배포 대상 계획만 출력 (실제 build/deploy 안 함)
# formatting: repo-wide dart format는 운영 deploy 필수 gate가 아님 (CI/개발 품질 작업)
# mutating `dart format .` 금지 — firebase 직전 Final clean check 필수 (dirty면 publish 금지)
#
# 필수: tool\deploy_control.local.ps1 (gitignore) — PlanOnly가 아닐 때
#   $AdminEmail = "..."
#   $AdminUid = "..."
# 선택: $FcmWebVapidKey = "..."  # 없으면 알림은 outbox_only로 유지
#
# 비밀번호는 스크립트에 넣지 마세요.
# dart-define 없는 flutter build web --release 만으로 운영 배포하지 마세요.
# 직접 firebase deploy 임의 실행 금지 — 이 스크립트만 사용.

[CmdletBinding()]
param(
  [switch]$IncludeRelay,
  [switch]$PlanOnly
)

$ErrorActionPreference = "Stop"
# Flutter/Firebase may write info to stderr; do not treat native stderr as terminating.
$PSNativeCommandUseErrorActionPreference = $false
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

$RequiredFirebaseProject = "sotongware-control"
$ForbiddenFirebaseProject = "sotongware"
$RelayFunctionName = "sotong24Relay"
$ExpectedRelayOnlyTarget = "functions:sotong24Relay"

function Get-DeployOnlyTargets {
  param([switch]$WithRelay)
  if ($WithRelay) {
    return @("hosting", $ExpectedRelayOnlyTarget)
  }
  return @("hosting")
}

function Assert-CleanWorktree {
  param(
    [string]$Phase = "preflight"
  )
  $porcelain = git status --porcelain 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "git status failed — abort"
    exit 2
  }
  $lines = @($porcelain | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($lines.Count -gt 0) {
    Write-Host "dirty working tree — abort deploy ($Phase)"
    Write-Host "운영 배포는 clean worktree에서만 허용합니다. dirty=$($lines.Count)"
    Write-Host "changed files (diagnose only; no auto restore/reset/clean):"
    $lines | ForEach-Object { Write-Host "  $_" }
    exit 2
  }
}

function Assert-GitAlignedWithOriginMain {
  param([switch]$Strict)
  $branch = (git branch --show-current 2>$null).Trim()
  $head = (git rev-parse HEAD 2>$null).Trim()
  $origin = (git rev-parse origin/main 2>$null).Trim()
  if ([string]::IsNullOrWhiteSpace($head) -or [string]::IsNullOrWhiteSpace($origin)) {
    Write-Error "Unable to resolve HEAD/origin/main — abort deploy"
  }
  if ($head -ne $origin) {
    if ($Strict) {
      Write-Error "HEAD ($head) != origin/main ($origin) — abort deploy (push/merge first)"
    } else {
      Write-Warning "HEAD ($head) != origin/main ($origin) — PlanOnly continues"
    }
  }
  if (-not [string]::IsNullOrWhiteSpace($branch) -and $branch -ne "main") {
    Write-Warning "Current branch is '$branch' (not main)."
  }
  return [pscustomobject]@{
    Branch = $(if ($branch) { $branch } else { "(detached)" })
    Head = $head
    OriginMain = $origin
  }
}

function Assert-FirebaseProject {
  $useOut = firebase use 2>&1 | Out-String
  if ($useOut -match [regex]::Escape($ForbiddenFirebaseProject) -and $useOut -notmatch [regex]::Escape($RequiredFirebaseProject)) {
    Write-Error "Firebase project looks like '$ForbiddenFirebaseProject' (homepage). Aborting."
  }
  if ($useOut -notmatch [regex]::Escape($RequiredFirebaseProject)) {
    Write-Error "Firebase project must be $RequiredFirebaseProject. Aborting."
  }
  # .firebaserc default must also match
  $rcPath = Join-Path $Root ".firebaserc"
  if (Test-Path $rcPath) {
    $rc = Get-Content $rcPath -Raw
    if ($rc -notmatch [regex]::Escape($RequiredFirebaseProject)) {
      Write-Error ".firebaserc default project must be $RequiredFirebaseProject. Aborting."
    }
    if ($rc -match ('"' + [regex]::Escape($ForbiddenFirebaseProject) + '"')) {
      Write-Error ".firebaserc must not target homepage project $ForbiddenFirebaseProject. Aborting."
    }
  }
}

function Assert-RelayFunctionContract {
  $indexJs = Join-Path $Root "functions\index.js"
  if (-not (Test-Path $indexJs)) {
    Write-Error "functions/index.js missing — abort relay deploy"
  }
  $src = Get-Content $indexJs -Raw
  if ($src -notmatch ("exports\." + [regex]::Escape($RelayFunctionName) + "\s*=")) {
    Write-Error "Relay export '$RelayFunctionName' not found in functions/index.js — abort"
  }
  if ($ExpectedRelayOnlyTarget -ne ("functions:" + $RelayFunctionName)) {
    Write-Error "Internal relay target mismatch — abort"
  }
}

function Build-FirebaseDeployArgs {
  param([string[]]$OnlyTargets)
  foreach ($t in $OnlyTargets) {
    if ($t -eq "hosting") { continue }
    if ($t -ne $ExpectedRelayOnlyTarget) {
      Write-Error "Refusing non-allowlisted functions target: $t"
    }
  }
  $only = ($OnlyTargets -join ",")
  if ($only -notmatch "^hosting$" -and $only -notmatch "^hosting,functions:sotong24Relay$") {
    Write-Error "Deploy --only must be hosting or hosting,functions:sotong24Relay. Got: $only"
  }
  return @(
    "deploy",
    "--only", $only,
    "--project", $RequiredFirebaseProject
  )
}

Write-Host "== Preflight =="
Assert-CleanWorktree -Phase "preflight"
$gitInfo = Assert-GitAlignedWithOriginMain -Strict:(-not $PlanOnly)
Write-Host "git branch: $($gitInfo.Branch)"
Write-Host "git HEAD: $($gitInfo.Head)"
Write-Host "origin/main: $($gitInfo.OriginMain)"

Write-Host "== Firebase project check =="
firebase use
Assert-FirebaseProject

$onlyTargets = Get-DeployOnlyTargets -WithRelay:$IncludeRelay
if ($IncludeRelay) {
  Assert-RelayFunctionContract
}
$deployArgs = Build-FirebaseDeployArgs -OnlyTargets $onlyTargets
$onlyJoined = ($onlyTargets -join ",")

Write-Host "Deploy plan --only: $onlyJoined"
Write-Host "Deploy plan argv: firebase $($deployArgs -join ' ')"

if ($PlanOnly) {
  Write-Host "== PlanOnly: preflight PASS — skipping build/deploy =="
  Write-Host "PLAN_ONLY_TARGETS=$onlyJoined"
  exit 0
}

$LocalScript = Join-Path $Root "tool\deploy_control.local.ps1"
if (-not (Test-Path $LocalScript)) {
  Write-Error @"
관리자 인증 설정 누락 — 운영 빌드 중단

1) tool\deploy_control.example.ps1 을 tool\deploy_control.local.ps1 로 복사
2) AdminEmail / AdminUid 만 실제 값으로 설정 (비밀번호 금지)
3) 다시 .\scripts\deploy_control.ps1 실행
"@
}

# 로컬 파일에서 변수만 추출 (비밀번호 없는 파일)
$AdminEmail = $null
$AdminUid = $null
$FcmWebVapidKey = $null
Get-Content $LocalScript | ForEach-Object {
  if ($_ -match '^\s*\$AdminEmail\s*=\s*"([^"]+)"') { $AdminEmail = $Matches[1] }
  if ($_ -match '^\s*\$AdminUid\s*=\s*"([^"]+)"') { $AdminUid = $Matches[1] }
  if ($_ -match '^\s*\$FcmWebVapidKey\s*=\s*"([^"]+)"') { $FcmWebVapidKey = $Matches[1] }
}

if ([string]::IsNullOrWhiteSpace($AdminEmail) -or $AdminEmail -eq "YOUR_ADMIN_EMAIL_HERE") {
  Write-Error "관리자 인증 설정 누락 (AdminEmail) — 운영 빌드 중단"
}
if ([string]::IsNullOrWhiteSpace($AdminUid) -or $AdminUid -eq "YOUR_ADMIN_UID_HERE") {
  Write-Error "관리자 인증 설정 누락 (AdminUid) — 운영 빌드 중단"
}
$HasFcmWebVapidKey = -not [string]::IsNullOrWhiteSpace($FcmWebVapidKey) -and
  $FcmWebVapidKey -ne "YOUR_FCM_WEB_VAPID_KEY_HERE"
if (-not $HasFcmWebVapidKey) {
  $FcmWebVapidKey = ""
  Write-Warning "FCM Web VAPID 설정 없음 — Push 등록은 비활성화하고 outbox_only로 배포합니다."
}

if ($IncludeRelay) {
  Write-Host "== functions tests (relay contract) =="
  Push-Location (Join-Path $Root "functions")
  try {
    node --test test/*.test.js
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  } finally {
    Pop-Location
  }
}

Write-Host "== flutter clean =="
flutter clean
Write-Host "== flutter pub get =="
flutter pub get
Write-Host "== flutter analyze =="
flutter analyze
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "== flutter test =="
flutter test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "== release build (admin email/UID via dart-define, quoted for PowerShell) =="
# Flutter writes informational warnings to stderr (e.g. Wasm dry run). PowerShell
# 7+ can treat that as a terminating NativeCommandError even when exit code is 0.
$GitSha = (git rev-parse --short HEAD 2>$null)
if ([string]::IsNullOrWhiteSpace($GitSha)) { $GitSha = "unknown" }
$kst = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::UtcNow, 'Korea Standard Time')
$BuiltAt = $kst.ToString('yyyy-MM-dd HH:mm') + ' KST'
Write-Host "BuiltAt dart-define: $BuiltAt"
$buildArgs = @(
  'build', 'web', '--release', '--base-href', '/',
  "--dart-define=SOTONG_ADMIN_AUTH_EMAIL=$AdminEmail",
  "--dart-define=SOTONG_ADMIN_UID=$AdminUid",
  "--dart-define=SOTONG_FCM_WEB_VAPID_KEY=$FcmWebVapidKey",
  "--dart-define=SOTONG_GIT_SHA=$GitSha",
  "--dart-define=SOTONG_BUILT_AT=$BuiltAt"
)
& flutter @buildArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

python -c @"
from pathlib import Path
html = Path('build/web/index.html').read_text(encoding='utf-8')
js = Path('build/web/main.dart.js').read_text(encoding='utf-8', errors='ignore')
email = '''$AdminEmail'''
uid = '''$AdminUid'''
vapid = '''$FcmWebVapidKey'''
double_quoted_base = 'base href=' + chr(34) + '/' + chr(34)
single_quoted_base = 'base href=' + chr(39) + '/' + chr(39)
print('base_href_ok', double_quoted_base in html or single_quoted_base in html)
print('admin_email_configured', email in js and len(email.strip()) > 0)
print('admin_uid_configured', uid in js and len(uid.strip()) > 0)
print('fcm_vapid_configured', len(vapid.strip()) > 0 and vapid in js)
if email not in js or uid not in js:
    raise SystemExit('Required admin dart-define missing from build output — abort deploy')
"@
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Fail-closed: validation/build must not leave tracked source dirty before publish.
Write-Host "== Final clean check (pre-firebase) =="
Assert-CleanWorktree -Phase "final-pre-deploy"

Write-Host "== firebase deploy ($onlyJoined) =="
& firebase @deployArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Deploy finished: https://sotongware-control.web.app"
if ($IncludeRelay) {
  Write-Host "Relay function: $RelayFunctionName (only)"
}
Write-Host "Verify login with display id 'sotongware' in a secret window."
