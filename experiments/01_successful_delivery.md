# 01 Successful Delivery

## Purpose

Prove the baseline happy path: Jason can drive the full CI/CD action sequence and record successful candidate delivery.

## BDI Workflow

```text
Jason starts
-> !deliver_release(candidate)
-> build/test/security pass
-> staging deploy and health pass
-> production deploy and health pass
-> canary observation stays stable
-> delivery_succeeded(candidate)
-> release_complete
```

## Manual BDI Experiment

1. Clear old state:

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
docker compose down --remove-orphans
if (Test-Path .\bdi\logs\cicd_environment.log) { Clear-Content .\bdi\logs\cicd_environment.log }
```

2. Start a log watcher:

```powershell
Get-Content .\bdi\logs\cicd_environment.log -Tail 120 -Wait
```

3. Start Jason:

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD\bdi
$env:BDI_TELEMETRY_ENABLED="true"
$env:BDI_TELEMETRY_INTERVAL_SECONDS="3"
$env:BDI_TELEMETRY_GRACE_SECONDS="5"
$env:BDI_OBSERVE_PRODUCTION_CANARY_MS="15000"
$env:PAYMENT_STAGING_FAILURE_MODE="none"
$env:PAYMENT_PRODUCTION_FAILURE_MODE="none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE="0"
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS="0"
jason project.mas2j
```

Why these settings:

| Setting | Why it is set | What it makes the system do |
| --- | --- | --- |
| `BDI_TELEMETRY_ENABLED=true` | This is a normal production-style run. | `CicdEnvironment.java` polls Prometheus and updates Jason telemetry beliefs. |
| `BDI_TELEMETRY_INTERVAL_SECONDS=3` | Makes the demo responsive. | Java polls Prometheus every 3 seconds instead of waiting longer. |
| `BDI_TELEMETRY_GRACE_SECONDS=5` | Avoids judging production during container restart. | Java briefly skips telemetry right after deploy/rollback. |
| `BDI_OBSERVE_PRODUCTION_CANARY_MS=15000` | Gives a short canary window. | Jason waits 15 seconds before accepting production as stable. |
| `PAYMENT_STAGING_FAILURE_MODE=none` | Keeps staging healthy. | The staging app does not intentionally fail requests. |
| `PAYMENT_PRODUCTION_FAILURE_MODE=none` | Keeps production healthy. | The production app does not use deterministic failure modes. |
| `PAYMENT_PRODUCTION_FORCE_ERROR_RATE=0` | Removes random failures. | `/pay` and `/refund` should succeed unless another fault exists. |
| `PAYMENT_PRODUCTION_EXTRA_LATENCY_MS=0` | Removes artificial slowness. | Latency telemetry should stay normal. |

## Expected BDI Evidence

Look for:

```text
percept status(build, passed)
percept status(test, passed)
percept status(security_scan, passed)
percept status(deploy(staging), passed)
percept status(health_check(staging), passed)
percept status(deploy(production), passed)
percept status(health_check(production), passed)
percept observation(production, canary, stable)
[CicdEnvironment][decision] delivery_succeeded reason=candidate
[CicdEnvironment][decision] release_complete
```

Check the final version:

```powershell
Get-Content C:\NHI\2026_IT-Project\260023_BDI_CICD\runtime\state\production_version.txt
```

Expected:

```text
candidate
```

## Quick BDI Automation

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
powershell -ExecutionPolicy Bypass -File .\experiments\01_successful_delivery_bdi.ps1
```

## Traditional CI/CD Execution

The traditional version runs the same public shell actions in a fixed order. It does not create Jason beliefs and does not reason about goals.

```text
build.sh
-> test.sh
-> security_scan.sh
-> deploy.sh staging candidate
-> health_check.sh staging
-> deploy.sh production candidate
-> health_check.sh production
-> fixed release complete
```

Quick command:

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
powershell -ExecutionPolicy Bypass -File .\experiments\01_successful_delivery_traditional.ps1
```

Expected traditional result:

```text
final_decision=release_complete_fixed_pipeline
production_version=candidate
```
