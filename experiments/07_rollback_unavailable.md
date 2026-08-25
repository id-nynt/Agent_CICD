# 07 Rollback Unavailable

## Purpose

Prove that Jason can escalate when it decides rollback is necessary but rollback fails.

## BDI Workflow

```text
candidate reaches production
-> real /pay traffic creates high error-rate telemetry
-> Jason decides production recovery is needed
-> Jason calls rollback(production)
-> CicdEnvironment forces rollback action failure for the experiment
-> status(rollback(production),failed)
-> Jason records manual_intervention_required
```

## Manual BDI Experiment

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
docker compose down --remove-orphans
if (Test-Path .\bdi\logs\cicd_environment.log) { Clear-Content .\bdi\logs\cicd_environment.log }
```

Start Jason:

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD\bdi
$env:BDI_TELEMETRY_ENABLED="true"
$env:BDI_TELEMETRY_INTERVAL_SECONDS="3"
$env:BDI_TELEMETRY_GRACE_SECONDS="5"
$env:BDI_OBSERVE_PRODUCTION_CANARY_MS="35000"
$env:BDI_FORCE_ROLLBACK_PRODUCTION_FAIL="true"
$env:PAYMENT_PRODUCTION_FAILURE_MODE="none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE="0.20"
jason project.mas2j
```

Why these settings:

| Setting | Why it is set | What it makes the system do |
| --- | --- | --- |
| `BDI_TELEMETRY_ENABLED=true` | Rollback should be triggered by real telemetry degradation. | Java polls Prometheus and updates Jason beliefs. |
| `BDI_TELEMETRY_INTERVAL_SECONDS=3` | Makes the high error-rate belief appear quickly. | Java polls every 3 seconds. |
| `BDI_TELEMETRY_GRACE_SECONDS=5` | Avoids startup false alarms. | Java skips telemetry briefly after deploy/rollback. |
| `BDI_OBSERVE_PRODUCTION_CANARY_MS=35000` | Gives time to send failing traffic. | Jason remains in canary long enough for telemetry to change. |
| `BDI_FORCE_ROLLBACK_PRODUCTION_FAIL=true` | Simulates rollback being unavailable. | When Jason calls `rollback(production)`, Java returns `status(rollback(production), failed)`. |
| `PAYMENT_PRODUCTION_FAILURE_MODE=none` | Avoids deterministic `/pay` failure. | The degradation comes from probabilistic failures. |
| `PAYMENT_PRODUCTION_FORCE_ERROR_RATE=0.20` | Creates measured error-rate degradation. | Real `/pay` traffic produces enough failures for Prometheus to report high error rate. |

When canary starts, send traffic:

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

```text
[CicdEnvironment][telemetry] production error_rate=0.xxxx(high) ... environment=unstable
[CicdEnvironment] forced_failure stage=rollback_production
percept status(rollback(production), failed)
[CicdEnvironment][decision] manual_intervention_required reason=rollback_failed
```

## Quick BDI Automation

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
powershell -ExecutionPolicy Bypass -File .\experiments\07_rollback_unavailable_bdi.ps1
```

## Traditional CI/CD Execution

The traditional fixed pipeline has no Jason rollback decision in this scenario. It can deploy the candidate and then observe traffic, but it does not choose rollback or manual intervention.

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
powershell -ExecutionPolicy Bypass -File .\experiments\07_rollback_unavailable_traditional.ps1
```

Expected traditional result:

```text
final_decision=release_complete_fixed_pipeline_no_manual_intervention_reason
production_version=candidate
```
