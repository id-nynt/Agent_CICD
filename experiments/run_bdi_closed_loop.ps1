param(
    [int]$TelemetryIntervalSeconds = 3,
    [int]$TelemetryGraceSeconds = 5,
    [int]$TrafficCount = 12,
    [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$BdiDir = Join-Path $Root "bdi"
$LogFile = Join-Path $BdiDir "logs\cicd_environment.log"
$ResultDir = Join-Path $Root "experiments\bdi_closed_loop_results"
$ResultFile = Join-Path $ResultDir "production_telemetry_rollback.md"
$JasonBat = "C:\Program Files\jason-bin-3.3.0\bin\jason.bat"

function Wait-ForLogPattern {
    param(
        [string]$Pattern,
        [int]$Seconds
    )

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

function Invoke-PaymentTraffic {
    param([int]$Count)

    for ($i = 1; $i -le $Count; $i++) {
        try {
            Invoke-RestMethod `
                -Method POST `
                -Uri "http://localhost:8002/pay" `
                -ContentType "application/json" `
                -Body "{`"amount`": $i}" | Out-Null
        } catch {
            # In this scenario /pay is expected to fail; Prometheus should record it.
        }
    }
}

if (!(Test-Path $JasonBat)) {
    throw "Jason launcher not found at $JasonBat"
}

New-Item -ItemType Directory -Force -Path (Split-Path $LogFile) | Out-Null
New-Item -ItemType Directory -Force -Path $ResultDir | Out-Null
Set-Content -LiteralPath $LogFile -Value "" -Encoding UTF8

Push-Location $Root
try {
    Write-Host "[closed_loop] Resetting Docker Compose runtime to reduce stale Prometheus samples"
    docker compose down --remove-orphans | Out-Host
} finally {
    Pop-Location
}

$env:BDI_TELEMETRY_INTERVAL_SECONDS = [string]$TelemetryIntervalSeconds
$env:BDI_TELEMETRY_GRACE_SECONDS = [string]$TelemetryGraceSeconds
$env:PAYMENT_PRODUCTION_FAILURE_MODE = "pay_error"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE = "0"
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS = "0"
$env:PAYMENT_STAGING_FAILURE_MODE = "none"
$env:PAYMENT_STAGING_FORCE_ERROR_RATE = "0"
$env:PAYMENT_STAGING_EXTRA_LATENCY_MS = "0"

Write-Host "[closed_loop] Starting Jason MAS with production candidate failure_mode=pay_error"
$jasonProcess = Start-Process `
    -FilePath $JasonBat `
    -ArgumentList "project.mas2j" `
    -WorkingDirectory $BdiDir `
    -WindowStyle Hidden `
    -PassThru

try {
    if (!(Wait-ForLogPattern -Pattern "percept status\(health_check\(production\), passed\)" -Seconds $TimeoutSeconds)) {
        throw "Timed out waiting for production health-check pass percept."
    }

    Write-Host "[closed_loop] Production health passed. Sending failing /pay traffic."
    Invoke-PaymentTraffic -Count $TrafficCount

    if (!(Wait-ForLogPattern -Pattern "production error_rate=.*\(high\).*environment=unstable" -Seconds $TimeoutSeconds)) {
        throw "Timed out waiting for Prometheus high error-rate telemetry."
    }

    if (!(Wait-ForLogPattern -Pattern "action .*rollback\.sh production" -Seconds $TimeoutSeconds)) {
        throw "Timed out waiting for Jason-triggered rollback action."
    }

    if (!(Wait-ForLogPattern -Pattern "percept status\(rollback\(production\), passed\)" -Seconds $TimeoutSeconds)) {
        throw "Timed out waiting for rollback success percept."
    }

    $mind = & $JasonBat agent mind deployment_agent
    $telemetry = py (Join-Path $Root "telemetry\prometheus_adapter.py") production --pretty
    $logTail = Get-Content -LiteralPath $LogFile -Tail 160

    $report = @(
        "# BDI Closed Loop Result",
        "",
        "Scenario: production health passes, payment traffic fails, Prometheus reports high error rate, Jason rolls back.",
        "",
        "## Evidence Chain",
        "",
        '```text',
        "Jason deploys candidate through CicdEnvironment",
        "Production /health passes",
        "Runner sends POST /pay traffic as stimulus only",
        "Prometheus reports error_rate high",
        "CicdEnvironment updates environment(production, unstable)",
        "deployment_agent reacts through AgentSpeak plan",
        "Jason invokes rollback(production)",
        "CicdEnvironment calls cicd/actions/rollback.sh production",
        "Rollback result becomes status(rollback(production), passed)",
        '```',
        "",
        "## Agent Mind",
        "",
        '```text',
        ($mind -join [Environment]::NewLine),
        '```',
        "",
        "## Prometheus Adapter",
        "",
        '```json',
        ($telemetry -join [Environment]::NewLine),
        '```',
        "",
        "## Environment Log Tail",
        "",
        '```text',
        ($logTail -join [Environment]::NewLine),
        '```'
    )

    Set-Content -LiteralPath $ResultFile -Value $report -Encoding UTF8

    Write-Host "[closed_loop] PASS: Jason closed loop triggered rollback from telemetry."
    Write-Host "[closed_loop] Wrote $ResultFile"
    Write-Host "[closed_loop] Key checks:"
    Write-Host "  - metric(production,error_rate,high)"
    Write-Host "  - environment(production,unstable)"
    Write-Host "  - status(rollback(production),passed)"
} finally {
    if ($jasonProcess -and !$jasonProcess.HasExited) {
        Stop-Process -Id $jasonProcess.Id -Force
    }

    Remove-Item Env:\PAYMENT_PRODUCTION_FAILURE_MODE -ErrorAction SilentlyContinue
    Remove-Item Env:\PAYMENT_PRODUCTION_FORCE_ERROR_RATE -ErrorAction SilentlyContinue
    Remove-Item Env:\PAYMENT_PRODUCTION_EXTRA_LATENCY_MS -ErrorAction SilentlyContinue
    Remove-Item Env:\PAYMENT_STAGING_FAILURE_MODE -ErrorAction SilentlyContinue
    Remove-Item Env:\PAYMENT_STAGING_FORCE_ERROR_RATE -ErrorAction SilentlyContinue
    Remove-Item Env:\PAYMENT_STAGING_EXTRA_LATENCY_MS -ErrorAction SilentlyContinue
}
