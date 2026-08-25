param(
    [int]$TimeoutSeconds = 240,
    [int]$TrafficCount = 35,
    [int]$LatencyMs = 800
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
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE = "0"
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS = ([string]$LatencyMs)

$jasonProcess = $null
try {
    Write-Host "[03_high_latency_bdi] starting Jason"
    $jasonProcess = Start-JasonScenario
    if (!(Wait-ForScenarioLog -Pattern "\[CicdEnvironment\]\[observe\] start environment=production phase=canary" -Seconds $TimeoutSeconds)) {
        throw "Canary observation did not start."
    }
    Write-Host "[03_high_latency_bdi] sending $TrafficCount /pay requests with latency=${LatencyMs}ms"
    Invoke-PaymentTraffic -Count $TrafficCount
    $highLatency = Wait-ForScenarioLog -Pattern "latency_p95_ms=.*\(high\).*environment=unstable" -Seconds 90
    $pause = Wait-ForScenarioLog -Pattern "\[CicdEnvironment\]\[decision\] pause_reobserve reason=high_latency" -Seconds 90
    Write-Host "[03_high_latency_bdi] telemetry_high_latency=$highLatency"
    Write-Host "[03_high_latency_bdi] pause_reobserve=$pause"
    Write-Host "[03_high_latency_bdi] production_version=$(Get-ProductionVersion)"
    Get-Content -LiteralPath $Script:LogFile -Tail 160
    if (!$highLatency -or !$pause) {
        throw "High-latency BDI evidence was not observed."
    }
} finally {
    Stop-JasonScenario -Process $jasonProcess
    Clear-ScenarioEnvironment
}
