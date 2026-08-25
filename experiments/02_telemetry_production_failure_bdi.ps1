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
$env:PAYMENT_STAGING_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE = ([string]$ForceErrorRate)
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS = "0"

$jasonProcess = $null
try {
    Write-Host "[02_telemetry_production_failure_bdi] starting Jason"
    $jasonProcess = Start-JasonScenario
    if (!(Wait-ForScenarioLog -Pattern "\[CicdEnvironment\]\[observe\] start environment=production phase=canary" -Seconds $TimeoutSeconds)) {
        throw "Canary observation did not start."
    }
    Write-Host "[02_telemetry_production_failure_bdi] sending $TrafficCount /pay requests"
    Invoke-PaymentTraffic -Count $TrafficCount
    $highError = Wait-ForScenarioLog -Pattern "error_rate=.*\(high\).*environment=unstable" -Seconds 70
    $restored = Wait-ForScenarioLog -Pattern "\[CicdEnvironment\]\[decision\] production_reliability_restored" -Seconds 100
    $failed = Wait-ForScenarioLog -Pattern "\[CicdEnvironment\]\[decision\] delivery_failed reason=(telemetry_unstable|candidate_unsafe)" -Seconds 100
    Write-Host "[02_telemetry_production_failure_bdi] telemetry_high_error=$highError"
    Write-Host "[02_telemetry_production_failure_bdi] production_reliability_restored=$restored"
    Write-Host "[02_telemetry_production_failure_bdi] delivery_failed=$failed"
    Write-Host "[02_telemetry_production_failure_bdi] production_version=$(Get-ProductionVersion)"
    Get-Content -LiteralPath $Script:LogFile -Tail 160
    if (!$highError -or !$restored -or !$failed) {
        throw "Telemetry-driven BDI failure evidence was not observed."
    }
} finally {
    Stop-JasonScenario -Process $jasonProcess
    Clear-ScenarioEnvironment
}
