param(
    [ValidateSet("build","test","security")][string]$Gate = "build",
    [int]$TimeoutSeconds = 160
)

. "$PSScriptRoot\scenario_lib.ps1"

$ErrorActionPreference = "Stop"
Clear-ScenarioEnvironment
Reset-ScenarioState

$env:BDI_TELEMETRY_ENABLED = "false"
$env:PAYMENT_STAGING_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE = "0"

if ($Gate -eq "build") { $env:BDI_FORCE_BUILD_FAIL = "true"; $reason = "build_failed" }
if ($Gate -eq "test") { $env:BDI_FORCE_TEST_FAIL = "true"; $reason = "test_failed" }
if ($Gate -eq "security") { $env:BDI_FORCE_SECURITY_SCAN_FAIL = "true"; $reason = "security_failed" }

$jasonProcess = $null
try {
    Write-Host "[06_gate_failures_bdi] starting Jason with forced $Gate gate failure"
    $jasonProcess = Start-JasonScenario
    $forced = Wait-ForScenarioLog -Pattern "forced_failure stage=$Gate" -Seconds $TimeoutSeconds
    $failed = Wait-ForScenarioLog -Pattern "\[CicdEnvironment\]\[decision\] delivery_failed reason=$reason" -Seconds 80
    Write-Host "[06_gate_failures_bdi] forced_gate_failure=$forced"
    Write-Host "[06_gate_failures_bdi] delivery_failed=$failed"
    Write-Host "[06_gate_failures_bdi] production_version=$(Get-ProductionVersion)"
    Get-Content -LiteralPath $Script:LogFile -Tail 120
    if (!$forced -or !$failed) {
        throw "Gate-failure BDI evidence was not observed."
    }
} finally {
    Stop-JasonScenario -Process $jasonProcess
    Clear-ScenarioEnvironment
}
