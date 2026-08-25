param(
    [int]$TimeoutSeconds = 240,
    [int]$TrafficCount = 80,
    [double]$ForceErrorRate = 0.20
)

. "$PSScriptRoot\scenario_lib.ps1"

$ErrorActionPreference = "Stop"
Clear-ScenarioEnvironment
Reset-ScenarioState

$env:BDI_TELEMETRY_ENABLED = "true"
$env:BDI_TELEMETRY_INTERVAL_SECONDS = "3"
$env:BDI_TELEMETRY_GRACE_SECONDS = "5"
$env:BDI_OBSERVE_PRODUCTION_CANARY_MS = "35000"
$env:BDI_FORCE_ROLLBACK_PRODUCTION_FAIL = "true"
$env:PAYMENT_STAGING_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE = ([string]$ForceErrorRate)
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS = "0"

$jasonProcess = $null
try {
    Write-Host "[07_rollback_unavailable_bdi] starting Jason"
    $jasonProcess = Start-JasonScenario
    if (!(Wait-ForScenarioLog -Pattern "\[CicdEnvironment\]\[observe\] start environment=production phase=canary" -Seconds $TimeoutSeconds)) {
        throw "Canary observation did not start."
    }
    Write-Host "[07_rollback_unavailable_bdi] sending $TrafficCount /pay requests"
    Invoke-PaymentTraffic -Count $TrafficCount
    $highError = Wait-ForScenarioLog -Pattern "error_rate=.*\(high\).*environment=unstable" -Seconds 70
    $rollbackFailed = Wait-ForScenarioLog -Pattern "percept status\(rollback\(production\), failed\)" -Seconds 100
    $manual = Wait-ForScenarioLog -Pattern "\[CicdEnvironment\]\[decision\] manual_intervention_required reason=rollback_failed" -Seconds 100
    Write-Host "[07_rollback_unavailable_bdi] telemetry_high_error=$highError"
    Write-Host "[07_rollback_unavailable_bdi] rollback_failed=$rollbackFailed"
    Write-Host "[07_rollback_unavailable_bdi] manual_intervention_required=$manual"
    Write-Host "[07_rollback_unavailable_bdi] production_version=$(Get-ProductionVersion)"
    Get-Content -LiteralPath $Script:LogFile -Tail 180
    if (!$highError -or !$rollbackFailed -or !$manual) {
        throw "Rollback-unavailable BDI evidence was not observed."
    }
} finally {
    Stop-JasonScenario -Process $jasonProcess
    Clear-ScenarioEnvironment
}
