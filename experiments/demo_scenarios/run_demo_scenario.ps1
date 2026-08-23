param(
    [Parameter(Mandatory=$true)]
    [string]$Scenario,
    [int]$TelemetryIntervalSeconds = 3,
    [int]$TelemetryGraceSeconds = 8,
    [int]$TimeoutSeconds = 210
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

Push-Location $Root
try {
    powershell -ExecutionPolicy Bypass `
        -File .\experiments\run_bdi_scenario_suite.ps1 `
        -Scenario $Scenario `
        -TelemetryIntervalSeconds $TelemetryIntervalSeconds `
        -TelemetryGraceSeconds $TelemetryGraceSeconds `
        -TimeoutSeconds $TimeoutSeconds
} finally {
    Pop-Location
}
