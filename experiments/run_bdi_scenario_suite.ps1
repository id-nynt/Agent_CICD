param(
    [string]$Scenario = "all",
    [int]$TelemetryIntervalSeconds = 3,
    [int]$TelemetryGraceSeconds = 5,
    [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$BdiDir = Join-Path $Root "bdi"
$LogFile = Join-Path $BdiDir "logs\cicd_environment.log"
$CatalogFile = Join-Path $PSScriptRoot "bdi_scenario_catalog.json"
$ResultDir = Join-Path $PSScriptRoot "bdi_scenario_results"
$SummaryFile = Join-Path $ResultDir "summary.md"
$JasonBat = "C:\Program Files\jason-bin-3.3.0\bin\jason.bat"

function Get-ScenarioValue {
    param($ScenarioObject, [string]$Name, $Default = $null)
    if ($ScenarioObject.PSObject.Properties.Name -contains $Name) {
        return $ScenarioObject.$Name
    }
    return $Default
}

function Wait-ForLogPattern {
    param([string]$Pattern, [int]$Seconds)
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path $LogFile) {
            $content = Get-Content -LiteralPath $LogFile -Raw
            if ($content -match $Pattern) {
                return $true
            }
        }
        Start-Sleep -Seconds 2
    }
    return $false
}

function Get-AgentMind {
    $tempOut = Join-Path $env:TEMP ("bdi_agent_mind_{0}.txt" -f ([guid]::NewGuid().ToString("N")))
    $tempErr = Join-Path $env:TEMP ("bdi_agent_mind_{0}.err" -f ([guid]::NewGuid().ToString("N")))
    try {
        $process = Start-Process `
            -FilePath $JasonBat `
            -ArgumentList "agent mind deployment_agent" `
            -WorkingDirectory $BdiDir `
            -WindowStyle Hidden `
            -RedirectStandardOutput $tempOut `
            -RedirectStandardError $tempErr `
            -PassThru
        if (!$process.WaitForExit(8000)) {
            Stop-Process -Id $process.Id -Force
        }
        $stdout = if (Test-Path $tempOut) { Get-Content -LiteralPath $tempOut -Raw } else { "" }
        $stderr = if (Test-Path $tempErr) { Get-Content -LiteralPath $tempErr -Raw } else { "" }
        return ($stdout + [Environment]::NewLine + $stderr).Trim()
    } finally {
        Remove-Item -LiteralPath $tempOut -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $tempErr -ErrorAction SilentlyContinue
    }
}

function Wait-ForBelief {
    param([string]$Belief, [int]$Seconds)
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        $logText = if (Test-Path $LogFile) { Get-Content -LiteralPath $LogFile -Raw } else { "" }
        $normalizedLog = ($logText -replace "\s+", "")
        $normalizedBelief = ($Belief -replace "\s+", "")
        if ($normalizedLog -like "*$normalizedBelief*") {
            return $true
        }
        if ($Belief -match "^decision\(([^)]+)\)$" -and $logText -match "\[CicdEnvironment\]\[decision\]\s+$([regex]::Escape($Matches[1]))(\s|$)") {
            return $true
        }
        if ($Belief -match "^(stop_reason|reobserve_reason|manual_reason|recovery_reason)\(([^)]+)\)$" -and $logText -match "reason=$([regex]::Escape($Matches[2]))") {
            return $true
        }
        if ($Belief -match "^metric\(production,error_rate,([^)]+)\)$" -and $logText -match "error_rate=.*\($([regex]::Escape($Matches[1]))\)") {
            return $true
        }
        if ($Belief -match "^metric\(production,latency,([^)]+)\)$" -and $logText -match "latency_p95_ms=.*\($([regex]::Escape($Matches[1]))\)") {
            return $true
        }
        if ($Belief -match "^metric\(production,availability,([^)]+)\)$" -and $logText -match "availability=.*\($([regex]::Escape($Matches[1]))\)") {
            return $true
        }
        if ($Belief -match "^environment\(production,([^)]+)\)$" -and $logText -match "environment=$([regex]::Escape($Matches[1]))") {
            return $true
        }
        Start-Sleep -Seconds 2
    }
    return $false
}

function Invoke-PaymentTraffic {
    param([string]$Mode, [int]$Count)
    if ($Count -le 0) {
        return
    }

    for ($i = 1; $i -le $Count; $i++) {
        try {
            Invoke-RestMethod `
                -Method POST `
                -Uri "http://localhost:8002/pay" `
                -ContentType "application/json" `
                -Body "{`"amount`": $i}" | Out-Null
        } catch {
            # Error-producing scenarios intentionally rely on Prometheus counters.
        }
    }
}

function Reset-Compose {
    Push-Location $Root
    try {
        docker compose down --remove-orphans | Out-Host
    } finally {
        Pop-Location
    }
}

function Set-ScenarioEnvironment {
    param($ScenarioObject)

    $env:BDI_TELEMETRY_INTERVAL_SECONDS = [string]$TelemetryIntervalSeconds
    $env:BDI_TELEMETRY_GRACE_SECONDS = [string]$TelemetryGraceSeconds
    $env:BDI_TELEMETRY_ENABLED = [string](Get-ScenarioValue $ScenarioObject "telemetryEnabled" $true)
    $env:PAYMENT_STAGING_FAILURE_MODE = Get-ScenarioValue $ScenarioObject "stagingFailureMode" "none"
    $env:PAYMENT_STAGING_FORCE_ERROR_RATE = [string](Get-ScenarioValue $ScenarioObject "stagingForceErrorRate" 0)
    $env:PAYMENT_STAGING_EXTRA_LATENCY_MS = [string](Get-ScenarioValue $ScenarioObject "stagingExtraLatencyMs" 0)
    $env:PAYMENT_PRODUCTION_FAILURE_MODE = Get-ScenarioValue $ScenarioObject "productionFailureMode" "none"
    $env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE = [string](Get-ScenarioValue $ScenarioObject "productionForceErrorRate" 0)
    $env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS = [string](Get-ScenarioValue $ScenarioObject "productionExtraLatencyMs" 0)

    foreach ($failure in (Get-ScenarioValue $ScenarioObject "forceFailures" @())) {
        Set-Item -Path "Env:\$failure" -Value "true"
    }
}

function Clear-ScenarioEnvironment {
    $names = @(
        "BDI_TELEMETRY_INTERVAL_SECONDS",
        "BDI_TELEMETRY_GRACE_SECONDS",
        "BDI_TELEMETRY_ENABLED",
        "PAYMENT_STAGING_FAILURE_MODE",
        "PAYMENT_STAGING_FORCE_ERROR_RATE",
        "PAYMENT_STAGING_EXTRA_LATENCY_MS",
        "PAYMENT_PRODUCTION_FAILURE_MODE",
        "PAYMENT_PRODUCTION_FORCE_ERROR_RATE",
        "PAYMENT_PRODUCTION_EXTRA_LATENCY_MS",
        "BDI_FORCE_BUILD_FAIL",
        "BDI_FORCE_TEST_FAIL",
        "BDI_FORCE_SECURITY_SCAN_FAIL",
        "BDI_FORCE_DEPLOY_STAGING_FAIL",
        "BDI_FORCE_HEALTH_CHECK_STAGING_FAIL",
        "BDI_FORCE_DEPLOY_PRODUCTION_FAIL",
        "BDI_FORCE_HEALTH_CHECK_PRODUCTION_FAIL",
        "BDI_FORCE_ROLLBACK_PRODUCTION_FAIL",
        "BDI_FORCE_BUILD_FAIL_ONCE",
        "BDI_FORCE_TEST_FAIL_ONCE",
        "BDI_FORCE_SECURITY_SCAN_FAIL_ONCE",
        "BDI_FORCE_DEPLOY_STAGING_FAIL_ONCE",
        "BDI_FORCE_HEALTH_CHECK_STAGING_FAIL_ONCE",
        "BDI_FORCE_DEPLOY_PRODUCTION_FAIL_ONCE",
        "BDI_FORCE_HEALTH_CHECK_PRODUCTION_FAIL_ONCE",
        "BDI_FORCE_ROLLBACK_PRODUCTION_FAIL_ONCE"
    )

    foreach ($name in $names) {
        Remove-Item "Env:\$name" -ErrorAction SilentlyContinue
    }
}

function ConvertTo-PlainList {
    param($Value)
    if ($null -eq $Value) {
        return @()
    }
    if ($Value -is [System.Array]) {
        return @($Value)
    }
    return @($Value)
}

if (!(Test-Path $JasonBat)) {
    throw "Jason launcher not found at $JasonBat"
}

$catalog = Get-Content -LiteralPath $CatalogFile -Raw | ConvertFrom-Json
$selected = @($catalog | Where-Object { $Scenario -eq "all" -or $_.id -eq $Scenario })
if ($selected.Count -eq 0) {
    throw "No scenario matched '$Scenario'."
}

New-Item -ItemType Directory -Force -Path (Split-Path $LogFile) | Out-Null
New-Item -ItemType Directory -Force -Path $ResultDir | Out-Null

$summaryRows = @()

foreach ($scenarioObject in $selected) {
    $id = $scenarioObject.id
    Write-Host "[scenario_suite] Running $id"

    $scenarioResultDir = Join-Path $ResultDir $id
    New-Item -ItemType Directory -Force -Path $scenarioResultDir | Out-Null
    Set-Content -LiteralPath $LogFile -Value "" -Encoding UTF8
    Clear-ScenarioEnvironment
    Reset-Compose
    Set-ScenarioEnvironment $scenarioObject

    $jasonProcess = $null
    $passed = $false
    $notes = New-Object System.Collections.Generic.List[string]
    try {
        $jasonProcess = Start-Process `
            -FilePath $JasonBat `
            -ArgumentList "project.mas2j" `
            -WorkingDirectory $BdiDir `
            -WindowStyle Hidden `
            -PassThru

        $trafficMode = Get-ScenarioValue $scenarioObject "trafficMode" "none"
        $trafficCount = [int](Get-ScenarioValue $scenarioObject "trafficCount" 0)

        if ($trafficMode -ne "none") {
            if (Wait-ForLogPattern -Pattern "percept status\(health_check\(production\), passed\)" -Seconds $TimeoutSeconds) {
                Invoke-PaymentTraffic -Mode $trafficMode -Count $trafficCount
            } else {
                $notes.Add("production health pass was not observed before traffic stimulus")
            }
        }

        if ([bool](Get-ScenarioValue $scenarioObject "stopPrometheusAfterRelease" $false)) {
            if (Wait-ForBelief -Belief "decision(release_complete)" -Seconds $TimeoutSeconds) {
                Push-Location $Root
                try {
                    docker compose stop prometheus | Out-Host
                } finally {
                    Pop-Location
                }
            } else {
                $notes.Add("release_complete was not observed before stopping Prometheus")
            }
        }

        if ([bool](Get-ScenarioValue $scenarioObject "healAfterPause" $false)) {
            if (Wait-ForBelief -Belief "decision(pause_reobserve)" -Seconds $TimeoutSeconds) {
                $env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS = "0"
                $env:PAYMENT_PRODUCTION_FAILURE_MODE = "none"
                Push-Location $Root
                try {
                    Start-Sleep -Seconds 4
                    $healed = $false
                    for ($attempt = 1; $attempt -le 3 -and -not $healed; $attempt++) {
                        docker compose up -d --no-deps --build payment-production | Out-Host
                        if ($LASTEXITCODE -eq 0) {
                            $healed = $true
                        } else {
                            Start-Sleep -Seconds 5
                        }
                    }
                    docker compose up -d --no-deps prometheus | Out-Host
                    Start-Sleep -Seconds 6
                    Invoke-PaymentTraffic -Mode "success" -Count ([Math]::Max(4, $trafficCount))
                } finally {
                    Pop-Location
                }
            } else {
                $notes.Add("pause_reobserve was not observed before transient recovery stimulus")
            }
        }

        $expectedBeliefs = ConvertTo-PlainList (Get-ScenarioValue $scenarioObject "expectedBeliefs" @())
        $beliefChecks = @()
        foreach ($belief in $expectedBeliefs) {
            Write-Host "[scenario_suite] checking belief $belief"
            $seen = Wait-ForBelief -Belief $belief -Seconds $TimeoutSeconds
            $beliefChecks += [ordered]@{
                belief = $belief
                observed = $seen
            }
        }
        Write-Host "[scenario_suite] belief checks complete for $id"

        $forbiddenChecks = @()
        $logText = if (Test-Path $LogFile) { Get-Content -LiteralPath $LogFile -Raw } else { "" }
        foreach ($pattern in (ConvertTo-PlainList (Get-ScenarioValue $scenarioObject "forbiddenLogPatterns" @()))) {
            $seen = $logText -match [regex]::Escape($pattern)
            $forbiddenChecks += [ordered]@{
                pattern = $pattern
                observed = $seen
            }
        }

        $passed = (($beliefChecks | Where-Object { -not $_.observed }).Count -eq 0) -and (($forbiddenChecks | Where-Object { $_.observed }).Count -eq 0)

        Write-Host "[scenario_suite] collecting evidence for $id"
        $mind = "Agent mind capture skipped by suite automation. Use 'jason agent mind deployment_agent' while the MAS is running for live belief inspection."
        $logTail = if (Test-Path $LogFile) { Get-Content -LiteralPath $LogFile -Tail 220 } else { @() }
        $telemetry = $null
        if ([bool](Get-ScenarioValue $scenarioObject "telemetryEnabled" $true)) {
            try {
                $telemetry = py (Join-Path $Root "telemetry\prometheus_adapter.py") production --pretty 2>&1
            } catch {
                $telemetry = @($_.Exception.Message)
            }
        } else {
            $telemetry = @("Telemetry disabled for this gate-control scenario.")
        }

        $jsonResult = [ordered]@{
            id = [string]$id
            passed = [bool]$passed
            capability = [string]$scenarioObject.capability
            successCriteria = [string]$scenarioObject.successCriteria
            expectedBeliefs = @($beliefChecks | ForEach-Object { [ordered]@{ belief = [string]$_.belief; observed = [bool]$_.observed } })
            forbiddenLogPatterns = @($forbiddenChecks | ForEach-Object { [ordered]@{ pattern = [string]$_.pattern; observed = [bool]$_.observed } })
            notes = @($notes.ToArray() | ForEach-Object { [string]$_ })
            resultFiles = [ordered]@{
                summary = "summary.md"
                environmentLog = "..\..\..\bdi\logs\cicd_environment.log"
            }
        }

        $jsonPath = Join-Path $scenarioResultDir "result.json"
        $mdPath = Join-Path $scenarioResultDir "summary.md"
        Write-Host "[scenario_suite] writing evidence for $id"
        $jsonResult | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

        $md = @(
            "# $id",
            "",
            "Capability: $($scenarioObject.capability)",
            "",
            "Result: $(if ($passed) { "PASS" } else { "FAIL" })",
            "",
            "Success criteria: $($scenarioObject.successCriteria)",
            "",
            "## Expected Beliefs",
            "",
            '```text',
            (($beliefChecks | ForEach-Object { "$($_.belief): $($_.observed)" }) -join [Environment]::NewLine),
            '```',
            "",
            "## Agent Mind",
            "",
            '```text',
            $mind,
            '```',
            "",
            "## Environment Log Tail",
            "",
            '```text',
            ($logTail -join [Environment]::NewLine),
            '```'
        )
        Set-Content -LiteralPath $mdPath -Value $md -Encoding UTF8

        $summaryRows += "| $id | $(if ($passed) { "PASS" } else { "FAIL" }) | $($scenarioObject.capability) | $($scenarioObject.successCriteria) |"
        Write-Host "[scenario_suite] $(if ($passed) { "PASS" } else { "FAIL" }): $id"
    } finally {
        if ($jasonProcess -and !$jasonProcess.HasExited) {
            Stop-Process -Id $jasonProcess.Id -Force
        }
        Clear-ScenarioEnvironment
    }
}

$summary = @(
    "# BDI Scenario Suite Summary",
    "",
    "Generated: $(Get-Date -Format s)",
    "",
    "| Scenario | Result | BDI capability | Success criteria |",
    "| --- | --- | --- | --- |"
) + $summaryRows

Set-Content -LiteralPath $SummaryFile -Value $summary -Encoding UTF8
Write-Host "[scenario_suite] Wrote $SummaryFile"
