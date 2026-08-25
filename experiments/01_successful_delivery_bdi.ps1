param([int]$TimeoutSeconds = 180)

. "$PSScriptRoot\scenario_lib.ps1"

$ErrorActionPreference = "Stop"
Clear-ScenarioEnvironment
Reset-ScenarioState

$env:BDI_TELEMETRY_ENABLED = "true"
$env:BDI_TELEMETRY_INTERVAL_SECONDS = "3"
$env:BDI_TELEMETRY_GRACE_SECONDS = "5"
$env:BDI_OBSERVE_PRODUCTION_CANARY_MS = "15000"
$env:PAYMENT_STAGING_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE = "0"
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS = "0"

$jasonProcess = $null
try {
    Write-Host "[01_successful_delivery_bdi] starting Jason"
    $jasonProcess = Start-JasonScenario
    $releaseComplete = Wait-ForScenarioLog -Pattern "\[CicdEnvironment\]\[decision\] release_complete" -Seconds $TimeoutSeconds
    $deliverySucceeded = Wait-ForScenarioLog -Pattern "\[CicdEnvironment\]\[decision\] delivery_succeeded reason=candidate" -Seconds 20
    Write-Host "[01_successful_delivery_bdi] release_complete=$releaseComplete"
    Write-Host "[01_successful_delivery_bdi] delivery_succeeded=$deliverySucceeded"
    Write-Host "[01_successful_delivery_bdi] production_version=$(Get-ProductionVersion)"
    Get-Content -LiteralPath $Script:LogFile -Tail 120
    if (!$releaseComplete -or !$deliverySucceeded) {
        throw "Successful BDI delivery evidence was not observed."
    }
} finally {
    Stop-JasonScenario -Process $jasonProcess
    Clear-ScenarioEnvironment
}
