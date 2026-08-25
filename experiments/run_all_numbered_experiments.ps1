param(
    [string]$ResultsRoot = ""
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($ResultsRoot)) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $ResultsRoot = Join-Path $Root "experiments\results\$stamp"
}

New-Item -ItemType Directory -Force -Path $ResultsRoot | Out-Null
$LogDir = Join-Path $ResultsRoot "logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$scenarioDefinitions = @(
    @{
        Code = "01"
        Scenario = "Successful delivery"
        Capability = "Completes the delivery goal when action and telemetry beliefs stay healthy."
        BdiScript = "01_successful_delivery_bdi.ps1"
        TraditionalScript = "01_successful_delivery_traditional.ps1"
        ExpectedBdi = "delivery_succeeded(candidate), release_complete, production=candidate"
        ExpectedTraditional = "fixed release complete, production=candidate"
    },
    @{
        Code = "02"
        Scenario = "Telemetry-driven production failure"
        Capability = "Uses real traffic and Prometheus error-rate telemetry to rollback and fail candidate delivery."
        BdiScript = "02_telemetry_production_failure_bdi.ps1"
        TraditionalScript = "02_telemetry_production_failure_traditional.ps1"
        ExpectedBdi = "production_reliability_restored, delivery_failed, production=stable"
        ExpectedTraditional = "fixed pipeline accepts health-passing candidate, production=candidate"
    },
    @{
        Code = "03"
        Scenario = "High latency"
        Capability = "Distinguishes latency from error-rate failure and chooses pause/reobserve."
        BdiScript = "03_high_latency_bdi.ps1"
        TraditionalScript = "03_high_latency_traditional.ps1"
        ExpectedBdi = "metric latency high, pause_reobserve(high_latency)"
        ExpectedTraditional = "fixed release complete, no pause/reobserve"
    },
    @{
        Code = "04"
        Scenario = "Observability failure"
        Capability = "Recognizes telemetry unavailable/network suspected instead of app failure."
        BdiScript = "04_observability_failure_bdi.ps1"
        TraditionalScript = "04_observability_failure_traditional.ps1"
        ExpectedBdi = "telemetry unavailable, pause_reobserve(network_suspected)"
        ExpectedTraditional = "fixed release complete, no telemetry reasoning"
    },
    @{
        Code = "05"
        Scenario = "Transient health failure and retry"
        Capability = "Restores reliability, then retries the same candidate and succeeds."
        BdiScript = "05_transient_health_retry_bdi.ps1"
        TraditionalScript = "05_transient_health_retry_traditional.ps1"
        ExpectedBdi = "rollback_then_retry, continue_deploy_candidate, delivery_succeeded"
        ExpectedTraditional = "fixed release complete; Java-only one-shot hook is not visible"
    },
    @{
        Code = "06"
        Scenario = "Build gate failure"
        Capability = "Stops delivery when an early gate percept fails."
        BdiScript = "06_gate_failures_bdi.ps1 -Gate build"
        TraditionalScript = "06_gate_failures_traditional.ps1 -Gate build"
        ExpectedBdi = "status(build,failed), delivery_failed(build_failed)"
        ExpectedTraditional = "shell actions pass if source is valid; Java hook is not visible"
    },
    @{
        Code = "07"
        Scenario = "Rollback unavailable"
        Capability = "Escalates to manual intervention when recovery action fails."
        BdiScript = "07_rollback_unavailable_bdi.ps1"
        TraditionalScript = "07_rollback_unavailable_traditional.ps1"
        ExpectedBdi = "status(rollback(production),failed), manual_intervention_required"
        ExpectedTraditional = "fixed release complete; no BDI rollback decision to fail"
    }
)

function Get-ProductionVersion {
    $path = Join-Path $Root "runtime\state\production_version.txt"
    if (Test-Path $path) {
        return (Get-Content -LiteralPath $path -Raw).Trim()
    }
    return "<missing>"
}

function Invoke-ExperimentScript {
    param(
        [hashtable]$Definition,
        [ValidateSet("BDI","Traditional")][string]$Mode,
        [string]$ScriptCommand
    )

    $logName = "{0}_{1}_{2}.log" -f $Definition.Code, ($Definition.Scenario -replace '[^A-Za-z0-9]+','_').Trim('_').ToLowerInvariant(), $Mode.ToLowerInvariant()
    $logPath = Join-Path $LogDir $logName
    $stdoutPath = Join-Path $LogDir ($logName -replace '\.log$', '.stdout.tmp')
    $stderrPath = Join-Path $LogDir ($logName -replace '\.log$', '.stderr.tmp')
    $scriptLine = ".\experiments\$ScriptCommand"

    $started = Get-Date
    Write-Host "[run_all] starting $($Definition.Code) ${Mode}: $($Definition.Scenario)"
    $process = Start-Process `
        -FilePath "powershell" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "& $scriptLine") `
        -WorkingDirectory $Root `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -WindowStyle Hidden `
        -Wait `
        -PassThru
    $process.Refresh()
    $exitCode = $process.ExitCode
    $ended = Get-Date

    $stdout = if (Test-Path $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw } else { "" }
    $stderr = if (Test-Path $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { "" }
    $text = @(
        "=== STDOUT ==="
        $stdout
        "=== STDERR ==="
        $stderr
    ) -join "`n"
    Set-Content -LiteralPath $logPath -Value $text -Encoding UTF8
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -ErrorAction SilentlyContinue

    $passed = ($exitCode -eq 0)
    if ($Mode -eq "BDI") {
        $expected = $Definition.ExpectedBdi
    } else {
        $expected = $Definition.ExpectedTraditional
    }
    [pscustomobject]@{
        code = $Definition.Code
        scenario = $Definition.Scenario
        mode = $Mode
        passed = $passed
        exit_code = $exitCode
        started_at = $started.ToString("s")
        ended_at = $ended.ToString("s")
        duration_seconds = [math]::Round(($ended - $started).TotalSeconds, 1)
        production_version = Get-ProductionVersion
        log_file = (Resolve-Path $logPath).Path
        expected = $expected
        capability = $Definition.Capability
        tail = (($text -split "`r?`n") | Select-Object -Last 20) -join "`n"
    }
}

$results = @()
foreach ($definition in $scenarioDefinitions) {
    foreach ($mode in @("BDI", "Traditional")) {
        if ($mode -eq "BDI") {
            $script = $definition.BdiScript
            $expected = $definition.ExpectedBdi
        } else {
            $script = $definition.TraditionalScript
            $expected = $definition.ExpectedTraditional
        }
        try {
            $result = Invoke-ExperimentScript -Definition $definition -Mode $mode -ScriptCommand $script
        } catch {
            $result = [pscustomobject]@{
                code = $definition.Code
                scenario = $definition.Scenario
                mode = $mode
                passed = $false
                exit_code = -1
                started_at = (Get-Date).ToString("s")
                ended_at = (Get-Date).ToString("s")
                duration_seconds = 0
                production_version = Get-ProductionVersion
                log_file = ""
                expected = $expected
                capability = $definition.Capability
                tail = $_.Exception.Message
            }
        }
        $results += $result
    }
}

$jsonPath = Join-Path $ResultsRoot "experiment_results.json"
$results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$mdPath = Join-Path $ResultsRoot "traditional_vs_bdi_comparison.md"
$lines = @()
$lines += "# Traditional Vs BDI Experiment Comparison"
$lines += ""
$lines += "Generated: $(Get-Date -Format s)"
$lines += ""
$lines += "Logs directory: logs/"
$lines += ""
$lines += '| Code | Scenario | BDI Result | Traditional Result | BDI Capability Demonstrated |'
$lines += '| --- | --- | --- | --- | --- |'

foreach ($definition in $scenarioDefinitions) {
    $bdi = $results | Where-Object { $_.code -eq $definition.Code -and $_.mode -eq "BDI" } | Select-Object -First 1
    $traditional = $results | Where-Object { $_.code -eq $definition.Code -and $_.mode -eq "Traditional" } | Select-Object -First 1
    if ($bdi.passed) { $bdiStatus = "PASS" } else { $bdiStatus = "FAIL" }
    if ($traditional.passed) { $tradStatus = "PASS" } else { $tradStatus = "FAIL" }
    if ([string]::IsNullOrWhiteSpace($bdi.log_file)) {
        $bdiLogLeaf = "<none>"
    } else {
        $bdiLogLeaf = Split-Path $bdi.log_file -Leaf
    }
    if ([string]::IsNullOrWhiteSpace($traditional.log_file)) {
        $traditionalLogLeaf = "<none>"
    } else {
        $traditionalLogLeaf = Split-Path $traditional.log_file -Leaf
    }
    $bdiCell = "{0}; production={1}; expected: {2}; log: {3}" -f $bdiStatus, $bdi.production_version, $bdi.expected, $bdiLogLeaf
    $tradCell = "{0}; production={1}; expected: {2}; log: {3}" -f $tradStatus, $traditional.production_version, $traditional.expected, $traditionalLogLeaf
$lines += "| $($definition.Code) | $($definition.Scenario) | $bdiCell | $tradCell | $($definition.Capability) |"
}

$lines += ""
$lines += "## Notes"
$lines += ""
$lines += "- Traditional scripts use the same cicd/actions/*.sh public action interface, but they do not create Jason beliefs or choose BDI plans."
$lines += "- PAYMENT_* variables configure app/container behavior."
$lines += "- BDI_FORCE_* variables are Java environment test hooks used only for selected BDI control-flow scenarios."
$lines += "- The strongest live telemetry proof is scenario 02, where real /pay traffic changes Prometheus metrics and Jason reacts."

$lines | Set-Content -LiteralPath $mdPath -Encoding UTF8

Write-Host "[run_all] results_root=$ResultsRoot"
Write-Host "[run_all] json=$jsonPath"
Write-Host "[run_all] comparison=$mdPath"

$failed = $results | Where-Object { -not $_.passed }
if ($failed.Count -gt 0) {
    Write-Host "[run_all] completed with failures=$($failed.Count)"
    $failed | Format-Table code,scenario,mode,exit_code,production_version -AutoSize
    exit 1
}

Write-Host "[run_all] all experiments passed"
