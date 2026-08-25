# 02 Telemetry-Driven Production Failure

## Purpose

Prove the strongest BDI loop: production health passes, but real traffic changes Prometheus metrics during canary, and Jason reacts by rolling back.

## BDI Workflow

```text
candidate deployed to production
-> /health passes
-> Jason opens observe(production, canary)
-> real POST /pay traffic is generated
-> FORCE_ERROR_RATE=0.20 makes some requests fail
-> service.py records request/error metrics
-> Prometheus scrapes /metrics
-> CicdEnvironment reads high error rate
-> metric(production,error_rate,high)
-> environment(production,unstable)
-> Jason calls rollback(production)
-> production_reliability_restored(telemetry_unstable)
-> delivery_failed(candidate,telemetry_unstable)
```

## Manual BDI Experiment

1. Clear old state and logs:

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
docker compose down --remove-orphans
if (Test-Path .\bdi\logs\cicd_environment.log) { Clear-Content .\bdi\logs\cicd_environment.log }
```

2. Start Jason:

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD\bdi
$env:BDI_TELEMETRY_ENABLED="true"
$env:BDI_TELEMETRY_INTERVAL_SECONDS="3"
$env:BDI_TELEMETRY_GRACE_SECONDS="5"
$env:BDI_OBSERVE_PRODUCTION_CANARY_MS="35000"
$env:PAYMENT_STAGING_FAILURE_MODE="none"
$env:PAYMENT_PRODUCTION_FAILURE_MODE="none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE="0.20"
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS="0"
jason project.mas2j
```

Why these settings:

| Setting | Why it is set | What it makes the system do |
| --- | --- | --- |
| `BDI_TELEMETRY_ENABLED=true` | This scenario must be telemetry-driven. | Java polls Prometheus and turns metrics into Jason beliefs. |
| `BDI_TELEMETRY_INTERVAL_SECONDS=3` | Keeps the demo quick enough to watch. | New telemetry can reach Jason within a few seconds. |
| `BDI_TELEMETRY_GRACE_SECONDS=5` | Prevents false instability during deploy startup. | Java ignores production telemetry briefly after deployment. |
| `BDI_OBSERVE_PRODUCTION_CANARY_MS=35000` | Gives enough time to inject traffic. | Jason keeps the candidate in canary before final success. |
| `PAYMENT_STAGING_FAILURE_MODE=none` | Keeps staging out of the experiment. | Staging should pass normally so the scenario reaches production. |
| `PAYMENT_PRODUCTION_FAILURE_MODE=none` | Avoids deterministic `/pay` failure. | The app does not force every `/pay` request to fail. |
| `PAYMENT_PRODUCTION_FORCE_ERROR_RATE=0.20` | Creates probabilistic production degradation. | Each real `/pay` request has about a 20 percent chance to fail. |
| `PAYMENT_PRODUCTION_EXTRA_LATENCY_MS=0` | Keeps the scenario focused on error rate. | High latency should not be the reason Jason reacts. |

3. Wait for:

```text
[CicdEnvironment][observe] start environment=production phase=canary
```

4. In another terminal, send real traffic:

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
1..80 | ForEach-Object {
  try {
    Invoke-RestMethod -Method POST -Uri http://localhost:8002/pay -ContentType "application/json" -Body "{`"amount`": $_}"
  } catch {
    "request $_ failed as part of configured error rate"
  }
}
```

## Expected BDI Evidence

Look for:

```text
[CicdEnvironment][telemetry] production error_rate=0.xxxx(high) ... environment=unstable
[CicdEnvironment][decision] recovery_reason reason=telemetry_unstable
[CicdEnvironment] action ... rollback.sh production
[CicdEnvironment] percept status(rollback(production), passed)
[CicdEnvironment][decision] production_reliability_restored reason=telemetry_unstable
[CicdEnvironment][decision] delivery_failed reason=telemetry_unstable
```

Depending on timing, the reason may be `candidate_unsafe`; that is still acceptable if it follows the high error-rate percept.

Expected final version:

```text
stable
```

## Quick BDI Automation

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
powershell -ExecutionPolicy Bypass -File .\experiments\02_telemetry_production_failure_bdi.ps1
```

## Traditional CI/CD Execution

The traditional fixed pipeline can deploy the same unhealthy candidate configuration because `/health` passes. It does not watch the canary telemetry and does not choose rollback.

Quick command:

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
powershell -ExecutionPolicy Bypass -File .\experiments\02_telemetry_production_failure_traditional.ps1
```

Expected traditional result:

```text
final_decision=release_complete_fixed_pipeline_no_bdi_rollback
production_version=candidate
```
