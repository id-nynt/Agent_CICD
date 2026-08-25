param()

. "$PSScriptRoot\scenario_lib.ps1"

$ErrorActionPreference = "Stop"
Clear-ScenarioEnvironment
Reset-ScenarioState

$env:PAYMENT_STAGING_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE = "0"
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS = "0"

Write-Host "[05_transient_health_retry_traditional] running fixed shell pipeline"
Invoke-TraditionalPipeline
Write-Host "[05_transient_health_retry_traditional] note=traditional script does not use BDI_FORCE_HEALTH_CHECK_PRODUCTION_FAIL_ONCE because that flag belongs to CicdEnvironment"
Write-Host "[05_transient_health_retry_traditional] final_decision=release_complete_fixed_pipeline"
Write-Host "[05_transient_health_retry_traditional] production_version=$(Get-ProductionVersion)"
Clear-ScenarioEnvironment
