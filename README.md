# BDI CI/CD Research Prototype

This repository is a local research prototype for autonomous CI/CD using a Jason BDI agent.

The current real controller path is:

```text
Jason deployment_agent.asl
  -> CicdEnvironment.java
  -> cicd/actions/*.sh
  -> Docker Compose payment service
  -> Prometheus telemetry
  -> CicdEnvironment.java telemetry polling
  -> Jason percepts and AgentSpeak plans
```

The older generated-belief path still exists, but it is legacy scaffolding. When `bdi/run_agent_for_scenario.sh` is run without `--jason`, its trace is modeled by Bash from generated `.asl` files. That path is useful for historical comparison only; it is not evidence that Jason selected plans.

## What Starts The Demo

Closed-loop demo:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\run_bdi_closed_loop.ps1
```

Scenario-suite demo:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\run_bdi_scenario_suite.ps1 -Scenario production_high_error_rate
```

Traditional-vs-BDI comparison:

```powershell
py .\experiments\run_traditional_vs_bdi_comparison.py --scenarios success_stable production_high_error_rate high_latency
```

Manual Jason run:

```powershell
cd bdi
jason project.mas2j
```

## Components

| Component | Where | One-sentence role |
| --- | --- | --- |
| Payment service | `app/payment_service/service.py` | Flask service that exposes `/health`, `/pay`, `/refund`, and `/metrics`. |
| Docker Compose | `docker-compose.yml` | Runs staging, production, and Prometheus containers locally. |
| Shell actions | `cicd/actions/*.sh` | Public CI/CD action interface used by both traditional and BDI flows. |
| Prometheus | `runtime/prometheus/prometheus.yml` | Scrapes payment-service `/metrics` every 5 seconds. |
| Jason MAS | `bdi/project.mas2j` | Starts `deployment_agent` with `CicdEnvironment`. |
| BDI agent | `bdi/deployment_agent.asl` | Holds goals, plans, beliefs, and decisions. |
| Jason environment bridge | `bdi/src/env/CicdEnvironment.java` | Executes shell actions and converts action results plus telemetry into Jason percepts. |
| Scenario runner | `experiments/run_bdi_scenario_suite.ps1` | Configures stimuli, starts Jason, sends traffic, and records evidence without choosing BDI decisions. |
| Comparison runner | `experiments/run_traditional_vs_bdi_comparison.py` | Runs fixed pipeline and Jason BDI paths over selected scenarios and writes a comparison report. |

## What Calls What

```text
run_bdi_closed_loop.ps1 or run_bdi_scenario_suite.ps1
  -> jason project.mas2j
    -> bdi/deployment_agent.asl
      -> external action build(candidate)
        -> CicdEnvironment.executeAction(...)
          -> cicd/actions/build.sh candidate
      -> external action deploy(candidate, production)
        -> CicdEnvironment.executeAction(...)
          -> cicd/actions/deploy.sh production candidate
            -> docker compose up payment-production
      -> external action rollback(production)
        -> CicdEnvironment.executeAction(...)
          -> cicd/actions/rollback.sh production
            -> docker compose up payment-production with stable version
```

Prometheus telemetry path:

```text
payment service /pay, /refund, /health
  -> prometheus_client counters, histograms, gauges
  -> /metrics
  -> Prometheus scrape
  -> CicdEnvironment HTTP query to Prometheus API
  -> Jason percepts such as metric(production,error_rate,high)
  -> deployment_agent.asl reactive plans
```

## Telemetry And Beliefs

Telemetry originates in `app/payment_service/service.py`:

```text
payment_service_requests_total
payment_service_errors_total
payment_service_request_latency_seconds
payment_service_health
```

Prometheus obtains it through `runtime/prometheus/prometheus.yml`, which scrapes:

```text
payment-staging:8000/metrics
payment-production:8000/metrics
```

In the real Jason controller path, telemetry is converted into BDI percepts in:

```text
bdi/src/env/CicdEnvironment.java
```

The live beliefs are stored inside the running Jason agent belief base. Inspect them with:

```powershell
cd bdi
jason agent mind deployment_agent
```

Common evidence:

```text
metric(production,error_rate,high)[source(percept)]
environment(production,unstable)[source(percept)]
decision(rollback_production)[source(self)]
status(rollback(production),passed)[source(percept)]
```

## Complete Failure Path Example

Tested scenario: `production_high_error_rate`.

```text
1. Scenario runner starts Jason with PAYMENT_PRODUCTION_FAILURE_MODE=pay_error.
2. Jason deploys candidate through deploy(candidate, production).
3. CicdEnvironment calls cicd/actions/deploy.sh production candidate.
4. Production /health passes.
5. Runner sends POST /pay traffic as stimulus only.
6. service.py records failed /pay requests in Prometheus metrics.
7. Prometheus scrapes /metrics.
8. CicdEnvironment queries Prometheus.
9. CicdEnvironment updates metric(production,error_rate,high).
10. CicdEnvironment updates environment(production,unstable).
11. deployment_agent.asl reactive +environment(production, unstable) plan applies.
12. Agent adopts !recover_production(telemetry_unstable).
13. Agent executes rollback(production).
14. CicdEnvironment calls cicd/actions/rollback.sh production.
15. Rollback redeploys stable production.
16. CicdEnvironment adds status(rollback(production),passed) and environment(production,stable).
```

Expected log evidence:

```text
[CicdEnvironment][telemetry] production error_rate=1.0000(high) ... environment=unstable
[CicdEnvironment][decision] recovery_reason reason=telemetry_unstable
[CicdEnvironment] action ... cicd\actions\rollback.sh production
[CicdEnvironment] percept status(rollback(production), passed)
[CicdEnvironment][decision] rollback_production
```

Necessary files for that scenario:

```text
bdi/project.mas2j
bdi/deployment_agent.asl
bdi/src/env/CicdEnvironment.java
cicd/actions/build.sh
cicd/actions/test.sh
cicd/actions/security_scan.sh
cicd/actions/deploy.sh
cicd/actions/health_check.sh
cicd/actions/rollback.sh
app/payment_service/service.py
app/payment_service/Dockerfile
app/payment_service/requirements.txt
docker-compose.yml
runtime/prometheus/prometheus.yml
telemetry/thresholds.yml
experiments/bdi_scenario_catalog.json
experiments/run_bdi_scenario_suite.ps1
```

## Documentation Map

| Document | Purpose |
| --- | --- |
| `docs/beginner_guide.md` | High-level beginner explanation of the whole project. |
| `docs/execution_walkthrough.md` | Detailed behind-the-stage execution path and data flow. |
| `docs/codebase_architecture.md` | Folder tree, component map, and architecture diagrams. |
| `docs/architecture.md` | Component architecture and complete execution trace. |
| `docs/bdi_goal_model.md` | Agent goals, plans, beliefs, and decisions. |
| `docs/bdi_scenario_suite.md` | Scenario catalog and test commands. |
| `docs/traditional_vs_bdi_comparison.md` | Fair comparison method and report location. |
| `bdi/README.md` | Jason-specific runtime notes. |
| `bdi/audit_current_runtime.md` | Audit of legacy modeled traces vs real Jason execution. |

## Limitations

This prototype does not claim production readiness. It does not implement Kubernetes, cloud deployment, multi-agent coordination, machine learning, persistent event storage, or real payment processing.

The reliable research claim is narrower: a Jason BDI controller can invoke the same CI/CD shell actions as a fixed pipeline, perceive action and Prometheus results as beliefs, and choose context-sensitive plans such as release, rollback, pause/reobserve, stop, or manual intervention.
