param(
    [int]$TimeoutSeconds = 220
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$BdiDir = Join-Path $Root "bdi"
$LogFile = Join-Path $BdiDir "logs\cicd_environment.log"
$JasonBat = "C:\Program Files\jason-bin-3.3.0\bin\jason.bat"

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
            # Failed /pay responses are the intended telemetry stimulus.
        }
    }
}

function Clear-DemoEnvironment {
    $names = @(
        "BDI_TELEMETRY_ENABLED",
        "BDI_TELEMETRY_INTERVAL_SECONDS",
        "BDI_TELEMETRY_GRACE_SECONDS",
        "BDI_OBSERVE_PRODUCTION_CANARY_MS",
        "PAYMENT_STAGING_FAILURE_MODE",
        "PAYMENT_PRODUCTION_FAILURE_MODE",
        "PAYMENT_PRODUCTION_FORCE_ERROR_RATE",
        "PAYMENT_PRODUCTION_EXTRA_LATENCY_MS",
        "BDI_FORCE_BUILD_FAIL",
        "BDI_FORCE_TEST_FAIL",
        "BDI_FORCE_SECURITY_SCAN_FAIL",
        "BDI_FORCE_HEALTH_CHECK_PRODUCTION_FAIL",
        "BDI_FORCE_ROLLBACK_PRODUCTION_FAIL"
    )
    foreach ($name in $names) {
        Remove-Item "Env:\$name" -ErrorAction SilentlyContinue
    }
}

if (!(Test-Path $JasonBat)) {
    throw "Jason launcher not found at $JasonBat"
}

New-Item -ItemType Directory -Force -Path (Split-Path $LogFile) | Out-Null
Set-Content -LiteralPath $LogFile -Value "" -Encoding UTF8

Push-Location $Root
try {
    docker compose down --remove-orphans | Out-Host
} finally {
    Pop-Location
}

Clear-DemoEnvironment
$env:BDI_TELEMETRY_ENABLED = "true"
$env:BDI_TELEMETRY_INTERVAL_SECONDS = "3"
$env:BDI_TELEMETRY_GRACE_SECONDS = "5"
$env:BDI_OBSERVE_PRODUCTION_CANARY_MS = "25000"
$env:PAYMENT_STAGING_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FAILURE_MODE = "pay_error"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE = "0"
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS = "0"

$jasonProcess = $null
try {
    Write-Host "[demo_failed_telemetry_path] starting Jason"
    $jasonProcess = Start-Process `
        -FilePath $JasonBat `
        -ArgumentList "project.mas2j" `
        -WorkingDirectory $BdiDir `
        -WindowStyle Hidden `
        -PassThru

    $canaryStarted = Wait-ForLogPattern -Pattern "\[CicdEnvironment\]\[observe\] start environment=production phase=canary" -Seconds $TimeoutSeconds
    if (!$canaryStarted) {
        throw "Production canary observation did not start before timeout."
    }

    Write-Host "[demo_failed_telemetry_path] canary started; sending /pay traffic"
    Invoke-PaymentTraffic -Count 12

    $highError = Wait-ForLogPattern -Pattern "error_rate=.*\(high\).*environment=unstable" -Seconds 60
    $rollback = Wait-ForLogPattern -Pattern "\[CicdEnvironment\]\[decision\] rollback_production" -Seconds 90

    Write-Host "[demo_failed_telemetry_path] telemetry_high_error=$highError"
    Write-Host "[demo_failed_telemetry_path] rollback_production=$rollback"
    Write-Host "[demo_failed_telemetry_path] log tail:"
    Get-Content -LiteralPath $LogFile -Tail 160

    if (!$highError -or !$rollback) {
        throw "Telemetry-driven rollback evidence was not observed before timeout."
    }
} finally {
    if ($jasonProcess -and !$jasonProcess.HasExited) {
        Stop-Process -Id $jasonProcess.Id -Force
    }
    Clear-DemoEnvironment
}

