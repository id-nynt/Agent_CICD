# 03 High Latency

## Purpose

Prove that Jason does not treat every telemetry issue as the same. High latency without high error rate should trigger pause/reobserve behavior before stronger recovery.

## BDI Workflow

```text
candidate reaches production
-> /health passes
-> canary observation starts
-> real /pay traffic is generated
-> EXTRA_LATENCY_MS adds slow responses
-> Prometheus latency p95 becomes high
-> metric(production,latency,high)
-> environment(production,unstable)
-> Jason chooses pause_reobserve(high_latency)
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
$env:PAYMENT_PRODUCTION_FAILURE_MODE="none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE="0"
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS="800"
jason project.mas2j
```

Why these settings:

| Setting | Why it is set | What it makes the system do |
| --- | --- | --- |
| `BDI_TELEMETRY_ENABLED=true` | The agent must observe latency through Prometheus. | Java converts latency metrics into Jason beliefs. |
| `BDI_TELEMETRY_INTERVAL_SECONDS=3` | Makes latency changes visible quickly. | Polling happens every 3 seconds. |
| `BDI_TELEMETRY_GRACE_SECONDS=5` | Avoids judging startup noise. | Production telemetry is skipped briefly after deploy. |
| `BDI_OBSERVE_PRODUCTION_CANARY_MS=35000` | Gives time to send slow traffic. | Jason waits during canary instead of immediately accepting release. |
| `PAYMENT_PRODUCTION_FAILURE_MODE=none` | Keeps errors out of the scenario. | `/pay` should not fail deterministically. |
| `PAYMENT_PRODUCTION_FORCE_ERROR_RATE=0` | Keeps error rate normal. | Jason should react to latency, not errors. |
| `PAYMENT_PRODUCTION_EXTRA_LATENCY_MS=800` | Creates slow production responses. | `service.py` adds about 800 ms delay, making p95 latency high. |

When canary starts, send traffic:

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
1..35 | ForEach-Object {
  Invoke-RestMethod -Method POST -Uri http://localhost:8002/pay -ContentType "application/json" -Body "{`"amount`": $_}" | Out-Null
}
```

## Expected BDI Evidence

```text
[CicdEnvironment][telemetry] production ... latency_p95_ms=8xx.xx(high) ... environment=unstable
[CicdEnvironment][decision] pause_reobserve reason=high_latency
```

If latency remains high after reobserve, Jason may later restore production reliability and fail/defer candidate delivery.

## Quick BDI Automation

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
powershell -ExecutionPolicy Bypass -File .\experiments\03_high_latency_bdi.ps1
```

## Traditional CI/CD Execution

The traditional pipeline accepts the release after health passes. It does not have a pause/reobserve concept.

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
powershell -ExecutionPolicy Bypass -File .\experiments\03_high_latency_traditional.ps1
```

Expected traditional result:

```text
final_decision=release_complete_fixed_pipeline_no_pause_reobserve
production_version=candidate
```
