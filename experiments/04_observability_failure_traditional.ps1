param()

. "$PSScriptRoot\scenario_lib.ps1"

$ErrorActionPreference = "Stop"
Clear-ScenarioEnvironment
Reset-ScenarioState

$env:PAYMENT_STAGING_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE = "0"
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS = "0"

Write-Host "[04_observability_failure_traditional] running fixed shell pipeline"
Invoke-TraditionalPipeline
Write-Host "[04_observability_failure_traditional] final_decision=release_complete_fixed_pipeline_no_telemetry_reasoning"
Write-Host "[04_observability_failure_traditional] production_version=$(Get-ProductionVersion)"
Clear-ScenarioEnvironment
