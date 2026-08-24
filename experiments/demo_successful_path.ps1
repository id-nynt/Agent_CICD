param(
    [int]$TimeoutSeconds = 180
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

function Clear-DemoEnvironment {
    $names = @(
        "BDI_TELEMETRY_ENABLED",
        "BDI_TELEMETRY_INTERVAL_SECONDS",
        "BDI_TELEMETRY_GRACE_SECONDS",
        "BDI_OBSERVE_PRODUCTION_CANARY_MS",
        "PAYMENT_STAGING_FAILURE_MODE",
        "PAYMENT_PRODUCTION_FAILURE_MODE",
        "PAYMENT_PRODUCTION_FORCE_ERROR_RATE",
        "PAYMENT_PRODUCTION_EXTRA_LATENCY_MS"
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
$env:BDI_OBSERVE_PRODUCTION_CANARY_MS = "15000"
$env:PAYMENT_STAGING_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FAILURE_MODE = "none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE = "0"
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS = "0"

$jasonProcess = $null
try {
    Write-Host "[demo_successful_path] starting Jason"
    $jasonProcess = Start-Process `
        -FilePath $JasonBat `
        -ArgumentList "project.mas2j" `
        -WorkingDirectory $BdiDir `
        -WindowStyle Hidden `
        -PassThru

    $releaseComplete = Wait-ForLogPattern -Pattern "\[CicdEnvironment\]\[decision\] release_complete" -Seconds $TimeoutSeconds
    $stableObservation = Wait-ForLogPattern -Pattern "percept observation\(production, canary, stable\)" -Seconds 20

    Write-Host "[demo_successful_path] release_complete=$releaseComplete"
    Write-Host "[demo_successful_path] observation_stable=$stableObservation"
    Write-Host "[demo_successful_path] log tail:"
    Get-Content -LiteralPath $LogFile -Tail 120

    if (!$releaseComplete -or !$stableObservation) {
        throw "Successful path evidence was not observed before timeout."
    }
} finally {
    if ($jasonProcess -and !$jasonProcess.HasExited) {
        Stop-Process -Id $jasonProcess.Id -Force
    }
    Clear-DemoEnvironment
}

