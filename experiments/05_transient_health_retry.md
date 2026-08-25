# 05 Transient Health Failure And Retry

## Purpose

Prove goal persistence. A first production health check fails once, Jason restores reliability, then retries the same candidate instead of treating rollback as delivery success.

## BDI Workflow

```text
candidate deploys to production
-> first health_check(production) is forced to fail once
-> status(health_check(production),failed)
-> Jason recovers production
-> rollback(production)
-> production_reliability_restored(health_failed)
-> Jason verifies recovered production
-> Jason retries candidate deployment
-> delivery_succeeded(candidate)
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
$env:BDI_TELEMETRY_ENABLED="false"
$env:BDI_OBSERVE_PRODUCTION_CANARY_MS="1000"
$env:BDI_FORCE_HEALTH_CHECK_PRODUCTION_FAIL_ONCE="true"
$env:PAYMENT_PRODUCTION_FAILURE_MODE="none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE="0"
jason project.mas2j
```

Why these settings:

| Setting | Why it is set | What it makes the system do |
| --- | --- | --- |
| `BDI_TELEMETRY_ENABLED=false` | Keeps this scenario focused on action-result reasoning. | Java does not add Prometheus telemetry beliefs during the test. |
| `BDI_OBSERVE_PRODUCTION_CANARY_MS=1000` | Keeps the retry proof fast after recovery. | Canary observation waits only 1 second. |
| `BDI_FORCE_HEALTH_CHECK_PRODUCTION_FAIL_ONCE=true` | Creates one transient production health failure. | The first Jason `health_check(production)` returns `failed`; later checks run normally. |
| `PAYMENT_PRODUCTION_FAILURE_MODE=none` | Keeps the real app healthy. | The failure is a controlled action-result percept, not app degradation. |
| `PAYMENT_PRODUCTION_FORCE_ERROR_RATE=0` | Avoids random business failures. | The retry can succeed cleanly after recovery. |

## Expected BDI Evidence

```text
[CicdEnvironment] forced_failure stage=health_check_production
percept status(health_check(production), failed)
[CicdEnvironment][decision] production_reliability_restored reason=health_failed
[CicdEnvironment][decision] rollback_then_retry_production reason=health_failed
[CicdEnvironment][decision] continue_deploy_candidate reason=health_failed
[CicdEnvironment][decision] delivery_succeeded reason=candidate
```

Expected final version:

```text
candidate
```

## Quick BDI Automation

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
powershell -ExecutionPolicy Bypass -File .\experiments\05_transient_health_retry_bdi.ps1
```

## Traditional CI/CD Execution

The one-shot health failure flag belongs to `CicdEnvironment.java`, not the shell scripts. The traditional pipeline does not see that Java-level test hook, so this exact BDI reasoning scenario is not available in the fixed shell path.

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
powershell -ExecutionPolicy Bypass -File .\experiments\05_transient_health_retry_traditional.ps1
```

Expected traditional result:

```text
final_decision=release_complete_fixed_pipeline
production_version=candidate
```
