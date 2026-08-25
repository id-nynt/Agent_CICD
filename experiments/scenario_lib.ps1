param()

$Script:Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Script:BdiDir = Join-Path $Script:Root "bdi"
$Script:LogFile = Join-Path $Script:BdiDir "logs\cicd_environment.log"
$Script:JasonBat = "C:\Program Files\jason-bin-3.3.0\bin\jason.bat"
$Script:Bash = "C:\Program Files\Git\bin\bash.exe"

function Clear-ScenarioEnvironment {
    $names = @(
        "BDI_TELEMETRY_ENABLED",
        "BDI_TELEMETRY_INTERVAL_SECONDS",
        "BDI_TELEMETRY_GRACE_SECONDS",
        "BDI_OBSERVE_PRODUCTION_CANARY_MS",
        "BDI_PROMETHEUS_URL",
        "BDI_FORCE_BUILD_FAIL",
        "BDI_FORCE_TEST_FAIL",
        "BDI_FORCE_SECURITY_SCAN_FAIL",
        "BDI_FORCE_DEPLOY_STAGING_FAIL",
        "BDI_FORCE_DEPLOY_PRODUCTION_FAIL",
        "BDI_FORCE_HEALTH_CHECK_STAGING_FAIL",
        "BDI_FORCE_HEALTH_CHECK_PRODUCTION_FAIL",
        "BDI_FORCE_HEALTH_CHECK_PRODUCTION_FAIL_ONCE",
        "BDI_FORCE_ROLLBACK_PRODUCTION_FAIL",
        "PAYMENT_STAGING_FAILURE_MODE",
        "PAYMENT_STAGING_FORCE_ERROR_RATE",
        "PAYMENT_STAGING_EXTRA_LATENCY_MS",
        "PAYMENT_PRODUCTION_FAILURE_MODE",
        "PAYMENT_PRODUCTION_FORCE_ERROR_RATE",
        "PAYMENT_PRODUCTION_EXTRA_LATENCY_MS"
    )

    foreach ($name in $names) {
        Remove-Item "Env:\$name" -ErrorAction SilentlyContinue
    }
}

function Reset-ScenarioState {
    New-Item -ItemType Directory -Force -Path (Split-Path $Script:LogFile) | Out-Null
    Set-Content -LiteralPath $Script:LogFile -Value "" -Encoding UTF8
    Push-Location $Script:Root
    try {
        docker compose down --remove-orphans | Out-Host
    } finally {
        Pop-Location
    }
}

function Wait-ForScenarioLog {
    param(
        [Parameter(Mandatory=$true)][string]$Pattern,
        [int]$Seconds = 120
    )

    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path $Script:LogFile) {
            $content = Get-Content -LiteralPath $Script:LogFile -Raw
            if ($content -match $Pattern) {
                return $true
            }
        }
        Start-Sleep -Seconds 2
    }
    return $false
}

function Start-JasonScenario {
    if (!(Test-Path $Script:JasonBat)) {
        throw "Jason launcher not found at $Script:JasonBat"
    }

    return Start-Process `
        -FilePath $Script:JasonBat `
        -ArgumentList "project.mas2j" `
        -WorkingDirectory $Script:BdiDir `
        -WindowStyle Hidden `
        -PassThru
}

function Stop-JasonScenario {
    param($Process)
    if ($Process -and !$Process.HasExited) {
        Stop-Process -Id $Process.Id -Force
    }
}

function Invoke-PaymentTraffic {
    param(
        [int]$Count = 80,
        [string]$Endpoint = "pay",
        [int]$DelayMilliseconds = 0
    )

    for ($i = 1; $i -le $Count; $i++) {
        try {
            Invoke-RestMethod `
                -Method POST `
                -Uri "http://localhost:8002/$Endpoint" `
                -ContentType "application/json" `
                -Body "{`"amount`": $i}" | Out-Null
        } catch {
            # Failed business requests are valid stimulus for telemetry scenarios.
        }

        if ($DelayMilliseconds -gt 0) {
            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }
}

function Invoke-CicdAction {
    param(
        [Parameter(Mandatory=$true)][string]$ScriptName,
        [string[]]$Arguments = @()
    )

    if (!(Test-Path $Script:Bash)) {
        throw "Git Bash not found at $Script:Bash"
    }

    $scriptPath = Join-Path $Script:Root "cicd\actions\$ScriptName"
    & $Script:Bash $scriptPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$ScriptName failed with exit code $LASTEXITCODE"
    }
}

function Invoke-TraditionalPipeline {
    Invoke-CicdAction -ScriptName "build.sh" -Arguments @("candidate")
    Invoke-CicdAction -ScriptName "test.sh" -Arguments @("candidate")
    Invoke-CicdAction -ScriptName "security_scan.sh" -Arguments @("candidate")
    Invoke-CicdAction -ScriptName "deploy.sh" -Arguments @("staging", "candidate")
    Invoke-CicdAction -ScriptName "health_check.sh" -Arguments @("staging")
    Invoke-CicdAction -ScriptName "deploy.sh" -Arguments @("production", "candidate")
    Invoke-CicdAction -ScriptName "health_check.sh" -Arguments @("production")
}

function Get-ProductionVersion {
    $path = Join-Path $Script:Root "runtime\state\production_version.txt"
    if (Test-Path $path) {
        return (Get-Content -LiteralPath $path -Raw).Trim()
    }
    return "<missing>"
}
