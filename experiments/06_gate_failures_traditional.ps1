param(
    [ValidateSet("build","test","security")][string]$Gate = "build"
)

. "$PSScriptRoot\scenario_lib.ps1"

$ErrorActionPreference = "Stop"
Clear-ScenarioEnvironment
Reset-ScenarioState

Write-Host "[06_gate_failures_traditional] running fixed shell pipeline"
Write-Host "[06_gate_failures_traditional] note=BDI_FORCE_* variables are Java-environment test hooks, so traditional shell scripts do not read them"
Write-Host "[06_gate_failures_traditional] requested_gate=$Gate"
Invoke-TraditionalPipeline
Write-Host "[06_gate_failures_traditional] final_decision=release_complete_fixed_pipeline_if_shell_actions_pass"
Write-Host "[06_gate_failures_traditional] production_version=$(Get-ProductionVersion)"
Clear-ScenarioEnvironment
