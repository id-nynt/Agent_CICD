# Autonomous CI/CD With a Jason BDI Agent

This repository is a prototype for **autonomous CI/CD using a Belief-Desire-Intention (BDI) agent**. It compares a traditional fixed deployment pipeline with a Jason-based controller that can perceive CI/CD results and Prometheus telemetry, reason over those beliefs, and choose whether to continue delivery, pause, retry, rollback, defer, fail, or request manual intervention.

The prototype simulates deployment of a local payment service. It is not production-ready infrastructure; it is a controlled research environment for showing how BDI reasoning can make deployment decisions more adaptive and explainable.

## Research Idea

The BDI controller pursues this objective:

```text
Deliver the candidate successfully while preserving production reliability.
```

Rollback is not counted as delivery success. Rollback is a safety action that can restore production reliability while the candidate may still fail or be deferred.

The agent records outcomes such as:

```text
delivery_succeeded(candidate)
delivery_failed(candidate, Reason)
delivery_deferred(candidate, Reason)
production_reliability_restored
```

## Architecture

```text
User or experiment script
        |
        v
Jason MAS: bdi/project.mas2j
        |
        v
BDI agent: bdi/deployment_agent.asl
        |
        | external actions: build, test, deploy, observe, rollback
        v
Java environment: bdi/src/env/CicdEnvironment.java
        |
        | runs the public CI/CD scripts
        v
cicd/actions/*.sh
        |
        v
Docker Compose
        |
        +--> payment-staging      http://localhost:8001
        +--> payment-production   http://localhost:8002
        `--> prometheus           http://localhost:9090
```

Telemetry closes the loop:

```text
payment service traffic
  -> /metrics
  -> Prometheus scrape
  -> CicdEnvironment polling
  -> Jason percepts
  -> AgentSpeak plans
  -> next CI/CD action
```

## Main Components

| Component         | Location                                       | Purpose                                                                           |
| ----------------- | ---------------------------------------------- | --------------------------------------------------------------------------------- |
| Payment service   | `app/payment_service/service.py`               | Flask service with `/health`, `/pay`, `/refund`, and `/metrics`.                  |
| Docker Compose    | `docker-compose.yml`                           | Runs staging, production, and Prometheus locally.                                 |
| CI/CD actions     | `cicd/actions/*.sh`                            | Shared action interface for both traditional and BDI flows.                       |
| Jason project     | `bdi/project.mas2j`                            | Starts the Jason MAS and registers the Java environment.                          |
| BDI agent         | `bdi/deployment_agent.asl`                     | Contains goals, beliefs, plans, recovery logic, and outcome semantics.            |
| Java bridge       | `bdi/src/env/CicdEnvironment.java`             | Executes shell actions and converts action/telemetry results into Jason percepts. |
| Prometheus config | `runtime/prometheus/prometheus.yml`            | Scrapes staging and production metrics.                                           |
| Thresholds        | `telemetry/thresholds.yml`                     | Defines when telemetry becomes normal/high/low.                                   |
| Experiment guides | `experiments/01_*.md` to `experiments/07_*.md` | Manual scenario instructions and expected evidence.                               |

## BDI Execution Workflow

The BDI execution path is:

```text
bdi/project.mas2j
-> bdi/deployment_agent.asl
-> bdi/src/env/CicdEnvironment.java
-> cicd/actions/*.sh
-> docker-compose.yml
-> app/payment_service/service.py
-> Prometheus
-> CicdEnvironment.java
-> Jason beliefs and plans
```

Jason executes the agent plans. The Java environment runs the shell scripts. Prometheus telemetry is queried and converted into Jason percepts such as:

```text
metric(production,error_rate,high)
metric(production,latency,normal)
metric(production,availability,high)
environment(production,unstable)
status(rollback(production),passed)
```

## Prerequisites

Install and start:

```text
Docker Desktop
PowerShell
Git Bash
Java
Gradle
Jason
```

The scripts assume Jason can be run with:

```powershell
jason project.mas2j
```

Before the first Jason run, build the Java environment:

```powershell
cd bdi
gradle build
```

## Quick Start

Run the successful BDI delivery scenario:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\01_successful_delivery_bdi.ps1
```

Run the telemetry-driven production failure scenario:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\02_telemetry_production_failure_bdi.ps1
```

Run all numbered experiments:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\run_all_numbered_experiments.ps1
```

Results are stored under:

```text
experiments/results/<timestamp>/
```

The latest recorded comparison from this workspace is:

```text
experiments/results/20260825_124329/traditional_vs_bdi_comparison.md
experiments/results/20260825_124329/traditional_vs_bdi_comparison_observed.md
```

## Manual Jason Run

To start the agent directly:

```powershell
cd bdi
$env:BDI_TELEMETRY_ENABLED="true"
$env:BDI_TELEMETRY_INTERVAL_SECONDS="3"
$env:BDI_TELEMETRY_GRACE_SECONDS="5"
$env:BDI_OBSERVE_PRODUCTION_CANARY_MS="15000"
jason project.mas2j
```

This starts Jason. Docker starts later when the agent chooses actions such as `deploy(candidate, staging)` or `deploy(candidate, production)`. Those actions are passed to `CicdEnvironment.java`, which runs the matching script in `cicd/actions/`.

Inspect the live Jason belief base:

```powershell
cd bdi
jason agent mind deployment_agent
```

Read the Java bridge log:

```powershell
cd bdi
Get-Content .\logs\cicd_environment.log -Tail 80
```

## Scenario Suite

| Scenario                          | BDI capability demonstrated                                                                             |
| --------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `01_successful_delivery`          | Completes build, validation, staging, production, canary observation, and release success.              |
| `02_telemetry_production_failure` | Uses real `/pay` traffic and Prometheus error-rate telemetry to trigger rollback and candidate failure. |
| `03_high_latency`                 | Detects high latency and pauses/reobserves instead of blindly accepting the release.                    |
| `04_observability_failure`        | Treats missing telemetry as uncertainty and escalates instead of assuming success.                      |
| `05_transient_health_retry`       | Restores reliability after a transient health failure, then retries the same candidate.                 |
| `06_gate_failures`                | Stops delivery when build, test, or security gates fail.                                                |
| `07_rollback_unavailable`         | Requests manual intervention when rollback itself fails.                                                |

Each scenario has:

```text
experiments/NN_name.md
experiments/NN_name_bdi.ps1
experiments/NN_name_traditional.ps1
```

The manual overview is:

```text
experiments/manual_demo_pipeline.md
```

## Traditional vs BDI Comparison

Both controllers use the same public shell actions under `cicd/actions/`.

The traditional path follows a fixed sequence. It can build, test, deploy, and health-check, but it does not maintain a Jason belief base or select AgentSpeak recovery plans.

The BDI path can use the same actions while also responding to symbolic beliefs such as:

```text
status(test,failed)
metric(production,error_rate,high)
environment(production,unstable)
telemetry(production,unavailable)
```

This makes the comparison fair at the action level while highlighting the difference in controller behavior.

## Important Environment Variables

Application variables configure the Dockerized payment service:

| Variable                                                           | Meaning                                                                                                                                         |
| ------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `PAYMENT_STAGING_FAILURE_MODE` / `PAYMENT_PRODUCTION_FAILURE_MODE` | Maps into the container as `FAILURE_MODE`; values like `none`, `pay_error`, `refund_error`, or `unhealthy` change service behavior.             |
| `PAYMENT_PRODUCTION_FORCE_ERROR_RATE`                              | Maps into the container as `FORCE_ERROR_RATE`; gives each real business request a probability of failure. It does not create traffic by itself. |
| `PAYMENT_PRODUCTION_EXTRA_LATENCY_MS`                              | Maps into the container as `EXTRA_LATENCY_MS`; adds request latency for latency scenarios.                                                      |

BDI variables configure the Java/Jason environment:

| Variable                           | Meaning                                                                                         |
| ---------------------------------- | ----------------------------------------------------------------------------------------------- |
| `BDI_TELEMETRY_ENABLED`            | Enables Prometheus polling in `CicdEnvironment.java`.                                           |
| `BDI_TELEMETRY_INTERVAL_SECONDS`   | Controls the polling interval.                                                                  |
| `BDI_TELEMETRY_GRACE_SECONDS`      | Gives the system time before treating telemetry as meaningful.                                  |
| `BDI_OBSERVE_PRODUCTION_CANARY_MS` | Controls how long `observe(production, canary)` waits while telemetry changes can arrive.       |
| `BDI_FORCE_*`                      | Test hooks read by the Java environment to force action failures without editing shell scripts. |

For telemetry-driven scenarios, real traffic still has to be generated. For example, `FORCE_ERROR_RATE=0.20` means roughly 20 percent of real `/pay` requests fail, and those failures update the app metrics that Prometheus scrapes.

## Useful URLs

```text
Staging health:     http://localhost:8001/health
Production health:  http://localhost:8002/health
Production metrics: http://localhost:8002/metrics
Prometheus:         http://localhost:9090
```

`/pay` and `/refund` are POST endpoints. Opening them directly in a browser with GET may show `Method Not Allowed`, which is expected.

## Documentation Map

| Document                              | Purpose                                                                                   |
| ------------------------------------- | ----------------------------------------------------------------------------------------- |
| `docs/project_guide.md`               | Beginner-friendly project guide with phases, architecture, variables, and project status. |
| `docs/extra_information.md`           | More detailed architecture and execution workflow.                                        |
| `experiments/manual_demo_pipeline.md` | Common manual demo process and scenario trigger guidance.                                 |
| `bdi/README.md`                       | Jason-specific runtime notes.                                                             |

## Limitations

This is a local research prototype. It does not implement Kubernetes, cloud deployment, production secrets, persistent event storage, multi-agent coordination, machine learning, or production-grade incident response.

Some failure cases use Java-side test hooks such as `BDI_FORCE_BUILD_FAIL` so the agent can be tested without permanently modifying CI/CD scripts. Telemetry-driven scenarios use actual service traffic, service metrics, Prometheus scraping, Java polling, and Jason percept updates.

The research claim is intentionally narrow: a plain Jason BDI controller can execute the same CI/CD action interface as a traditional pipeline, perceive action and telemetry results as beliefs, and choose more explainable context-sensitive responses than a fixed sequence.
