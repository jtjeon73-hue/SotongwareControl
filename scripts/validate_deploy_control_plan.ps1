# deploy_control.ps1 PlanOnly / fail-closed 검증 (실제 firebase deploy 금지)
# 사용법: .\scripts\validate_deploy_control_plan.ps1
$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

$scriptPath = Join-Path $PSScriptRoot "deploy_control.ps1"
$failures = @()

function Assert-True($cond, $msg) {
  if (-not $cond) { throw "ASSERT_FAIL: $msg" }
}

Write-Host "== 1) PowerShell parse =="
$tokens = $null
$errs = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
  $scriptPath,
  [ref]$tokens,
  [ref]$errs
)
if ($null -eq $ast) { throw "Parse returned null AST" }
if ($errs -and $errs.Count -gt 0) {
  throw "Parse errors: $($errs | ForEach-Object { $_.Message } | Out-String)"
}
Write-Host "syntax PASS"

Write-Host "== 2) Hosting-only PlanOnly =="
$hostingOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -PlanOnly 2>&1 | Out-String
Assert-True ($LASTEXITCODE -eq 0) "Hosting-only PlanOnly exit 0"
Assert-True ($hostingOut -match "PLAN_ONLY_TARGETS=hosting") "Hosting-only targets"
Assert-True ($hostingOut -notmatch "functions:") "Hosting-only must not include functions"
Assert-True ($hostingOut -match "sotongware-control") "project check"
Write-Host "Hosting-only regression PASS"

Write-Host "== 3) IncludeRelay PlanOnly =="
$relayOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -IncludeRelay -PlanOnly 2>&1 | Out-String
Assert-True ($LASTEXITCODE -eq 0) "IncludeRelay PlanOnly exit 0"
Assert-True ($relayOut -match "PLAN_ONLY_TARGETS=hosting,functions:sotong24Relay") "IncludeRelay targets exact"
Assert-True ($relayOut -notmatch "functions:api") "Must not include api"
Assert-True ($relayOut -notmatch "functions:study") "Must not include study*"
Write-Host "IncludeRelay plan PASS"

Write-Host "== 4) fail-closed helpers (inline) =="
# Dot-source is hard for param scripts; re-check source contracts instead.
$src = Get-Content $scriptPath -Raw
Assert-True ($src -match 'RequiredFirebaseProject = "sotongware-control"') "project constant"
Assert-True ($src -match 'ForbiddenFirebaseProject = "sotongware"') "forbidden homepage"
Assert-True ($src -match 'RelayFunctionName = "sotong24Relay"') "relay name"
Assert-True ($src -match 'Assert-CleanWorktree') "dirty tree gate"
Assert-True ($src -match 'hosting,functions:sotong24Relay') "allowlisted only join"
Assert-True ($src -notmatch 'firebase deploy --only functions\b(?!:sotong24Relay)') "no bare functions deploy"
Write-Host "fail-closed source PASS"

Write-Host "== 5) dirty tree gate (simulation via porcelain check function) =="
$porcelain = git status --porcelain
if ($porcelain) {
  throw "This validation must run on a clean worktree; found dirty files"
}
Write-Host "clean worktree confirmed PASS"

Write-Host "== 6) dirty tree fail-closed (temp marker) =="
$marker = Join-Path $Root "tmp_dirty_marker.txt"
Set-Content -Path $marker -Value "dirty-test"
try {
  $dirtyOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -PlanOnly 2>&1 | Out-String
  $dirtyCode = $LASTEXITCODE
  Assert-True ($dirtyCode -ne 0) "dirty tree must non-zero exit"
  Assert-True ($dirtyOut -match "dirty working tree") "dirty tree error message"
  Write-Host "dirty fail-closed PASS"
} finally {
  if (Test-Path $marker) { Remove-Item $marker -Force }
}
Assert-True (-not (Test-Path $marker)) "marker removed"
Assert-True (-not (git status --porcelain)) "worktree clean after dirty test"

Write-Host "ALL validate_deploy_control_plan checks PASS"
