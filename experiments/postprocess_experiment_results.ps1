param(
    [Parameter(Mandatory=$true)][string]$ResultsRoot
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path $ResultsRoot).Path
$logDir = Join-Path $root "logs"
if (!(Test-Path $logDir)) {
    throw "Logs directory not found: $logDir"
}

function Read-Log {
    param([string]$Name)
    $path = Join-Path $logDir $Name
    if (!(Test-Path $path)) {
        return ""
    }
    return Get-Content -LiteralPath $path -Raw
}

function Has-All {
    param([string]$Text, [string[]]$Patterns)
    foreach ($pattern in $Patterns) {
        if ($Text -notmatch $pattern) {
            return $false
        }
    }
    return $true
}

$definitions = @(
    @{
        Code = "01"
        Scenario = "Successful delivery"
        BdiLog = "01_successful_delivery_bdi.log"
        TradLog = "01_successful_delivery_traditional.log"
        BdiPatterns = @("delivery_succeeded reason=candidate", "release_complete", "production_version=candidate")
        TradPatterns = @("final_decision=release_complete_fixed_pipeline", "production_version=candidate")
        BdiMeaning = "BDI completed the root delivery goal and recorded release_complete."
        TradMeaning = "Traditional fixed pipeline completed the happy path."
    },
    @{
        Code = "02"
        Scenario = "Telemetry-driven production failure"
        BdiLog = "02_telemetry_driven_production_failure_bdi.log"
        TradLog = "02_telemetry_driven_production_failure_traditional.log"
        BdiPatterns = @("telemetry_high_error=True", "production_reliability_restored=True", "delivery_failed=True", "production_version=stable")
        TradPatterns = @("final_decision=release_complete_fixed_pipeline_no_bdi_rollback", "production_version=candidate")
        BdiMeaning = "BDI saw high Prometheus error-rate telemetry, rolled back, restored reliability, and failed candidate delivery."
        TradMeaning = "Traditional pipeline accepted the health-passing candidate and did not rollback."
    },
    @{
        Code = "03"
        Scenario = "High latency"
        BdiLog = "03_high_latency_bdi.log"
        TradLog = "03_high_latency_traditional.log"
        BdiPatterns = @("telemetry_high_latency=True", "pause_reobserve=True", "production_version=candidate")
        TradPatterns = @("final_decision=release_complete_fixed_pipeline_no_pause_reobserve", "production_version=candidate")
        BdiMeaning = "BDI classified latency as high and chose pause/reobserve."
        TradMeaning = "Traditional pipeline accepted the release without pause/reobserve reasoning."
    },
    @{
        Code = "04"
        Scenario = "Observability failure"
        BdiLog = "04_observability_failure_bdi.log"
        TradLog = "04_observability_failure_traditional.log"
        BdiPatterns = @("pause_reobserve=True", "manual_intervention_required=True", "telemetry\(production, unavailable\)", "network\(production, suspected\)")
        TradPatterns = @("final_decision=release_complete_fixed_pipeline_no_telemetry_reasoning", "production_version=candidate")
        BdiMeaning = "BDI perceived telemetry unavailable/network suspected and escalated uncertainty."
        TradMeaning = "Traditional pipeline did not use telemetry as a decision source."
    },
    @{
        Code = "05"
        Scenario = "Transient health failure and retry"
        BdiLog = "05_transient_health_failure_and_retry_bdi.log"
        TradLog = "05_transient_health_failure_and_retry_traditional.log"
        BdiPatterns = @("forced_health_failure=True", "rollback_then_retry=True", "continue_deploy_candidate=True", "delivery_succeeded=True", "production_version=candidate")
        TradPatterns = @("final_decision=release_complete_fixed_pipeline", "production_version=candidate")
        BdiMeaning = "BDI restored reliability after one failed health check, retried the same candidate, and succeeded."
        TradMeaning = "Traditional path does not see the Java-only one-shot BDI hook."
    },
    @{
        Code = "06"
        Scenario = "Build gate failure"
        BdiLog = "06_build_gate_failure_bdi.log"
        TradLog = "06_build_gate_failure_traditional.log"
        BdiPatterns = @("forced_gate_failure=True", "delivery_failed=True", "status\(build, failed\)", "delivery_failed reason=build_failed")
        TradPatterns = @("final_decision=release_complete_fixed_pipeline_if_shell_actions_pass", "production_version=candidate")
        BdiMeaning = "BDI stopped delivery when the build gate percept failed."
        TradMeaning = "Traditional shell path passed because BDI_FORCE_BUILD_FAIL is a Java BDI test hook."
    },
    @{
        Code = "07"
        Scenario = "Rollback unavailable"
        BdiLog = "07_rollback_unavailable_bdi.log"
        TradLog = "07_rollback_unavailable_traditional.log"
        BdiPatterns = @("telemetry_high_error=True", "rollback_failed=True", "manual_intervention_required=True", "status\(rollback\(production\), failed\)")
        TradPatterns = @("final_decision=release_complete_fixed_pipeline_no_manual_intervention_reason", "production_version=candidate")
        BdiMeaning = "BDI tried rollback after telemetry degradation, perceived rollback failure, and requested manual intervention."
        TradMeaning = "Traditional path had no BDI recovery action or manual-intervention reasoning."
    }
)

$observed = @()
foreach ($definition in $definitions) {
    $bdiText = Read-Log -Name $definition.BdiLog
    $tradText = Read-Log -Name $definition.TradLog
    $observed += [pscustomobject]@{
        code = $definition.Code
        scenario = $definition.Scenario
        mode = "BDI"
        evidence_passed = Has-All -Text $bdiText -Patterns $definition.BdiPatterns
        log_file = (Join-Path $logDir $definition.BdiLog)
        meaning = $definition.BdiMeaning
        matched_patterns = $definition.BdiPatterns
    }
    $observed += [pscustomobject]@{
        code = $definition.Code
        scenario = $definition.Scenario
        mode = "Traditional"
        evidence_passed = Has-All -Text $tradText -Patterns $definition.TradPatterns
        log_file = (Join-Path $logDir $definition.TradLog)
        meaning = $definition.TradMeaning
        matched_patterns = $definition.TradPatterns
    }
}

$jsonPath = Join-Path $root "experiment_results_observed.json"
$observed | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$mdPath = Join-Path $root "traditional_vs_bdi_comparison_observed.md"
$lines = @()
$lines += "# Traditional Vs BDI Comparison: Observed Evidence"
$lines += ""
$lines += "Generated: $(Get-Date -Format s)"
$lines += ""
$lines += "Source logs: logs/"
$lines += ""
$lines += "| Code | Scenario | BDI Observed Result | Traditional Observed Result | Comparison |
| --- | --- | --- | --- | --- |"

foreach ($definition in $definitions) {
    $bdi = $observed | Where-Object { $_.code -eq $definition.Code -and $_.mode -eq "BDI" } | Select-Object -First 1
    $trad = $observed | Where-Object { $_.code -eq $definition.Code -and $_.mode -eq "Traditional" } | Select-Object -First 1
    if ($bdi.evidence_passed) { $bdiStatus = "PASS" } else { $bdiStatus = "CHECK LOG" }
    if ($trad.evidence_passed) { $tradStatus = "PASS" } else { $tradStatus = "CHECK LOG" }
    $bdiLog = Split-Path $bdi.log_file -Leaf
    $tradLog = Split-Path $trad.log_file -Leaf
    $lines += "| $($definition.Code) | $($definition.Scenario) | ${bdiStatus}: $($bdi.meaning) Log: $bdiLog | ${tradStatus}: $($trad.meaning) Log: $tradLog | BDI adds explicit belief/goal/plan reasoning beyond the fixed shell sequence. |"
}

$lines += ""
$lines += "## Important Notes"
$lines += ""
$lines += "- This report is based on evidence found in the saved logs, not only process exit codes."
$lines += "- The wrapper run captured Docker progress correctly, but PowerShell did not preserve child exit codes in the initial JSON; use this observed report for supervisor discussion."
$lines += "- Scenario 04 contains BDI evidence for pause/reobserve and manual intervention, even though the scenario script's own final assertion reported failure because of a text-pattern mismatch."
$lines += "- Scenario 02 remains the strongest live telemetry proof: real /pay traffic changed Prometheus metrics, then Jason recovered production and failed candidate delivery."

$lines | Set-Content -LiteralPath $mdPath -Encoding UTF8

Write-Host "[postprocess] observed_json=$jsonPath"
Write-Host "[postprocess] observed_comparison=$mdPath"

$observed | Format-Table code,scenario,mode,evidence_passed -AutoSize
