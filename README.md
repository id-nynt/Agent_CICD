# BDI CI/CD Research Prototype

This repository is a research prototype that compares a traditional CI/CD pipeline with a BDI-based CI/CD decision layer.

BDI means:

```text
Beliefs -> Desires -> Intentions
```

In this project, the BDI agent does not replace CI/CD scripts. Instead, it reasons over deployment status and telemetry, then chooses what the pipeline should do next.

The current prototype demonstrates two paths:

```text
Traditional CI/CD:
build -> test -> security scan -> deploy -> health check -> release or rollback

BDI CI/CD:
real service -> Prometheus metrics -> telemetry adapter -> beliefs -> BDI reasoning -> release, rollback, pause, or stop
```

The important research idea is:

```text
Keep the CI/CD action interface simple, but make the release decision more context-aware.
```

## What This App Does

The demo application is a small fake payment service.

It exposes:

```text
GET  /health
POST /pay
POST /refund
GET  /metrics
```

It does not connect to a real payment provider. It exists to generate realistic operational telemetry:

```text
request count
error count
latency
availability
stable/candidate version labels
```

Prometheus scrapes those metrics. The telemetry adapter converts them into raw telemetry values. The belief mapper converts those values into symbolic BDI beliefs.

## Architecture

```text
app/payment_service
  /health /pay /refund /metrics
       |
       v
Prometheus
       |
       v
telemetry/prometheus_adapter.py
       |
       v
telemetry/belief_mapper.py
       |
       v
bdi/run_agent_for_scenario.sh
       |
       v
experiments/real_results/*.json
experiments/real_comparison_table.md
```

The traditional action interface remains:

```text
cicd/actions/*.sh
```

## Main Folders

| Path | Purpose |
| --- | --- |
| `app/payment_service/` | Flask payment service with Prometheus metrics and optional OpenTelemetry tracing |
| `cicd/actions/` | Public shell action interface used by traditional and BDI flows |
| `runtime/prometheus/` | Prometheus scrape configuration |
| `telemetry/` | Prometheus adapter, belief mapper, thresholds, tests |
| `bdi/` | Jason/AgentSpeak model and deterministic BDI trace runner |
| `experiments/` | Simulated and real-telemetry experiment runners and outputs |
| `.github/workflows/` | GitHub Actions traditional CI baseline |
| `docs/` | Longer explanation documents |
| `0_private/` | Private notes and roadmap files |

## Prerequisites

Recommended:

```text
Python 3.12
Docker Desktop
Git Bash on Windows
PowerShell
```

On this Windows machine, use `py` instead of `python` if `python` is not on PATH.

## Quick Start

Start the real local runtime:

```powershell
docker compose up --build
```

Check services:

```powershell
Invoke-WebRequest -UseBasicParsing http://localhost:8001/health
Invoke-WebRequest -UseBasicParsing http://localhost:8002/health
Invoke-WebRequest -UseBasicParsing http://localhost:9090/-/ready
```

Open Prometheus targets:

```text
http://localhost:9090/targets
```

Expected services:

| Service | URL | Meaning |
| --- | --- | --- |
| staging payment service | `http://localhost:8001` | Candidate version |
| production payment service | `http://localhost:8002` | Stable or candidate version |
| Prometheus | `http://localhost:9090` | Metrics store/query UI |

## Run The Traditional Action Interface

On Windows PowerShell, run shell scripts through Git Bash:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/build.sh candidate
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/test.sh candidate
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/security_scan.sh candidate
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/deploy.sh staging candidate
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/health_check.sh staging
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/deploy.sh production candidate
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/health_check.sh production
```

Rollback production:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/rollback.sh production
```

## Run Real-Telemetry BDI Experiments

The richer Phase 15 scenario catalog is defined in:

```text
experiments/real_scenarios.yml
```

It describes the intended real telemetry experiments using simple human-readable fields:

```text
description
environment settings for staging and production
traffic pattern
observation count
reobserve expectation
traditional expected decision
BDI expected decision
what the scenario proves
```

Defined scenarios:

| Scenario | What it proves | Expected BDI decision |
| --- | --- | --- |
| `real_success` | Healthy telemetry baseline where traditional CI/CD and BDI agree | `release_complete` |
| `real_high_error_rate` | `/health` passes while business traffic fails | `rollback_production` |
| `real_high_latency` | Successful requests can still be degraded enough to reobserve | `pause_reobserve` |
| `real_low_availability` | Unhealthy production should trigger rollback | `rollback_production` |
| `real_transient_recovery` | BDI can pause and avoid rollback after telemetry recovers | `release_complete` |
| `real_network_suspected` | Ambiguous network context should cause reobservation | `pause_reobserve` |
| `real_staging_failure` | Failed staging blocks production promotion | `stop_pipeline` |
| `real_security_scan_failure` | Failed security scan blocks deployment | `stop_pipeline` |

The real telemetry runner reads this file directly. Run all configured scenarios:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' experiments/run_real_telemetry_scenarios.sh
```

Run one scenario by name:

```powershell
py experiments/real_telemetry_runner.py real_high_error_rate
& 'C:\Program Files\Git\bin\bash.exe' experiments/run_real_telemetry_scenarios.sh real_high_error_rate
```

List available real telemetry scenarios:

```powershell
py experiments/real_telemetry_runner.py --list
```

Outputs:

```text
experiments/real_results/*.json
experiments/real_comparison_table.md
```

Read the summary table:

```powershell
Get-Content experiments/real_comparison_table.md
```

The original key real-telemetry scenario is still supported as a compatibility scenario:

```text
real_production_unstable
```

In that scenario:

```text
/health passes
/pay fails
Prometheus records payment errors
belief_mapper.py creates environment(production, unstable).
BDI chooses rollback_production
```

This demonstrates that BDI can react to real telemetry that a simple health-check-only traditional pipeline can miss.

## Run Simulated Experiments

The older simulated path is still available:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' experiments/run_all_scenarios.sh
```

Outputs:

```text
experiments/results/*.json
experiments/comparison_table.md
```

## Prometheus Telemetry

Generate production traffic:

```powershell
Invoke-RestMethod -Method POST -Uri http://localhost:8002/pay -ContentType "application/json" -Body '{"amount": 10}'
Invoke-RestMethod -Method POST -Uri http://localhost:8002/refund -ContentType "application/json" -Body '{"amount": 10}'
```

Query telemetry:

```powershell
py telemetry/prometheus_adapter.py production --pretty
```

Map adapter JSON into BDI beliefs:

```powershell
py telemetry/prometheus_adapter.py production --pretty | Out-File -Encoding utf8 telemetry/live_production.json
py telemetry/belief_mapper.py telemetry/live_production.json
Get-Content telemetry/generated_beliefs/production_live.asl
```

## How BDI Works Here

The BDI runner consumes symbolic beliefs like:

```prolog
status(build, passed).
status(health_check(production), passed).
metric(production, error_rate, high).
environment(production, unstable).
rollback_available(production).
```

Then it chooses a decision such as:

```text
release_complete
rollback_production
pause_reobserve
stop_pipeline
manual_intervention_required
```

For this prototype, `bdi/run_agent_for_scenario.sh` prints a deterministic modeled BDI trace and also generates Jason files under `bdi/generated/`.

## GitHub Actions Baseline

The workflow:

```text
.github/workflows/traditional-ci.yml
```

runs:

```text
build.sh candidate
test.sh candidate
security_scan.sh candidate
```

It proves that the project has a visible traditional CI baseline using the same shell action interface.

It does not deploy to cloud, run the BDI agent, use GitHub as the BDI control plane, or replace local experiments.

## Optional OpenTelemetry

Prometheus is the primary telemetry path. OpenTelemetry is only an optional reference.

Enable console tracing:

```powershell
$env:ENABLE_OTEL="true"
py app/payment_service/service.py
```

Call:

```powershell
Invoke-RestMethod -Method POST -Uri http://localhost:8000/pay -ContentType "application/json" -Body '{"amount": 10}'
```

The service console prints OpenTelemetry span JSON for the payment operation.

## What This Prototype Can Prove

This prototype can show:

```text
Traditional CI/CD can pass when /health is OK.
Real payment traffic can still fail even when /health is OK.
Prometheus can expose those failures as metrics.
Metrics can be converted into symbolic beliefs.
BDI can choose rollback based on telemetry-derived beliefs.
The old simulated scenario path still works.
```

This prototype does not claim:

```text
full production readiness
real payment processing
cloud deployment
Kubernetes orchestration
machine learning prediction
GitHub-controlled BDI automation
multi-agent coordination
```

## More Reading

Start with:

```text
docs/pipeline_explanation.md
telemetry/README.md
bdi/README.md
experiments/real_comparison_table.md
```

Private explanatory notes are under:

```text
0_private/
```
