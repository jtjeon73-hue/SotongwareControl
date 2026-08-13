# 예시: Relay secret을 Firebase Secret Manager에 설정 (로컬 전용)
# 사용법:
#   1) 이 파일을 tool/set_relay_secret.local.ps1 로 복사
#   2) 아래 SecretFile 경로를 본인 로컬 경로로 수정 (repo 밖 권장)
#   3) .\tool\set_relay_secret.local.ps1 실행
#
# 주의: secret 평문을 이 파일에 직접 넣지 마세요. *.local.ps1 은 gitignore 대상입니다.

$ErrorActionPreference = "Stop"
$Project = "sotongware-control"
$SecretFile = Join-Path $env:LOCALAPPDATA "SotongWareControl\sotong24_relay_secret.txt"

if (-not (Test-Path $SecretFile)) {
  Write-Error "Secret file not found: $SecretFile"
}

Get-Content $SecretFile -Raw | firebase functions:secrets:set SOTONG24_RELAY_SECRET --project $Project
Write-Host "Secret set requested for project $Project (value not printed)."
