# 소통총관제 Firebase Hosting 배포 예제
# 사용법:
# 1) 이 파일을 tool/deploy_control.local.ps1 로 복사
# 2) 아래 이메일/UID만 실제 값으로 수정 (비밀번호는 넣지 마세요)
# 3) .\tool\deploy_control.local.ps1 실행
#
# PowerShell에서 이메일 @ 기호가 깨지지 않도록 dart-define 값은 반드시 따옴표로 감쌉니다.

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$AdminEmail = "YOUR_ADMIN_EMAIL_HERE"
$AdminUid = "YOUR_ADMIN_UID_HERE"

if ([string]::IsNullOrWhiteSpace($AdminEmail) -or $AdminEmail -eq "YOUR_ADMIN_EMAIL_HERE") {
  Write-Error "Admin email is not configured in deploy_control.local.ps1"
}
if ([string]::IsNullOrWhiteSpace($AdminUid) -or $AdminUid -eq "YOUR_ADMIN_UID_HERE") {
  Write-Error "Admin UID is not configured in deploy_control.local.ps1"
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

Write-Host "== release build (admin email/UID via dart-define) =="
flutter build web --release --base-href / "--dart-define=SOTONG_ADMIN_AUTH_EMAIL=$AdminEmail" "--dart-define=SOTONG_ADMIN_UID=$AdminUid"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

python -c @"
from pathlib import Path
html = Path('build/web/index.html').read_text(encoding='utf-8')
js = Path('build/web/main.dart.js').read_text(encoding='utf-8', errors='ignore')
email = '''$AdminEmail'''
uid = '''$AdminUid'''
print('base_href_ok', 'base href=\"/\"' in html or \"base href='/'\" in html)
print('admin_email_configured', email in js and len(email.strip()) > 0)
print('admin_uid_configured', uid in js and len(uid.strip()) > 0)
"@

Write-Host "== firebase deploy =="
firebase deploy --only hosting --project sotongware-control
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Deploy finished: https://sotongware-control.web.app"
Write-Host "Open a secret window and verify login with id 'sotongware'."
Write-Host ""
Write-Host "TIP: Prefer .\scripts\deploy_control.ps1 as the standard ops deploy."
