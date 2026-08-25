param([int]$TimeoutSeconds = 240)

. "$PSScriptRoot\scenario_lib.ps1"

$ErrorActionPreference = "Stop"
Clear-ScenarioEnvironment
Reset-ScenarioState

$env:BDI_TELEMETRY_ENABLED = "false"
$env:BDI_OBSERVE_PRODUCTION_CANARY_MS = "1000"
$env:BDI_FORCE_HEALTH_CHECK_PRODUCTION_FAIL_ONCE = "true"
$env:PAYMENT_STAGING_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE = "0"
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS = "0"

$jasonProcess = $null
try {
    Write-Host "[05_transient_health_retry_bdi] starting Jason with one forced production health failure"
    $jasonProcess = Start-JasonScenario
    $forced = Wait-ForScenarioLog -Pattern "forced_failure stage=health_check_production" -Seconds $TimeoutSeconds
    $retry = Wait-ForScenarioLog -Pattern "\[CicdEnvironment\]\[decision\] rollback_then_retry_production reason=health_failed" -Seconds 120
    $continue = Wait-ForScenarioLog -Pattern "\[CicdEnvironment\]\[decision\] continue_deploy_candidate reason=health_failed" -Seconds 120
    $success = Wait-ForScenarioLog -Pattern "\[CicdEnvironment\]\[decision\] delivery_succeeded reason=candidate" -Seconds 120
    Write-Host "[05_transient_health_retry_bdi] forced_health_failure=$forced"
    Write-Host "[05_transient_health_retry_bdi] rollback_then_retry=$retry"
    Write-Host "[05_transient_health_retry_bdi] continue_deploy_candidate=$continue"
    Write-Host "[05_transient_health_retry_bdi] delivery_succeeded=$success"
    Write-Host "[05_transient_health_retry_bdi] production_version=$(Get-ProductionVersion)"
    Get-Content -LiteralPath $Script:LogFile -Tail 180
    if (!$forced -or !$retry -or !$continue -or !$success) {
        throw "Transient-health retry BDI evidence was not observed."
    }
} finally {
    Stop-JasonScenario -Process $jasonProcess
    Clear-ScenarioEnvironment
}
