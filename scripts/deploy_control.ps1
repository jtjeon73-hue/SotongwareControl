# 소통총관제 표준 운영 빌드·배포
# 사용법: .\scripts\deploy_control.ps1
#
# 필수: tool\deploy_control.local.ps1 (gitignore)
#   $AdminEmail = "..."
#   $AdminUid = "..."
# 선택: $FcmWebVapidKey = "..."  # 없으면 알림은 outbox_only로 유지
#
# 비밀번호는 스크립트에 넣지 마세요.
# dart-define 없는 flutter build web --release 만으로 운영 배포하지 마세요.

$ErrorActionPreference = "Stop"
# Flutter/Firebase may write info to stderr; do not treat native stderr as terminating.
$PSNativeCommandUseErrorActionPreference = $false
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

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

Write-Host "== Firebase project check =="
firebase use
$useOut = firebase use 2>&1 | Out-String
if ($useOut -notmatch "sotongware-control") {
  Write-Error "Firebase project must be sotongware-control. Aborting."
}

Write-Host "== flutter clean =="
flutter clean
Write-Host "== flutter pub get =="
flutter pub get
Write-Host "== dart format =="
dart format .
Write-Host "== flutter analyze =="
flutter analyze
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "== flutter test =="
flutter test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "== release build (admin email/UID via dart-define, quoted for PowerShell) =="
flutter build web --release --base-href / "--dart-define=SOTONG_ADMIN_AUTH_EMAIL=$AdminEmail" "--dart-define=SOTONG_ADMIN_UID=$AdminUid" "--dart-define=SOTONG_FCM_WEB_VAPID_KEY=$FcmWebVapidKey"
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

Write-Host "== firebase deploy hosting only =="
firebase deploy --only hosting --project sotongware-control
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Deploy finished: https://sotongware-control.web.app"
Write-Host "Verify login with display id 'sotongware' in a secret window."
