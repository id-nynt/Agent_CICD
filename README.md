# BDI CI/CD Research Prototype

This repository is a local prototype for autonomous CI/CD using a Jason BDI agent.

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

Current recommended successful-path demo:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\demo_successful_path.ps1
```

Current recommended telemetry-failure demo:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\demo_failed_telemetry_path.ps1
```

Manual Jason run:

```powershell
cd bdi
jason project.mas2j
```

## Components

| Component                            | Where                               | One-sentence role                                                                      |
| ------------------------------------ | ----------------------------------- | -------------------------------------------------------------------------------------- |
| Payment service                      | `app/payment_service/service.py`    | Flask service that exposes `/health`, `/pay`, `/refund`, and `/metrics`.               |
| Docker Compose                       | `docker-compose.yml`                | Runs staging, production, and Prometheus containers locally.                           |
| Shell actions                        | `cicd/actions/*.sh`                 | Public CI/CD action interface used by both traditional and BDI flows.                  |
| Prometheus                           | `runtime/prometheus/prometheus.yml` | Scrapes payment-service `/metrics` every 5 seconds.                                    |
| Jason MAS                            | `bdi/project.mas2j`                 | Starts `deployment_agent` with `CicdEnvironment`.                                      |
| BDI agent                            | `bdi/deployment_agent.asl`          | Holds goals, plans, beliefs, and decisions.                                            |
| Jason environment bridge             | `bdi/src/env/CicdEnvironment.java`  | Executes shell actions and converts action results plus telemetry into Jason percepts. |
| Manual demo guides                   | `experiments/demo_*.md`             | Explain the successful path and telemetry-driven failed path step by step.             |
| Demo scripts                         | `experiments/demo_*.ps1`            | Automate the same demos without choosing BDI decisions.                                |
| Archived scenario/comparison runners | `experiments/archive/`              | Older broader scenario-suite and comparison artifacts.                                 |

## What Calls What

```text
demo_successful_path.ps1 or demo_failed_telemetry_path.ps1
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
production_reliability_restored[source(self)]
delivery_failed(candidate,telemetry_unstable)[source(self)]
decision(rollback_production)[source(self)]
status(rollback(production),passed)[source(percept)]
```

## Complete Telemetry Failure Path Example

Recommended demo: `experiments/demo_failed_telemetry_path.ps1`.

```text
1. Demo script starts Jason with PAYMENT_PRODUCTION_FAILURE_MODE=none and PAYMENT_PRODUCTION_FORCE_ERROR_RATE=0.20.
2. Jason deploys candidate through deploy(candidate, production).
3. CicdEnvironment calls cicd/actions/deploy.sh production candidate.
4. Production /health passes.
5. Jason starts observe(production, canary).
6. Demo sends controlled POST /pay traffic as stimulus only.
7. service.py records request metrics and probabilistic failed /pay requests in Prometheus metrics.
8. Prometheus scrapes /metrics.
9. CicdEnvironment queries Prometheus.
10. CicdEnvironment updates metric(production,error_rate,high).
11. CicdEnvironment updates environment(production,unstable).
12. CicdEnvironment emits observation(production,canary,unstable).
13. deployment_agent.asl selects production recovery.
14. Agent executes rollback(production).
15. CicdEnvironment calls cicd/actions/rollback.sh production.
16. Rollback redeploys stable production.
17. Agent records production_reliability_restored.
18. Agent records delivery_failed(candidate,telemetry_unstable).
```

Expected log evidence:

```text
[CicdEnvironment][telemetry] production error_rate=0.xxxx(high) ... environment=unstable
[CicdEnvironment][decision] recovery_reason reason=telemetry_unstable
[CicdEnvironment] action ... cicd\actions\rollback.sh production
[CicdEnvironment] percept status(rollback(production), passed)
[CicdEnvironment][decision] production_reliability_restored reason=telemetry_unstable
[CicdEnvironment][decision] delivery_failed reason=telemetry_unstable
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
experiments/demo_failed_telemetry_path.md
experiments/demo_failed_telemetry_path.ps1
```

## Goal-Persistence Proof Case

The focused recoverable-failure test uses a one-time production health failure:

```text
health_check(production) fails once
-> Jason restores production reliability with rollback
-> Jason verifies recovered production
-> Jason retries the same candidate
-> Jason records delivery_succeeded(candidate)
```

Observed evidence:

```text
goal_persistence_test=True
[CicdEnvironment][decision] production_reliability_restored reason=health_failed
[CicdEnvironment][decision] rollback_then_retry_production reason=health_failed
[CicdEnvironment][decision] continue_deploy_candidate reason=health_failed
[CicdEnvironment][decision] delivery_succeeded reason=candidate
```

## Documentation Map

| Document                                    | Purpose                                                        |
| ------------------------------------------- | -------------------------------------------------------------- |
| `docs/extra_information.md`                 | Current architecture, diagrams, goal outcomes, and demo story. |
| `experiments/manual_demo_pipeline.md`       | Manual demo workflow and scenario trigger guidance.            |
| `experiments/demo_successful_path.md`       | Step-by-step successful-path demo.                             |
| `experiments/demo_failed_telemetry_path.md` | Step-by-step telemetry-driven failed-path demo.                |
| `bdi/README.md`                             | Jason-specific runtime notes.                                  |
| `bdi/audit_current_runtime.md`              | Audit of legacy modeled traces vs real Jason execution.        |

## Limitations

This prototype does not claim production readiness. It does not implement Kubernetes, cloud deployment, multi-agent coordination, machine learning, persistent event storage, or real payment processing.

The reliable research claim is narrower: a Jason BDI controller can invoke the same CI/CD shell actions as a fixed pipeline, perceive action and Prometheus results as beliefs, distinguish candidate delivery outcomes from production reliability restoration, and choose context-sensitive plans such as delivery success, delivery failure, delivery deferral, rollback, pause/reobserve, or manual intervention.
