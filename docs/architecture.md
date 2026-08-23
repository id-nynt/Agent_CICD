# Architecture And Execution Trace

This document answers the supervisor trace questions for the current repository.

## 1. What Process Starts The Demo?

The closed-loop demo starts with:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\run_bdi_closed_loop.ps1
```

The scenario-suite demo starts with:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\run_bdi_scenario_suite.ps1 -Scenario production_high_error_rate
```

Both scripts start Jason with:

```text
bdi/project.mas2j
```

which registers:

```mas2j
environment: CicdEnvironment
agents: deployment_agent;
```

## 2. What Components Are Running?

| Component | Runtime form |
| --- | --- |
| Jason MAS | Local Jason process |
| `deployment_agent` | Jason AgentSpeak agent |
| `CicdEnvironment` | Java Jason environment class |
| Payment staging | Docker container on `localhost:8001` |
| Payment production | Docker container on `localhost:8002` |
| Prometheus | Docker container on `localhost:9090` |
| Scenario runner | PowerShell process used for setup/stimulus/evidence |

## 3. What Does Each Component Do?

| Component | One-sentence role |
| --- | --- |
| `deployment_agent.asl` | Chooses CI/CD intentions from beliefs and goals. |
| `CicdEnvironment.java` | Bridges Jason actions/percepts to shell scripts and Prometheus. |
| `cicd/actions/*.sh` | Performs build, test, scan, deploy, health check, and rollback actions. |
| `service.py` | Simulates a payment service and emits Prometheus metrics. |
| Prometheus | Scrapes and stores service metrics. |
| Scenario runner | Starts the local experiment and injects traffic or failure stimuli. |

## 4. What Calls What?

```text
PowerShell runner
  -> jason project.mas2j
    -> deployment_agent.asl
      -> build(candidate)
      -> test(candidate)
      -> security_scan(candidate)
      -> deploy(candidate, staging)
      -> health_check(staging)
      -> deploy(candidate, production)
      -> health_check(production)
      -> rollback(production), when a recovery plan applies
        -> CicdEnvironment.executeAction(...)
          -> cicd/actions/*.sh
            -> docker compose / curl / local checks
```

Telemetry call chain:

```text
service.py
  -> /metrics
  -> Prometheus scrape
  -> CicdEnvironment queryPrometheus(...)
  -> updateMetric(...) and updateStatus(...)
  -> Jason percepts
  -> deployment_agent.asl plans
```

## 5. Where Does Telemetry Originate?

Telemetry originates in:

```text
app/payment_service/service.py
```

The service records:

```text
payment_service_requests_total
payment_service_errors_total
payment_service_request_latency_seconds
payment_service_health
```

## 6. How Does Prometheus Obtain It?

Prometheus uses:

```text
runtime/prometheus/prometheus.yml
```

It scrapes:

```text
payment-staging:8000/metrics
payment-production:8000/metrics
```

The labels `environment: staging` and `environment: production` are added by the Prometheus scrape config.

## 7. Where Is Telemetry Converted Into BDI Beliefs?

In the real Jason controller path, telemetry is converted in:

```text
bdi/src/env/CicdEnvironment.java
```

The relevant methods are:

```text
pollTelemetry(...)
queryPrometheus(...)
updateMetric(...)
updateStatus(...)
```

Thresholds are read from:

```text
telemetry/thresholds.yml
```

The resulting percepts include:

```prolog
metric(production,error_rate,high).
metric(production,latency,normal).
metric(production,availability,high).
environment(production,unstable).
```

The older `telemetry/belief_mapper.py` also converts telemetry JSON into `.asl` files, but that belongs to the legacy generated-belief workflow, not the current persistent Jason controller.

## 8. Where Are The Actual Beliefs Stored?

Live beliefs are stored inside the running Jason agent belief base.

Inspect them with:

```powershell
cd bdi
jason agent mind deployment_agent
```

The local environment also logs percept evidence to:

```text
bdi/logs/cicd_environment.log
```

That log is evidence of what the environment added as percepts or what decision-recording action Jason invoked; it is not the belief base itself.

## 9. Which `.asl` Plans React To Them?

The plans are in:

```text
bdi/deployment_agent.asl
```

Important reactions:

```prolog
+environment(production, unstable)
  : release_monitoring_enabled(production)
    & status(deploy(production), passed)
    & telemetry(production, unavailable)
    & not recovery_attempted(production)
<- !pause_reobserve(network_suspected).
```

```prolog
+environment(production, unstable)
  : release_monitoring_enabled(production)
    & status(deploy(production), passed)
    & metric(production, latency, high)
    & not metric(production, error_rate, high)
    & not recovery_attempted(production)
<- !pause_reobserve(high_latency).
```

```prolog
+environment(production, unstable)
  : release_monitoring_enabled(production)
    & status(deploy(production), passed)
    & not recovery_attempted(production)
<- !recover_production(telemetry_unstable).
```

Rollback result plans:

```prolog
+!handle_rollback_result
  : status(rollback(production), passed)
<- +decision(rollback_production).

+!handle_rollback_result
  : status(rollback(production), failed)
<- +decision(manual_intervention_required).
```

## 10. How Does An Agent Action Affect CI/CD?

AgentSpeak external actions are passed to `CicdEnvironment.executeAction(...)`.

Example:

```prolog
rollback(production)
```

becomes:

```text
CicdEnvironment.runRollback("production")
  -> cicd/actions/rollback.sh production
  -> docker compose up payment-production with stable version
  -> status(rollback(production), passed)
  -> environment(production, stable)
```

## 11. Complete Failure Scenario Trace

Scenario: `production_high_error_rate`.

```text
deployment starts
  -> run_bdi_scenario_suite.ps1 starts Jason MAS
  -> deployment_agent adopts !deliver_release(candidate)

application produces metric X
  -> runner sends POST /pay requests
  -> service.py is configured with FAILURE_MODE=pay_error
  -> payment_service_errors_total increases

Prometheus scrapes /metrics
  -> runtime/prometheus/prometheus.yml scrapes payment-production:8000/metrics

component Y queries metric
  -> CicdEnvironment.pollTelemetry("production")
  -> Prometheus HTTP API query for error rate

Y converts X into belief
  -> CicdEnvironment adds metric(production,error_rate,high)
  -> CicdEnvironment adds environment(production,unstable)

Jason receives belief/percept
  -> deployment_agent belief base contains metric(...)[source(percept)]
  -> deployment_agent belief base contains environment(...)[source(percept)]

plan P becomes applicable
  -> +environment(production, unstable)
     with deployed production and monitoring enabled
     selects !recover_production(telemetry_unstable)

agent chooses rollback
  -> recover plan executes rollback(production)

component Z executes rollback
  -> CicdEnvironment calls cicd/actions/rollback.sh production

old version becomes active
  -> rollback.sh sets PAYMENT_PRODUCTION_VERSION=stable
  -> docker compose recreates payment-production

metrics recover
  -> production service returns to stable/no forced payment error

belief changes
  -> CicdEnvironment records status(rollback(production),passed)
  -> CicdEnvironment records environment(production,stable)
```

## 12. Necessary Files For That Scenario

```text
bdi/project.mas2j
bdi/deployment_agent.asl
bdi/src/env/CicdEnvironment.java
bdi/build.gradle
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

## Expected Evidence

```text
[CicdEnvironment][telemetry] production error_rate=1.0000(high) ... environment=unstable
[CicdEnvironment][decision] recovery_reason reason=telemetry_unstable
[CicdEnvironment] action ... cicd\actions\rollback.sh production
[CicdEnvironment] percept status(rollback(production), passed)
[CicdEnvironment] percept environment(production, stable)
[CicdEnvironment][decision] rollback_production
```

## Boundary Of The Claim

The real BDI claim applies to the persistent Jason path using `deployment_agent.asl` and `CicdEnvironment.java`.

The legacy path using `bdi/run_agent_for_scenario.sh` without `--jason`, `telemetry/generated_beliefs/*.asl`, and `experiments/compile_results.py` is modeled trace scaffolding. It must not be described as Jason making decisions.
