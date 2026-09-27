# deploy_control.ps1 Include* target selection regression (no firebase deploy)
# Usage: .\scripts\test_deploy_control_targets.ps1
$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$scriptPath = Join-Path $PSScriptRoot "deploy_control.ps1"

function Assert-True($cond, $msg) {
  if (-not $cond) { throw "ASSERT_FAIL: $msg" }
}

$src = Get-Content $scriptPath -Raw

Write-Host "== A/B/C/D source contracts =="
Assert-True ($src -match '\[switch\]\$IncludeMonitorStageHealth') "param IncludeMonitorStageHealth"
Assert-True ($src -match 'MonitorStageHealthFunctionName = "monitorStageHealth"') "monitor function name"
Assert-True ($src -match 'ExpectedMonitorStageHealthOnlyTarget = "functions:monitorStageHealth"') "monitor target"
Assert-True ($src -match 'Assert-MonitorStageHealthFunctionContract') "monitor contract"
Assert-True ($src -match 'hosting,functions:monitorStageHealth') "allowlisted join"
Assert-True ($src -match 'Refusing multiple -Include\* functions flags together') "multi-include refuse"
Assert-True ($src -match 'PLAN_ONLY_TARGETS=\$onlyJoined') "PlanOnly prints targets"
Write-Host "source contracts PASS"

# Isolated copy of Get-DeployOnlyTargets (must stay in sync with deploy_control.ps1).
$ExpectedRelayOnlyTarget = "functions:sotong24Relay"
$ExpectedApiOnlyTarget = "functions:api"
$ExpectedMonitorStageHealthOnlyTarget = "functions:monitorStageHealth"

function Get-DeployOnlyTargets {
  param(
    [switch]$WithRelay,
    [switch]$WithApi,
    [switch]$WithMonitorStageHealth
  )
  $includeCount = 0
  if ($WithRelay) { $includeCount++ }
  if ($WithApi) { $includeCount++ }
  if ($WithMonitorStageHealth) { $includeCount++ }
  if ($includeCount -gt 1) {
    Write-Host "Refusing multiple -Include* functions flags together - deploy one functions target per run"
    exit 2
  }
  if ($WithRelay) {
    return @("hosting", $ExpectedRelayOnlyTarget)
  }
  if ($WithApi) {
    return @("hosting", $ExpectedApiOnlyTarget)
  }
  if ($WithMonitorStageHealth) {
    return @("hosting", $ExpectedMonitorStageHealthOnlyTarget)
  }
  return @("hosting")
}

function Build-FirebaseDeployArgs {
  param([string[]]$OnlyTargets)
  $AllowedFunctionsTargets = @(
    $ExpectedRelayOnlyTarget,
    $ExpectedApiOnlyTarget,
    $ExpectedMonitorStageHealthOnlyTarget
  )
  foreach ($t in $OnlyTargets) {
    if ($t -eq "hosting") { continue }
    if ($AllowedFunctionsTargets -notcontains $t) {
      throw "Refusing non-allowlisted functions target: $t"
    }
  }
  $only = ($OnlyTargets -join ",")
  if (
    $only -ne "hosting" -and
    $only -ne "hosting,functions:sotong24Relay" -and
    $only -ne "hosting,functions:api" -and
    $only -ne "hosting,functions:monitorStageHealth"
  ) {
    throw "Deploy --only must be hosting, hosting,functions:sotong24Relay, hosting,functions:api, or hosting,functions:monitorStageHealth. Got: $only"
  }
  return @(
    "deploy",
    "--only", $only,
    "--project", "sotongware-control"
  )
}

Write-Host "== A default → hosting =="
$a = (Get-DeployOnlyTargets) -join ","
Assert-True ($a -eq "hosting") "A default hosting"
$aArgs = Build-FirebaseDeployArgs -OnlyTargets @("hosting")
Assert-True (($aArgs -join " ") -eq "deploy --only hosting --project sotongware-control") "A argv"
Write-Host "A PASS"

Write-Host "== B IncludeRelay =="
$b = (Get-DeployOnlyTargets -WithRelay) -join ","
Assert-True ($b -eq "hosting,functions:sotong24Relay") "B relay"
Write-Host "B PASS"

Write-Host "== C IncludeApi =="
$c = (Get-DeployOnlyTargets -WithApi) -join ","
Assert-True ($c -eq "hosting,functions:api") "C api"
Write-Host "C PASS"

Write-Host "== D IncludeMonitorStageHealth =="
$d = (Get-DeployOnlyTargets -WithMonitorStageHealth) -join ","
Assert-True ($d -eq "hosting,functions:monitorStageHealth") "D monitor"
$dArgs = Build-FirebaseDeployArgs -OnlyTargets @("hosting", "functions:monitorStageHealth")
Assert-True (($dArgs -join " ") -eq "deploy --only hosting,functions:monitorStageHealth --project sotongware-control") "D argv"
Write-Host "D PASS"

Write-Host "== E forbidden combinations fail-closed =="
$combos = @(
  @{ Name = "Relay+Api"; Args = "-WithRelay -WithApi" },
  @{ Name = "Api+Monitor"; Args = "-WithApi -WithMonitorStageHealth" },
  @{ Name = "Relay+Monitor"; Args = "-WithRelay -WithMonitorStageHealth" },
  @{ Name = "AllThree"; Args = "-WithRelay -WithApi -WithMonitorStageHealth" }
)
foreach ($combo in $combos) {
  $outPath = Join-Path $env:TEMP ("sotong_target_" + $combo.Name + "_out.txt")
  $errPath = Join-Path $env:TEMP ("sotong_target_" + $combo.Name + "_err.txt")
  $harness = @"
`$ErrorActionPreference = 'Stop'
`$ExpectedRelayOnlyTarget = 'functions:sotong24Relay'
`$ExpectedApiOnlyTarget = 'functions:api'
`$ExpectedMonitorStageHealthOnlyTarget = 'functions:monitorStageHealth'
function Get-DeployOnlyTargets {
  param([switch]`$WithRelay,[switch]`$WithApi,[switch]`$WithMonitorStageHealth)
  `$includeCount = 0
  if (`$WithRelay) { `$includeCount++ }
  if (`$WithApi) { `$includeCount++ }
  if (`$WithMonitorStageHealth) { `$includeCount++ }
  if (`$includeCount -gt 1) {
    Write-Host 'Refusing multiple -Include* functions flags together - deploy one functions target per run'
    exit 2
  }
  return @('hosting')
}
Get-DeployOnlyTargets $($combo.Args) | Out-Null
Write-Host 'REACHED_OK'
exit 0
"@
  $harnessPath = Join-Path $env:TEMP ("sotong_target_" + $combo.Name + ".ps1")
  Set-Content -Path $harnessPath -Value $harness -Encoding UTF8
  try {
    $proc = Start-Process -FilePath "powershell" -ArgumentList @(
      "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $harnessPath
    ) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $outPath -RedirectStandardError $errPath
    $out = ((Get-Content $outPath -Raw -ErrorAction SilentlyContinue) + "`n" +
      (Get-Content $errPath -Raw -ErrorAction SilentlyContinue))
    Assert-True ($proc.ExitCode -ne 0) "$($combo.Name) must non-zero"
    Assert-True ($out -match "one functions target per run") "$($combo.Name) refuse message"
    Assert-True ($out -notmatch "REACHED_OK") "$($combo.Name) must not succeed"
    Write-Host "E $($combo.Name) PASS"
  } finally {
    foreach ($f in @($outPath, $errPath, $harnessPath)) {
      if (Test-Path $f) { Remove-Item $f -Force -ErrorAction SilentlyContinue }
    }
  }
}

Write-Host "== F PlanOnly wiring (source) =="
Assert-True ($src -match '(?m)^\s*\[switch\]\$PlanOnly') "PlanOnly switch"
Assert-True ($src -match 'IncludeMonitorStageHealth -PlanOnly') "usage mentions monitor PlanOnly"
Assert-True ($src -match 'WithMonitorStageHealth:\$IncludeMonitorStageHealth') "wired into Get-DeployOnlyTargets"
Assert-True ($src -match 'if \(\$PlanOnly\)') "PlanOnly early exit"
Assert-True ($src -match 'skipping build/deploy') "PlanOnly skips build/deploy"
Write-Host "F PASS"

# Keep isolated harness in sync with production script body.
Assert-True ($src -match 'if \(\$WithMonitorStageHealth\) \{\s*return @\("hosting", \$ExpectedMonitorStageHealthOnlyTarget\)') "script returns monitor target"
Assert-True ($src -match '\$includeCount -gt 1') "script multi-include counter"

Write-Host "ALL test_deploy_control_targets checks PASS"
