# Extra Information: Current Architecture And Workflow

This document explains the current BDI CI/CD prototype as it works now.

It is a companion to `docs/project_guide.md` and the numbered experiment guides in `experiments/`.

## 1. Project In One Paragraph

This project compares a fixed CI/CD pipeline with a Jason BDI controller. Both paths use the same local payment service, Docker Compose environment, Prometheus metrics, and shell action scripts under `cicd/actions/`. The difference is the controller. The traditional path runs a fixed sequence. The BDI path uses Jason beliefs, goals, and plans to decide whether to deliver the candidate, fail delivery, defer delivery, rollback production, pause/reobserve, retry, or request manual intervention.

The current root objective is:

```text
deliver the candidate successfully while preserving production reliability
```

Rollback is not counted as candidate delivery success. Rollback is a safety action that can restore production reliability while the candidate delivery may still fail or be deferred.

## 2. Current Active Runtime Path

The real demo path is:

```text
bdi/project.mas2j
-> bdi/deployment_agent.asl
-> bdi/src/env/CicdEnvironment.java
-> cicd/actions/*.sh
-> docker-compose.yml
-> app/payment_service/service.py
-> runtime/prometheus/prometheus.yml
```

What starts the demo:

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD\bdi
jason project.mas2j
```

This starts Jason, not Docker directly. Docker starts later when the Jason agent calls `deploy(...)`, Java receives that Jason action, and `CicdEnvironment.java` runs `cicd/actions/deploy.sh`, which runs `docker compose up`.

## 3. Current Legacy Or Historical Path

These files are not needed for the supervisor demo:

```text
bdi/cicd_agent.asl
bdi/run_agent_for_scenario.sh
telemetry/generated_beliefs/
telemetry/live/
simulation/
upgrade_hooks/
experiments/archive/
```

They are useful as research history, but the current evidence should come from the active runtime path above.

## 4. Component Diagram

```text
User / experiment script
        |
        v
Jason MAS
        |
        v
deployment_agent.asl
        |
        | Jason external actions:
        | build(candidate)
        | test(candidate)
        | deploy(candidate, production)
        | rollback(production)
        v
CicdEnvironment.java
        |
        | runs shell scripts
        v
cicd/actions/*.sh
        |
        | docker compose up / health checks / rollback
        v
Docker Compose
        |
        +--> payment-staging      http://localhost:8001
        |
        +--> payment-production   http://localhost:8002
        |
        `--> prometheus           http://localhost:9090
```

## 5. Perception-Reasoning-Action Loop

```text
Jason chooses action
        |
        v
CicdEnvironment executes shell script
        |
        v
Docker/app state changes
        |
        v
App exposes /metrics
        |
        v
Prometheus scrapes metrics
        |
        v
CicdEnvironment polls Prometheus
        |
        v
Java converts numeric telemetry into symbolic percepts
        |
        v
Jason belief base changes
        |
        v
AgentSpeak plan becomes applicable
        |
        v
Jason chooses next action or final outcome
```

This is the research loop:

```text
perceive -> reason -> act -> perceive again
```

## 6. BDI Agent

The current active agent is:

```text
bdi/deployment_agent.asl
```

It is registered in:

```text
bdi/project.mas2j
```

The root goal is:

```text
!deliver_release(candidate)
```

The main goal structure is:

```text
!deliver_release(candidate)
|
|-- !prepare_candidate(candidate)
|   `-- build(candidate)
|
|-- !validate_candidate(candidate)
|   |-- test(candidate)
|   `-- security_scan(candidate)
|
|-- !deploy_to_staging(candidate)
|
|-- !verify_staging
|
|-- !deploy_to_production(candidate)
|
|-- !verify_production
|
|-- !observe_production_canary
|
`-- !maintain_reliability
```

Current outcome beliefs:

```text
delivery_succeeded(candidate)
delivery_failed(candidate, Reason)
delivery_deferred(candidate, Reason)
production_reliability_restored
production_reliability_restored(Reason)
```

Current decision marker beliefs:

```text
decision(delivery_succeeded)
decision(delivery_failed)
decision(delivery_deferred)
decision(release_complete)
decision(pause_reobserve)
decision(rollback_production)
decision(rollback_then_retry_production)
decision(continue_deploy_candidate)
decision(manual_intervention_required)
```

The agent now has outcome guards so if delivery has already failed or been deferred, a delayed canary completion cannot later overwrite the outcome as success.

## 7. Java Environment

The bridge is:

```text
bdi/src/env/CicdEnvironment.java
```

It has two jobs.

First, it executes actions requested by Jason:

| Jason action | Java result |
| --- | --- |
| `build(candidate)` | Runs `cicd/actions/build.sh candidate`. |
| `test(candidate)` | Runs `cicd/actions/test.sh candidate`. |
| `security_scan(candidate)` | Runs `cicd/actions/security_scan.sh candidate`. |
| `deploy(candidate, staging)` | Runs `cicd/actions/deploy.sh staging candidate`. |
| `deploy(candidate, production)` | Runs `cicd/actions/deploy.sh production candidate`. |
| `health_check(staging)` | Runs `cicd/actions/health_check.sh staging`. |
| `health_check(production)` | Runs `cicd/actions/health_check.sh production`. |
| `rollback(production)` | Runs `cicd/actions/rollback.sh production`. |
| `observe(production, canary)` | Waits for the canary window while telemetry polling continues. |

Second, it updates Jason percepts:

| Source | Jason percept |
| --- | --- |
| Script exit code `0` | `status(..., passed)` |
| Script exit code non-zero | `status(..., failed)` |
| Health check passed | `environment(..., stable)` |
| Health check failed | `environment(..., unstable)` |
| Prometheus query result | `metric(production,...,...)` |
| Telemetry summary | `environment(production,stable/unstable)` |
| Observation window result | `observation(production,canary,stable/unstable/unknown)` |

## 8. App And Docker

The app is:

```text
app/payment_service/service.py
```

Docker Compose starts two copies:

```text
payment-staging      http://localhost:8001
payment-production   http://localhost:8002
```

The app endpoints are:

| Endpoint | Method | Meaning |
| --- | --- | --- |
| `/health` | `GET` | Health check used by CI/CD scripts. |
| `/pay` | `POST` | Business request used for traffic/error telemetry. |
| `/refund` | `POST` | Business request used for traffic/error telemetry. |
| `/metrics` | `GET` | Prometheus metrics endpoint. |

Opening `/pay` or `/refund` in a browser uses `GET`, so `Method Not Allowed` is normal. Use `POST`.

## 9. App Environment Variables

The scenario variables you set in PowerShell are passed into Docker Compose, then into the container.

Example:

```powershell
$env:PAYMENT_PRODUCTION_FAILURE_MODE="none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE="0.20"
```

Docker Compose maps them:

```text
PAYMENT_PRODUCTION_FAILURE_MODE      -> FAILURE_MODE
PAYMENT_PRODUCTION_FORCE_ERROR_RATE  -> FORCE_ERROR_RATE
PAYMENT_PRODUCTION_EXTRA_LATENCY_MS  -> EXTRA_LATENCY_MS
```

Then `service.py` reads:

```text
FAILURE_MODE
FORCE_ERROR_RATE
EXTRA_LATENCY_MS
```

Meaning:

| Variable | Current demo use | Effect |
| --- | --- | --- |
| `FAILURE_MODE=none` | Normal/success and probabilistic telemetry demos. | No deterministic failure mode. |
| `FAILURE_MODE=pay_error` | Optional deterministic test only. | Every `/pay` request fails. |
| `FORCE_ERROR_RATE=0.20` | Main telemetry failure demo. | Each real `/pay` or `/refund` request has about 20% chance to fail. |
| `FORCE_ERROR_RATE=0` | Success/high-latency demos. | No random business failures. |
| `EXTRA_LATENCY_MS=800` | High-latency demo. | Adds about 800 ms delay to requests. |
| `EXTRA_LATENCY_MS=0` | Normal/error-rate demos. | No artificial latency. |

Important:

```text
FORCE_ERROR_RATE does not create traffic.
It only changes the probability that real requests fail.
You or a script must still send POST /pay traffic.
```

## 10. Telemetry

The app exposes Prometheus metrics at:

```text
GET /metrics
```

Prometheus config:

```text
runtime/prometheus/prometheus.yml
```

Prometheus scrapes:

```text
payment-staging:8000/metrics
payment-production:8000/metrics
```

The main metrics are:

| Metric | Meaning |
| --- | --- |
| `payment_service_requests_total` | Counts requests by version, method, endpoint, and status. |
| `payment_service_errors_total` | Counts failed business requests. |
| `payment_service_request_latency_seconds` | Records request latency histogram. |
| `payment_service_health` | Health gauge: `1` healthy, `0` unhealthy. |

`CicdEnvironment.java` queries Prometheus and applies thresholds from:

```text
telemetry/thresholds.yml
```

Current symbolic mapping:

| Numeric condition | Jason percept |
| --- | --- |
| error rate `> 0.05` | `metric(production,error_rate,high)` |
| error rate `<= 0.05` | `metric(production,error_rate,normal)` |
| p95 latency `> 500 ms` | `metric(production,latency,high)` |
| p95 latency `<= 500 ms` | `metric(production,latency,normal)` |
| availability `< 0.99` | `metric(production,availability,low)` |
| availability `>= 0.99` | `metric(production,availability,high)` |

Overall:

```text
any bad metric -> environment(production,unstable)
all normal     -> environment(production,stable)
Prometheus unavailable -> telemetry(production,unavailable)
                          network(production,suspected)
                          environment(production,unstable)
```

The active path does not use `telemetry/generated_beliefs/`. Those are legacy generated belief files.

## 11. Timing Controls

These variables are read by `CicdEnvironment.java`, not by the Flask app:

| Variable | Meaning |
| --- | --- |
| `BDI_TELEMETRY_ENABLED=true/false` | Turns Prometheus polling on/off. |
| `BDI_TELEMETRY_INTERVAL_SECONDS=3` | Poll Prometheus every 3 seconds. |
| `BDI_TELEMETRY_GRACE_SECONDS=5` | Ignore production telemetry briefly after deploy/rollback. |
| `BDI_OBSERVE_PRODUCTION_CANARY_MS=15000` | Keep canary observation open for 15 seconds. |
| `BDI_OBSERVE_PRODUCTION_CANARY_MS=35000` | Longer canary window for manual traffic injection. |
| `BDI_PROMETHEUS_URL=http://localhost:19090` | Observability-failure demo: intentionally wrong Prometheus URL. |

Why timing matters:

```text
/health can pass quickly.
Without canary time, Jason may record success too soon.
The observation window gives time for traffic, Prometheus scraping, Java polling, and belief updates.
```

## 12. Current Main Scenario Set

Use the numbered experiment files:

| Code | Scenario | Main point |
| --- | --- | --- |
| `01` | Successful delivery | Jason completes delivery when beliefs stay healthy. |
| `02` | Telemetry-driven production failure | Real `/pay` traffic changes metrics; Jason rolls back and fails candidate delivery. |
| `03` | High latency | Jason pauses/reobserves instead of treating every problem as immediate rollback. |
| `04` | Observability failure | Jason distinguishes telemetry unavailable from app failure. |
| `05` | Transient health failure and retry | Jason restores reliability, then retries the same candidate. |
| `06` | Build/test/security gate failures | Jason fails delivery when early action-result percepts fail. |
| `07` | Rollback unavailable | Jason escalates to manual intervention when rollback fails. |

Main guide:

```text
experiments/manual_demo_pipeline.md
```

Example commands:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\01_successful_delivery_bdi.ps1
powershell -ExecutionPolicy Bypass -File .\experiments\02_telemetry_production_failure_bdi.ps1
powershell -ExecutionPolicy Bypass -File .\experiments\05_transient_health_retry_bdi.ps1
```

Traditional comparison scripts are beside them:

```text
experiments/01_successful_delivery_traditional.ps1
experiments/02_telemetry_production_failure_traditional.ps1
...
experiments/07_rollback_unavailable_traditional.ps1
```

## 13. Full Example: Successful Delivery

```text
Jason starts !deliver_release(candidate)
-> build/test/security pass
-> staging deploy and health pass
-> production deploy and health pass
-> observe(production, canary)
-> telemetry remains stable
-> observation(production,canary,stable)
-> delivery_succeeded(candidate)
-> release_complete
```

Expected final production version:

```text
candidate
```

Guide:

```text
experiments/01_successful_delivery.md
```

## 14. Full Example: Telemetry-Driven Production Failure

This is currently the strongest supervisor demo because it uses real traffic and Prometheus metrics rather than direct belief injection.

```text
Jason deploys candidate to production
-> production /health passes
-> Jason starts observe(production, canary)
-> script/user sends 80 real POST /pay requests
-> PAYMENT_PRODUCTION_FORCE_ERROR_RATE=0.20 causes some requests to fail
-> service.py records request and error counters
-> Prometheus scrapes /metrics
-> CicdEnvironment reads measured error_rate > 0.05
-> Java updates:
     metric(production,error_rate,high)
     environment(production,unstable)
-> AgentSpeak recovery plan becomes applicable
-> Jason calls rollback(production)
-> CicdEnvironment runs rollback.sh
-> status(rollback(production),passed)
-> production_reliability_restored(telemetry_unstable)
-> delivery_failed(candidate,telemetry_unstable)
```

Expected final production version:

```text
stable
```

Recent observed evidence:

```text
[CicdEnvironment][telemetry] production error_rate=0.2222(high) ... environment=unstable
[CicdEnvironment][decision] recovery_reason reason=telemetry_unstable
[CicdEnvironment][decision] production_reliability_restored reason=telemetry_unstable
[CicdEnvironment][decision] delivery_failed reason=telemetry_unstable
```

Guide:

```text
experiments/02_telemetry_production_failure.md
```

## 15. Full Example: Transient Health Failure And Retry

This is the clearest goal-persistence proof.

```text
Production health check fails once
-> Jason records recovery_reason(health_failed)
-> Jason calls rollback(production)
-> production reliability restored
-> Jason records rollback_then_retry_production
-> Jason verifies recovered production
-> Jason records continue_deploy_candidate
-> Jason deploys the same candidate again
-> health and canary pass
-> delivery_succeeded(candidate)
```

Expected final production version:

```text
candidate
```

Guide:

```text
experiments/05_transient_health_retry.md
```

## 16. What Is Real And What Is Forced

Real telemetry-driven scenarios:

```text
01 successful delivery
02 telemetry-driven production failure
03 high latency
04 observability failure
```

These rely on Docker/app behavior, real HTTP traffic, Prometheus scraping, and Java telemetry polling.

Controlled action-result fault injection:

```text
05 transient health failure and retry
06 build/test/security gate failures
07 rollback unavailable
```

These use `BDI_FORCE_*` variables read by `CicdEnvironment.java`. They are useful for proving Jason control flow after failed action percepts, but they are not the same as live telemetry degradation.

Important distinction:

```text
PAYMENT_* variables configure the app container.
BDI_* variables configure the Java/Jason environment.
BDI_FORCE_* variables are test hooks for failed action-result percepts.
```

## 17. Codebase Map

```text
PROJECT
|
|-- app/
|   `-- payment_service/
|       |-- service.py
|       |-- Dockerfile
|       `-- requirements.txt
|
|-- cicd/
|   `-- actions/
|       |-- build.sh
|       |-- test.sh
|       |-- security_scan.sh
|       |-- deploy.sh
|       |-- health_check.sh
|       `-- rollback.sh
|
|-- bdi/
|   |-- project.mas2j
|   |-- deployment_agent.asl
|   |-- build.gradle
|   |-- settings.gradle
|   |-- src/env/
|   |   `-- CicdEnvironment.java
|   `-- logs/
|       `-- cicd_environment.log
|
|-- runtime/
|   |-- prometheus/
|   |   `-- prometheus.yml
|   `-- state/
|       `-- production_version.txt
|
|-- telemetry/
|   |-- thresholds.yml
|   `-- prometheus_adapter.py
|
|-- experiments/
|   |-- manual_demo_pipeline.md
|   |-- scenario_lib.ps1
|   |-- 01_successful_delivery.md
|   |-- 02_telemetry_production_failure.md
|   |-- 03_high_latency.md
|   |-- 04_observability_failure.md
|   |-- 05_transient_health_retry.md
|   |-- 06_gate_failures.md
|   `-- 07_rollback_unavailable.md
|
`-- docs/
    |-- project_guide.md
    `-- extra_information.md
```

## 18. What To Watch During A Demo

Best evidence log:

```text
bdi/logs/cicd_environment.log
```

Look for:

```text
[CicdEnvironment] action ...
[CicdEnvironment][script] ...
[CicdEnvironment] percept ...
[CicdEnvironment][telemetry] ...
[CicdEnvironment][observe] ...
[CicdEnvironment][decision] ...
```

Jason console prints:

```text
[deployment_agent][goal] ...
[deployment_agent][subgoal] ...
[deployment_agent][belief] ...
[deployment_agent][decision] ...
```

Inspect live Jason beliefs:

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD\bdi
jason agent mind deployment_agent
```

Check final production version:

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
Get-Content .\runtime\state\production_version.txt
```

Expected examples:

```text
candidate  -> successful candidate delivery
stable     -> rollback restored production after failed candidate delivery
```

## 19. Best Supervisor Story

Use this simple narrative:

```text
The shell scripts are the same in both controllers.
The traditional controller follows a fixed sequence.
The Jason controller has a goal: deliver candidate while preserving reliability.
It sees action results and Prometheus telemetry as beliefs.
If everything remains healthy, it records delivery_succeeded(candidate).
If /health passes but real /pay traffic creates high error telemetry, it rolls back and records delivery_failed(candidate,telemetry_unstable).
If a production health problem is transient, it restores reliability and retries the same candidate.
```

Recommended live demos:

```text
1. experiments/01_successful_delivery.md
2. experiments/02_telemetry_production_failure.md
3. experiments/05_transient_health_retry.md
```
