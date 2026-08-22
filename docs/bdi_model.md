# Phase 0 BDI Model

This document defines the initial BDI vocabulary for the research prototype. It is a design document only; it does not implement a Jason agent yet.

The model follows:

```text
events -> telemetry -> beliefs -> goals/plans -> actions -> results
```

## BDI Boundary

The BDI layer should reason over symbolic beliefs, not raw logs or raw metrics. Scenario events and telemetry should be mapped into beliefs before the agent selects goals, plans, and actions.

The initial implementation should use one explainable release agent. Multi-agent coordination is future work.

## Initial Beliefs

Beliefs should be small, explicit, and traceable to events or telemetry.

### Stage Status Beliefs

```prolog
status(build, pending).
status(build, passed).
status(build, failed).

status(test, pending).
status(test, passed).
status(test, failed).

status(security_scan, pending).
status(security_scan, passed).
status(security_scan, failed).

status(deploy(staging), pending).
status(deploy(staging), passed).
status(deploy(staging), failed).

status(health_check(staging), pending).
status(health_check(staging), passed).
status(health_check(staging), failed).

status(deploy(production), pending).
status(deploy(production), passed).
status(deploy(production), failed).

status(health_check(production), pending).
status(health_check(production), passed).
status(health_check(production), failed).
```

### Environment Beliefs

```prolog
environment(staging, stable).
environment(staging, unstable).

environment(production, stable).
environment(production, unstable).
```

### Release Beliefs

```prolog
release(candidate, available).
release(candidate, built).
release(candidate, validated).
release(candidate, deployed_to_staging).
release(candidate, deployed_to_production).

production_version(stable).
previous_production_version(stable).
candidate_version(candidate).
```

### Telemetry-Derived Beliefs

```prolog
metric(production, error_rate, normal).
metric(production, error_rate, high).

metric(production, latency, normal).
metric(production, latency, high).

metric(production, availability, high).
metric(production, availability, low).
```

### Context Beliefs

```prolog
network_issue_suspected(false).
network_issue_suspected(true).

evidence_sufficient(false).
evidence_sufficient(true).

rollback_available(production).
```

### Decision Beliefs

```prolog
decision(release_success).
decision(stop_pipeline).
decision(rollback_production).
decision(pause_reobserve).
decision(abandon_release).
```

## Root Goals

```prolog
!deliver_release.
!maintain_reliability.
!recover_if_failed.
!record_experiment_result.
```

## Subgoals

The first release goal should decompose into simple CI/CD subgoals:

```text
!deliver_release
  -> !prepare_candidate
  -> !validate_candidate
  -> !deploy_to_staging
  -> !verify_staging
  -> !deploy_to_production
  -> !verify_production
  -> !decide_release_outcome
  -> !record_experiment_result
```

Supporting subgoals:

```text
!prepare_candidate
  -> !run_build

!validate_candidate
  -> !run_tests
  -> !run_security_scan

!maintain_reliability
  -> !observe_production
  -> !evaluate_production_health

!recover_if_failed
  -> !choose_recovery_action
  -> !rollback_production or !pause_and_reobserve
```

## Plans

Plans should stay close to the action vocabulary and belief model.

### Success Path

```text
When !deliver_release:
  run build
  run tests
  run security scan
  deploy to staging
  verify staging
  deploy to production
  verify production
  record release_success
```

### Failed Pre-Production Path

```text
If build, test, security, staging deploy, or staging health fails:
  stop before production
  record stop_pipeline or abandon_release
```

### Production Unstable Path

```text
If production health fails and telemetry maps to environment(production, unstable):
  satisfy !recover_if_failed
  choose rollback(production)
  record rollback_production
```

### Network Or Uncertain Evidence Path

```text
If production health fails and network_issue_suspected(true):
  pause
  reobserve production
  update beliefs
  choose rollback or continue based on updated beliefs
```

### Recovery Before Rollback Completes

```text
If rollback is planned but updated beliefs show environment(production, stable):
  pause rollback decision
  record evidence and final decision
```

## Action Mapping

| BDI Action | Later Local Action Interface | Notes |
| --- | --- | --- |
| `build(candidate)` | `./cicd/actions/build.sh candidate` | Later real local action |
| `test(candidate)` | `./cicd/actions/test.sh candidate` | Later real local action |
| `security_scan(candidate)` | `./cicd/actions/security_scan.sh candidate` | Later real local action |
| `deploy(staging, candidate)` | `./cicd/actions/deploy.sh staging candidate` | Later real local action |
| `health_check(staging)` | `./cicd/actions/health_check.sh staging` | Later real local action |
| `deploy(production, candidate)` | `./cicd/actions/deploy.sh production candidate` | Later real local action |
| `health_check(production)` | `./cicd/actions/health_check.sh production` | Later real local action |
| `rollback(production)` | `./cicd/actions/rollback.sh production` | Later real local action |
| `pause(reason)` | Logged decision | Simulated first |
| `reobserve(production)` | Scenario telemetry refresh | Simulated first |
| `record_result(decision)` | Experiment result writer | Future local implementation |

## Success Criteria For The BDI Model

- Beliefs are symbolic and explainable.
- Goals clearly separate release delivery, reliability maintenance, recovery, and result recording.
- Plans can reproduce the traditional success path.
- Plans can choose rollback when production is unstable.
- Plans can pause and reobserve when evidence is uncertain.
- BDI decisions can be traced back to events, telemetry, and beliefs.
