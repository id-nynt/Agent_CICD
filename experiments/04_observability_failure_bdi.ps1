param([int]$TimeoutSeconds = 220)

. "$PSScriptRoot\scenario_lib.ps1"

$ErrorActionPreference = "Stop"
Clear-ScenarioEnvironment
Reset-ScenarioState

$env:BDI_TELEMETRY_ENABLED = "true"
$env:BDI_TELEMETRY_INTERVAL_SECONDS = "3"
$env:BDI_TELEMETRY_GRACE_SECONDS = "5"
$env:BDI_OBSERVE_PRODUCTION_CANARY_MS = "15000"
$env:BDI_PROMETHEUS_URL = "http://localhost:19090"
$env:PAYMENT_STAGING_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE = "0"
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS = "0"

$jasonProcess = $null
try {
    Write-Host "[04_observability_failure_bdi] starting Jason with unreachable Prometheus URL"
    $jasonProcess = Start-JasonScenario
    $unavailable = Wait-ForScenarioLog -Pattern "telemetry\(production,\s*unavailable\)|telemetry unavailable" -Seconds $TimeoutSeconds
    $pause = Wait-ForScenarioLog -Pattern "\[CicdEnvironment\]\[decision\] pause_reobserve reason=network_suspected" -Seconds 80
    $manual = Wait-ForScenarioLog -Pattern "\[CicdEnvironment\]\[decision\] manual_intervention_required reason=network_suspected" -Seconds 80
    Write-Host "[04_observability_failure_bdi] telemetry_unavailable=$unavailable"
    Write-Host "[04_observability_failure_bdi] pause_reobserve=$pause"
    Write-Host "[04_observability_failure_bdi] manual_intervention_required=$manual"
    Write-Host "[04_observability_failure_bdi] production_version=$(Get-ProductionVersion)"
    Get-Content -LiteralPath $Script:LogFile -Tail 160
    if (!$unavailable -or !$pause) {
        throw "Observability-failure BDI evidence was not observed."
    }
} finally {
    Stop-JasonScenario -Process $jasonProcess
    Clear-ScenarioEnvironment
}
