# 04 Observability Failure

## Purpose

Prove that Jason can distinguish "the app is unhealthy" from "telemetry is unavailable." This scenario points the BDI environment at an unreachable Prometheus URL.

## BDI Workflow

```text
candidate reaches production
-> health check passes
-> CicdEnvironment cannot query Prometheus
-> telemetry(production,unavailable)
-> network(production,suspected)
-> environment(production,unstable)
-> Jason pauses/reobserves
-> if still unavailable, Jason escalates to manual intervention/defer
```

## Manual BDI Experiment

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
docker compose down --remove-orphans
if (Test-Path .\bdi\logs\cicd_environment.log) { Clear-Content .\bdi\logs\cicd_environment.log }
```

Start Jason with a deliberately unreachable Prometheus URL:

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD\bdi
$env:BDI_TELEMETRY_ENABLED="true"
$env:BDI_TELEMETRY_INTERVAL_SECONDS="3"
$env:BDI_TELEMETRY_GRACE_SECONDS="5"
$env:BDI_OBSERVE_PRODUCTION_CANARY_MS="15000"
$env:BDI_PROMETHEUS_URL="http://localhost:19090"
$env:PAYMENT_PRODUCTION_FAILURE_MODE="none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE="0"
jason project.mas2j
```

Why these settings:

| Setting | Why it is set | What it makes the system do |
| --- | --- | --- |
| `BDI_TELEMETRY_ENABLED=true` | The scenario is about telemetry availability. | Java tries to poll Prometheus. |
| `BDI_TELEMETRY_INTERVAL_SECONDS=3` | Makes the failed poll appear quickly. | Java retries telemetry every 3 seconds. |
| `BDI_TELEMETRY_GRACE_SECONDS=5` | Keeps deploy startup from dominating the result. | Java waits briefly after production deploy before judging telemetry. |
| `BDI_OBSERVE_PRODUCTION_CANARY_MS=15000` | Keeps the manual demo short. | Jason waits 15 seconds in canary/reobserve windows. |
| `BDI_PROMETHEUS_URL=http://localhost:19090` | Intentionally points Java at the wrong Prometheus port. | Prometheus queries fail, creating `telemetry(production,unavailable)`. |
| `PAYMENT_PRODUCTION_FAILURE_MODE=none` | Keeps the app itself healthy. | The problem is observability, not app behavior. |
| `PAYMENT_PRODUCTION_FORCE_ERROR_RATE=0` | Keeps business errors normal. | High error rate should not be the reason Jason reacts. |

## Expected BDI Evidence

```text
[CicdEnvironment][telemetry] production unavailable
telemetry(production,unavailable)
network(production,suspected)
[CicdEnvironment][decision] pause_reobserve reason=network_suspected
```

If it remains unavailable:

```text
[CicdEnvironment][decision] manual_intervention_required reason=network_suspected
delivery_deferred(candidate,network_suspected)
```

## Quick BDI Automation

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
powershell -ExecutionPolicy Bypass -File .\experiments\04_observability_failure_bdi.ps1
```

## Traditional CI/CD Execution

The traditional pipeline does not query Prometheus as a decision source, so observability failure is invisible to it.

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
powershell -ExecutionPolicy Bypass -File .\experiments\04_observability_failure_traditional.ps1
```

Expected traditional result:

```text
final_decision=release_complete_fixed_pipeline_no_telemetry_reasoning
production_version=candidate
```
