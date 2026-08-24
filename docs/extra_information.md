# Extra Information: Current Architecture, Diagrams, And Workflow

This document summarizes the current version of the BDI CI/CD prototype.

It reflects the newer implementation where Jason does not immediately accept a release after `/health` passes. Instead, the agent enters a production canary observation window so telemetry can change beliefs before the final decision.

## Project Idea In One Paragraph

This project compares a fixed CI/CD pipeline with a Jason BDI controller. Both use the same local payment service and the same shell action interface under `cicd/actions/`. The difference is the controller. A traditional pipeline follows a fixed sequence and usually accepts production when scripts and `/health` pass. The BDI controller keeps symbolic beliefs about action results and production telemetry, then selects plans such as `delivery_succeeded`, `delivery_failed`, `delivery_deferred`, `production_reliability_restored`, `rollback_production`, `pause_reobserve`, or `manual_intervention_required`.

## Current Controller Boundary

The real BDI path is:

```text
bdi/project.mas2j
-> bdi/deployment_agent.asl
-> bdi/src/env/CicdEnvironment.java
-> cicd/actions/*.sh
-> Docker Compose payment service + Prometheus
```

The legacy/scaffolding path is separate:

```text
bdi/cicd_agent.asl
bdi/run_agent_for_scenario.sh
telemetry/generated_beliefs/
experiments/archive/
```

Those legacy files can be useful for historical explanation, but they are not the strongest current demo evidence.

## Diagram: Traditional Pipeline Vs BDI Controller

```text
                         SAME LOCAL SYSTEM

                  payment service candidate
                            |
                            v
                  same shell action scripts
                            |
              +-------------+-------------+
              |                           |
              v                           v
       Traditional pipeline          Jason BDI controller
       fixed control flow            beliefs + goals + plans
              |                           |
              v                           v
       build/test/deploy            build/test/deploy actions
              |                           |
              v                           v
       production /health           production /health
              |                           |
              v                           v
       release success              observe(production, canary)
                                          |
                                          v
                                Prometheus telemetry beliefs
                                          |
                         +----------------+----------------+
                         |                                 |
                         v                                 v
              stable -> delivery_succeeded     unstable -> recovery plan
                                                        |
                                                        v
                                                 rollback(production)
```

## Diagram: Current BDI Perception-Reasoning-Action Loop

```text
Application/environment changes
        |
        v
Payment service exposes /metrics
        |
        v
Prometheus scrapes /metrics
        |
        v
CicdEnvironment polls Prometheus
        |
        v
CicdEnvironment applies thresholds
        |
        v
Jason percepts are updated:
  metric(production,error_rate,high/normal)
  metric(production,latency,high/normal)
  metric(production,availability,high/low)
  environment(production,stable/unstable)
        |
        v
deployment_agent receives belief/event changes
        |
        v
AgentSpeak context conditions select a plan
        |
        v
Jason invokes an external action:
  deploy(...)
  health_check(...)
  rollback(...)
  observe(...)
        |
        v
CicdEnvironment executes or observes the real local system
        |
        v
New state and telemetry are perceived again
```

## Current Release Workflow

The root goal is:

```text
!deliver_release(candidate)
```

The current sequence is:

```text
!prepare_candidate(candidate)
  -> build(candidate)
  -> status(build, passed/failed)

!validate_candidate(candidate)
  -> test(candidate)
  -> status(test, passed/failed)
  -> security_scan(candidate)
  -> status(security_scan, passed/failed)

!deploy_to_staging(candidate)
  -> deploy(candidate, staging)
  -> status(deploy(staging), passed/failed)

!verify_staging
  -> health_check(staging)
  -> status(health_check(staging), passed/failed)
  -> environment(staging, stable/unstable)

!deploy_to_production(candidate)
  -> deploy(candidate, production)
  -> status(deploy(production), passed/failed)

!verify_production
  -> health_check(production)
  -> status(health_check(production), passed/failed)

!observe_production_canary
  -> observe(production, canary)
  -> observation(production, canary, stable/unstable/unknown)

!maintain_reliability
  -> delivery_succeeded, delivery_failed, delivery_deferred,
     rollback, pause/reobserve, or manual intervention
```

The important current addition is:

```text
observe(production, canary)
```

This creates time for Prometheus and `CicdEnvironment` to update telemetry beliefs before Jason records a delivery outcome.

## Current Goal Hierarchy

```text
!start_controller
`-- !deliver_release(candidate)
    |-- !prepare_candidate(candidate)
    |   `-- !run_build(candidate)
    |
    |-- !validate_candidate(candidate)
    |   |-- !run_tests(candidate)
    |   `-- !run_security_scan(candidate)
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

## Current Recovery And Decision Model

### Stop Release

Used for early gate failures:

```text
status(build, failed)         -> !stop_release(build_failed)
status(test, failed)          -> !stop_release(test_failed)
status(security_scan, failed) -> !stop_release(security_failed)
staging unstable              -> !stop_release(staging_unstable)
```

Decision evidence:

```text
decision(delivery_failed)
delivery_failed(candidate, Reason)
delivery_failure_reason(...)

or

decision(delivery_deferred)
delivery_deferred(candidate, Reason)
delivery_defer_reason(...)
```

### Production Recovery

Used for production failure or production telemetry instability:

```text
status(deploy(production), failed)
  -> !recover_production(deploy_failed)

status(health_check(production), failed)
  -> !recover_production(health_failed)

observation(production, canary, unstable)
  -> !recover_production(telemetry_unstable)

environment(production, unstable) after deployment
  -> recovery, pause/reobserve, or manual intervention depending on context
```

Decision evidence:

```text
recovery_reason(...)
production_reliability_restored
production_reliability_restored(...)
decision(rollback_production)
status(rollback(production), passed)
```

### Pause/Reobserve

Used when the agent should not immediately rollback:

```text
metric(production,latency,high)
and not metric(production,error_rate,high)
  -> !pause_reobserve(high_latency)

telemetry(production,unavailable)
  -> !pause_reobserve(network_suspected)
```

Decision evidence:

```text
decision(pause_reobserve)
reobserve_reason(high_latency)
reobserve_reason(network_suspected)
```

### Rollback Then Retry

The current model supports retrying the same candidate only for transient production health failure:

```text
health_check(production) fails
-> rollback(production)
-> recovered production health passes
-> continue_deploy_candidate
-> deploy candidate to production again
```

It does not retry the same candidate after high-error telemetry, because that likely means the candidate behavior itself is faulty.

Decision evidence:

```text
decision(rollback_then_retry_production)
decision(continue_deploy_candidate)
delivery_succeeded(candidate)
decision(delivery_succeeded)
```

## Telemetry Classification Rules

Thresholds are loaded from:

```text
telemetry/thresholds.yml
```

The current semantics are:

| Raw Prometheus metric | Rule | Jason percept |
| --- | --- | --- |
| Error rate | `> 0.05` | `metric(production,error_rate,high)` |
| Error rate | `<= 0.05` | `metric(production,error_rate,normal)` |
| P95 latency | `> 500 ms` | `metric(production,latency,high)` |
| P95 latency | `<= 500 ms` | `metric(production,latency,normal)` |
| Availability | `< 0.99` | `metric(production,availability,low)` |
| Availability | `>= 0.99` | `metric(production,availability,high)` |

Overall production state:

```text
any bad metric -> environment(production,unstable)
all normal     -> environment(production,stable)
poll failure   -> telemetry(production,unavailable)
                  network(production,suspected)
                  environment(production,unstable)
```

## Where Telemetry Comes From

The payment service exposes:

```text
GET /metrics
```

Prometheus scrapes metrics from the Docker services using:

```text
runtime/prometheus/prometheus.yml
```

The Java environment queries Prometheus directly:

```text
CicdEnvironment.java
```

It does not rely on generated belief files for the current live path.

## Current Timing Model

Important environment variables:

```text
BDI_TELEMETRY_ENABLED
BDI_TELEMETRY_INTERVAL_SECONDS
BDI_TELEMETRY_GRACE_SECONDS
BDI_OBSERVE_PRODUCTION_CANARY_MS
```

Typical demo values:

```powershell
$env:BDI_TELEMETRY_ENABLED="true"
$env:BDI_TELEMETRY_INTERVAL_SECONDS="3"
$env:BDI_TELEMETRY_GRACE_SECONDS="5"
$env:BDI_OBSERVE_PRODUCTION_CANARY_MS="25000"
```

Why this matters:

```text
Production /health may pass quickly.
The canary observation window keeps Jason from finalizing immediately.
During that window, traffic can change metrics.
Prometheus can scrape those metrics.
CicdEnvironment can convert them into beliefs.
Jason can choose a plan before it records `delivery_succeeded(candidate)`.
```

## Full Example: Successful Path

```text
Jason: !deliver_release(candidate)
  |
  v
CicdEnvironment: build(candidate)
  |
  v
Shell: cicd/actions/build.sh candidate
  |
  v
Percept: status(build, passed)
  |
  v
test/security/staging/production actions pass
  |
  v
Percept: status(health_check(production), passed)
  |
  v
Jason: observe(production, canary)
  |
  v
CicdEnvironment polls telemetry during observation
  |
  v
Percepts:
  metric(production,error_rate,normal)
  metric(production,latency,normal)
  environment(production,stable)
  observation(production,canary,stable)
  |
  v
Jason outcome:
  delivery_succeeded(candidate)
  decision(delivery_succeeded)
  decision(release_complete)
```

Expected final production version:

```text
candidate
```

Run guide:

```text
experiments/demo_successful_path.md
```

Automation:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\demo_successful_path.ps1
```

## Full Example: Telemetry-Driven Failure Path

This is the strongest current demo because it does not use `BDI_FORCE_*` failure injection.

```text
Jason deploys candidate to production
  |
  v
Production /health passes
  |
  v
Jason starts observe(production, canary)
  |
  v
User/script sends POST /pay traffic
  |
  v
Payment service produces errors
  |
  v
Prometheus scrapes /metrics
  |
  v
CicdEnvironment polls Prometheus
  |
  v
Percepts:
  metric(production,error_rate,high)
  environment(production,unstable)
  observation(production,canary,unstable)
  |
  v
Jason plan:
  !recover_production(telemetry_unstable)
  |
  v
Jason action:
  rollback(production)
  |
  v
CicdEnvironment:
  cicd/actions/rollback.sh production
  |
  v
Percept:
  status(rollback(production), passed)
  |
  v
Jason decision:
  production_reliability_restored
  delivery_failed(candidate,candidate_unsafe)
  rollback_production
```

Expected final production version:

```text
stable
```

Run guide:

```text
experiments/demo_failed_telemetry_path.md
```

Automation:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\demo_failed_telemetry_path.ps1
```

## Full Example: Goal Persistence After Recoverable Failure

This is the clearest current demo that the agent keeps pursuing candidate delivery after a recoverable production problem.

```text
Jason deploys candidate to production
  |
  v
Production health check fails once
  |
  v
Jason chooses recovery_reason(health_failed)
  |
  v
Jason calls rollback(production)
  |
  v
Production stable version is restored
  |
  v
Jason records production_reliability_restored(health_failed)
  |
  v
Jason records rollback_then_retry_production
  |
  v
Jason verifies recovered production is healthy
  |
  v
Jason records continue_deploy_candidate
  |
  v
Jason deploys the same candidate again
  |
  v
Production health and canary observation pass
  |
  v
Jason records delivery_succeeded(candidate)
```

Evidence from the focused test:

```text
goal_persistence_test=True
[CicdEnvironment][decision] production_reliability_restored reason=health_failed
[CicdEnvironment][decision] rollback_then_retry_production reason=health_failed
[CicdEnvironment][decision] continue_deploy_candidate reason=health_failed
[CicdEnvironment][decision] delivery_succeeded reason=candidate
```

What this proves:

```text
Rollback is not treated as candidate delivery success.
Rollback first restores production reliability.
Then Jason explicitly continues pursuing the original candidate delivery goal.
```

## What Is Forced And What Is Real?

### Real Telemetry-Driven Evidence

These scenarios are the strongest proof that the agent perceives environment changes:

```text
successful path
production high error rate during canary
high latency during canary
Prometheus unavailable during canary
transient telemetry recovery
```

They work by changing application behavior or observability, sending real traffic, and letting Prometheus/Jason beliefs update.

### Controlled Action-Result Fault Injection

These scenarios use `BDI_FORCE_*` variables:

```text
build failure
test failure
security failure
staging health failure
production health failure
rollback unavailable
```

They are useful for testing BDI control flow after action-result percepts, but they are not the main proof of live telemetry reasoning.

Current limitation:

```text
Build/test/security failure cannot yet be triggered midway from another terminal.
They are configured before Jason starts.
```

To support true midway gate injection later, add a runtime control channel such as:

```text
runtime/control/fail_next_stage.txt
```

Then `CicdEnvironment.java` could consume the file before each action.

## Codebase Map

```text
PROJECT
|
|-- app/
|   `-- payment_service/
|       |-- service.py
|       `-- Dockerfile
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
|-- runtime/
|   |-- prometheus/
|   |   `-- prometheus.yml
|   `-- state/
|       `-- production_version.txt
|
|-- telemetry/
|   |-- thresholds.yml
|   |-- prometheus_adapter.py
|   `-- belief_mapper.py        legacy/helper, not the live Java path
|
|-- bdi/
|   |-- project.mas2j
|   |-- deployment_agent.asl
|   |-- src/env/
|   |   `-- CicdEnvironment.java
|   `-- logs/
|       `-- cicd_environment.log
|
|-- experiments/
|   |-- demo_successful_path.md
|   |-- demo_successful_path.ps1
|   |-- demo_failed_telemetry_path.md
|   |-- demo_failed_telemetry_path.ps1
|   |-- manual_demo_pipeline.md
|   `-- archive/
|       `-- older scenario-suite and comparison artifacts
|
`-- docs/
    `-- extra_information.md
```

## What To Watch In The MAS Console Or Log

Jason AgentSpeak output:

```text
[deployment_agent][goal] ...
[deployment_agent][subgoal] ...
[deployment_agent][belief] ...
[deployment_agent][decision] ...
```

Java environment output:

```text
[CicdEnvironment] action ...
[CicdEnvironment][script] ...
[CicdEnvironment] exit_code=...
[CicdEnvironment] percept ...
[CicdEnvironment][telemetry] ...
[CicdEnvironment][observe] ...
[CicdEnvironment][decision] ...
```

The same Java environment evidence is saved to:

```text
bdi/logs/cicd_environment.log
```

## Java Environment Summary

`CicdEnvironment.java` is the bridge between Jason and the real local system.

```text
Jason action -> Java bridge -> shell script -> Docker/payment service
```

Examples:

```text
build(candidate)              -> cicd/actions/build.sh candidate
test(candidate)               -> cicd/actions/test.sh candidate
security_scan(candidate)      -> cicd/actions/security_scan.sh candidate
deploy(candidate, staging)    -> cicd/actions/deploy.sh staging candidate
deploy(candidate, production) -> cicd/actions/deploy.sh production candidate
health_check(production)      -> cicd/actions/health_check.sh production
rollback(production)          -> cicd/actions/rollback.sh production
observe(production, canary)   -> timed observation while telemetry polling continues
```

The same class also converts the real world back into Jason percepts:

```text
script exit code -> status(..., passed/failed)
health check     -> environment(..., stable/unstable)
Prometheus query -> metric(...), environment(...)
observation      -> observation(..., stable/unstable/unknown)
```

## Current Best Demo Story

For supervisor review, lead with these two demos:

```text
1. Successful path:
   experiments/demo_successful_path.md

2. Telemetry-driven failed path:
   experiments/demo_failed_telemetry_path.md
```

The failed path is the clearest BDI contribution:

```text
/health passes
but /pay telemetry becomes bad during canary
therefore Jason rolls back before accepting the release
```
