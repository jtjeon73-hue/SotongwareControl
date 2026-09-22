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

Write-Host "== 3b) IncludeApi PlanOnly =="
$apiOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -IncludeApi -PlanOnly 2>&1 | Out-String
Assert-True ($LASTEXITCODE -eq 0) "IncludeApi PlanOnly exit 0"
Assert-True ($apiOut -match "PLAN_ONLY_TARGETS=hosting,functions:api") "IncludeApi targets exact"
Assert-True ($apiOut -notmatch "functions:sotong24Relay") "IncludeApi must not include relay"
Assert-True ($apiOut -notmatch "functions:study") "Must not include study*"
Write-Host "IncludeApi plan PASS"

Write-Host "== 3c) IncludeRelay+IncludeApi fail-closed =="
$bothOutPath = Join-Path $env:TEMP "sotong_both_flags_out.txt"
$bothErrPath = Join-Path $env:TEMP "sotong_both_flags_err.txt"
try {
  $bothProc = Start-Process -FilePath "powershell" -ArgumentList @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptPath,
    "-IncludeRelay", "-IncludeApi", "-PlanOnly"
  ) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $bothOutPath -RedirectStandardError $bothErrPath
  $bothOut = ((Get-Content $bothOutPath -Raw -ErrorAction SilentlyContinue) + "`n" +
    (Get-Content $bothErrPath -Raw -ErrorAction SilentlyContinue))
  Assert-True ($bothProc.ExitCode -ne 0) "Relay+Api together must non-zero exit"
  Assert-True (
    ($bothOut -match "Refusing -IncludeRelay and -IncludeApi together") -or
    ($bothOut -match "IncludeRelay and -IncludeApi")
  ) ("combined flags rejected; exit=$($bothProc.ExitCode); out=$bothOut")
  Write-Host "Relay+Api rejection PASS"
} finally {
  foreach ($f in @($bothOutPath, $bothErrPath)) {
    if (Test-Path $f) { Remove-Item $f -Force }
  }
}

Write-Host "== 4) fail-closed helpers (inline) =="
# Dot-source is hard for param scripts; re-check source contracts instead.
$src = Get-Content $scriptPath -Raw
Assert-True ($src -match 'RequiredFirebaseProject = "sotongware-control"') "project constant"
Assert-True ($src -match 'ForbiddenFirebaseProject = "sotongware"') "forbidden homepage"
Assert-True ($src -match 'RelayFunctionName = "sotong24Relay"') "relay name"
Assert-True ($src -match 'ApiFunctionName = "api"') "api name"
Assert-True ($src -match 'ExpectedApiOnlyTarget = "functions:api"') "api target constant"
Assert-True ($src -match 'Assert-ApiFunctionContract') "api export preflight"
Assert-True ($src -match 'Assert-CleanWorktree') "dirty tree gate"
Assert-True ($src -match 'hosting,functions:sotong24Relay') "allowlisted relay join"
Assert-True ($src -match 'hosting,functions:api') "allowlisted api join"
Assert-True ($src -match 'Refusing non-allowlisted functions target') "unknown functions target fail-closed"
Assert-True ($src -notmatch 'firebase deploy --only functions\b(?!:)') "no bare functions deploy"
Assert-True ($src -notmatch '(?m)^\s*dart format\b') "no dart format gate in release script"
Assert-True ($src -match '(?m)^\s*flutter analyze\s*$') "analyze retained"
Assert-True ($src -match '(?m)^\s*flutter test\s*$') "test retained"
Assert-True ($src -match "flutter @buildArgs") "build retained"
Assert-True ($src -match 'Final clean check \(pre-firebase\)') "final clean guard present"
# Final clean must appear before firebase invoke
$finalIdx = $src.IndexOf('Final clean check (pre-firebase)')
$fbIdx = $src.IndexOf('& firebase @deployArgs')
Assert-True ($finalIdx -ge 0 -and $fbIdx -gt $finalIdx) "final clean before firebase deploy"
Write-Host "fail-closed source PASS"

Write-Host "== 5) dirty tree gate (simulation via porcelain check function) =="
$porcelain = git status --porcelain
if ($porcelain) {
  throw "This validation must run on a clean worktree; found dirty files"
}
Write-Host "clean worktree confirmed PASS"

Write-Host "== 6) dirty tree fail-closed (temp marker / initial preflight) =="
$marker = Join-Path $Root "tmp_dirty_marker.txt"
Set-Content -Path $marker -Value "dirty-test"
try {
  $p = Start-Process -FilePath "powershell" -ArgumentList @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptPath, "-PlanOnly"
  ) -Wait -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $Root "tmp_plan_out.txt") -RedirectStandardError (Join-Path $Root "tmp_plan_err.txt")
  $dirtyOut = ((Get-Content (Join-Path $Root "tmp_plan_out.txt") -Raw -ErrorAction SilentlyContinue) + "`n" +
    (Get-Content (Join-Path $Root "tmp_plan_err.txt") -Raw -ErrorAction SilentlyContinue))
  Assert-True ($p.ExitCode -ne 0) "dirty tree must non-zero exit"
  Assert-True ($dirtyOut -match "dirty working tree") "dirty tree error message"
  Write-Host "dirty fail-closed PASS"
} finally {
  foreach ($f in @($marker, (Join-Path $Root "tmp_plan_out.txt"), (Join-Path $Root "tmp_plan_err.txt"))) {
    if (Test-Path $f) { Remove-Item $f -Force }
  }
}
Assert-True (-not (Test-Path $marker)) "marker removed"
Assert-True (-not (git status --porcelain)) "worktree clean after dirty test"

Write-Host "== 7) repo-wide format is not a release gate =="
Assert-True ($src -notmatch 'set-exit-if-changed') "check-only format gate removed"
Assert-True ($src -notmatch '(?m)^\s*dart format \.\s*$') "mutating dart format . absent"
Write-Host "format-not-a-gate PASS"

Write-Host "== 8) final clean gate blocks publish when dirty (logic harness) =="
# Replicate Assert-CleanWorktree final-pre-deploy: dirty => non-zero, no firebase.
$finalMarker = Join-Path $Root "tmp_final_dirty_marker.txt"
Set-Content -Path $finalMarker -Value "simulate-post-validation-dirty"
try {
  $harness = @'
$ErrorActionPreference = "Stop"
Set-Location $env:SOTONG_VALIDATE_ROOT
function Assert-CleanWorktree {
  param([string]$Phase = "preflight")
  $porcelain = git status --porcelain 2>$null
  if ($LASTEXITCODE -ne 0) { Write-Host "git status failed"; exit 2 }
  $lines = @($porcelain | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($lines.Count -gt 0) {
    Write-Host "dirty working tree — abort deploy ($Phase)"
    Write-Host "changed files (diagnose only; no auto restore/reset/clean):"
    $lines | ForEach-Object { Write-Host "  $_" }
    exit 2
  }
}
Write-Host "== Final clean check (pre-firebase) =="
Assert-CleanWorktree -Phase "final-pre-deploy"
Write-Host "REACHED_FIREBASE_DEPLOY"
exit 0
'@
  $harnessPath = Join-Path $Root "tmp_final_clean_harness.ps1"
  Set-Content -Path $harnessPath -Value $harness -Encoding UTF8
  $env:SOTONG_VALIDATE_ROOT = $Root
  $hout = & powershell -NoProfile -ExecutionPolicy Bypass -File $harnessPath 2>&1 | Out-String
  $hcode = $LASTEXITCODE
  Assert-True ($hcode -ne 0) "final clean must non-zero when dirty"
  Assert-True ($hout -match "final-pre-deploy") "final phase label"
  Assert-True ($hout -match "dirty working tree") "final dirty message"
  Assert-True ($hout -notmatch "REACHED_FIREBASE_DEPLOY") "must not reach firebase after dirty final check"
  Write-Host "final clean blocks publish PASS"
} finally {
  Remove-Item Env:SOTONG_VALIDATE_ROOT -ErrorAction SilentlyContinue
  foreach ($f in @(
    $finalMarker,
    (Join-Path $Root "tmp_final_clean_harness.ps1")
  )) {
    if (Test-Path $f) { Remove-Item $f -Force }
  }
}
Assert-True (-not (git status --porcelain)) "worktree clean after final-clean harness"

Write-Host "ALL validate_deploy_control_plan checks PASS"
