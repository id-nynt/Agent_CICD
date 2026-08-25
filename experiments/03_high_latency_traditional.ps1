param(
    [int]$TrafficCount = 35,
    [int]$LatencyMs = 800
)

. "$PSScriptRoot\scenario_lib.ps1"

$ErrorActionPreference = "Stop"
Clear-ScenarioEnvironment
Reset-ScenarioState

$env:PAYMENT_STAGING_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE = "0"
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS = ([string]$LatencyMs)

Write-Host "[03_high_latency_traditional] running fixed shell pipeline"
Invoke-TraditionalPipeline
Write-Host "[03_high_latency_traditional] sending $TrafficCount /pay requests after release"
Invoke-PaymentTraffic -Count $TrafficCount
Write-Host "[03_high_latency_traditional] final_decision=release_complete_fixed_pipeline_no_pause_reobserve"
Write-Host "[03_high_latency_traditional] production_version=$(Get-ProductionVersion)"
Clear-ScenarioEnvironment
