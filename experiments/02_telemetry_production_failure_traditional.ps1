param(
    [int]$TrafficCount = 80,
    [double]$ForceErrorRate = 0.20
)

. "$PSScriptRoot\scenario_lib.ps1"

$ErrorActionPreference = "Stop"
Clear-ScenarioEnvironment
Reset-ScenarioState

$env:PAYMENT_STAGING_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE = ([string]$ForceErrorRate)
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS = "0"

Write-Host "[02_telemetry_production_failure_traditional] running fixed shell pipeline"
Invoke-TraditionalPipeline
Write-Host "[02_telemetry_production_failure_traditional] sending $TrafficCount /pay requests after release"
Invoke-PaymentTraffic -Count $TrafficCount
Write-Host "[02_telemetry_production_failure_traditional] final_decision=release_complete_fixed_pipeline_no_bdi_rollback"
Write-Host "[02_telemetry_production_failure_traditional] production_version=$(Get-ProductionVersion)"
Clear-ScenarioEnvironment
