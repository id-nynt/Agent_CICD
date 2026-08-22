# Phase 0 Scenarios

This document defines the required scenario set for the BDI CI/CD research prototype. Scenarios should be data-driven in later phases and should feed the architecture:

```text
events -> telemetry -> beliefs -> goals/plans -> actions -> results
```

Phase 0 does not implement these scenarios. It only fixes the initial experimental scope.

## Scenario Design Rules

- Each scenario should define events, telemetry, context flags, and expected outcomes.
- Scenario data should not be hardcoded inside CI/CD action scripts.
- Traditional CI/CD and BDI CI/CD expected decisions should be recorded separately.
- Scenarios should be simple enough to explain in a research report.
- Phase 1 may guide action names, but scenario behavior should not copy Phase 1's single hardcoded rollback path.

## Required Scenarios

| Scenario | Purpose | Traditional Expected Decision | BDI Expected Decision |
| --- | --- | --- | --- |
| `success_stable` | Baseline successful release | Complete release | Complete release |
| `production_unstable` | Production health fails after deployment | Roll back production | Roll back after unstable environment belief |
| `stage_failure` | A pre-production stage fails | Stop before production | Stop release and preserve production |
| `rollback_midway_recovery` | Production initially looks unhealthy, then telemetry recovers | Continue rollback once triggered | Pause or reobserve before final rollback decision |
| `network_issue_suspected` | Health check failure may be caused by temporary infrastructure or network issue | Treat as failed and roll back | Pause, reobserve, then decide |

## Scenario Details

### success_stable

Purpose: prove the baseline happy path.

Initial conditions:

- Stable version is already in production.
- Candidate version is available.
- Staging and production are healthy.

Events:

- Build passes.
- Tests pass.
- Security scan passes.
- Staging deploy passes.
- Staging health check passes.
- Production deploy passes.
- Production health check passes.

Telemetry:

- Error rate is normal.
- Latency is normal.
- Availability is high.

Expected result:

- Traditional decision: `release_success`
- BDI decision: `release_success`
- Production ends on candidate.

### production_unstable

Purpose: show recovery when production becomes unhealthy after deployment.

Initial conditions:

- Stable version is already in production.
- Candidate version passes pre-production checks.
- Production becomes unhealthy after candidate deployment.

Events:

- Build passes.
- Tests pass.
- Security scan passes.
- Staging deploy and health check pass.
- Production deploy passes.
- Production health check fails.

Telemetry:

- Error rate is high.
- Latency may be high.
- Availability is low.
- No temporary network issue is suspected.

Expected result:

- Traditional decision: `rollback`
- BDI decision: `rollback_after_unstable_belief`
- Production returns to the previous stable version.

### stage_failure

Purpose: prove that unsafe releases do not reach production.

Initial conditions:

- Stable version is already in production.
- Candidate version is available but fails one pre-production condition.

Events:

- One of build, test, security scan, staging deploy, or staging health fails.
- Production deploy is not attempted.

Telemetry:

- Production remains stable.
- Failure telemetry is attached to the failed stage only.

Expected result:

- Traditional decision: `stop_pipeline`
- BDI decision: `abandon_release_or_request_fix`
- Production remains on stable.

### rollback_midway_recovery

Purpose: demonstrate that the BDI agent can reason about updated beliefs instead of blindly continuing a recovery path.

Initial conditions:

- Candidate is deployed to production.
- Production health initially appears failed.
- A later observation shows production telemetry recovering.

Events:

- Production health check fails.
- Rollback condition is detected.
- Reobservation event reports improved telemetry.

Telemetry:

- Initial error rate or availability is bad.
- Updated telemetry returns within acceptable threshold.
- Network issue may or may not be suspected.

Expected result:

- Traditional decision: `rollback`
- BDI decision: `pause_or_reobserve_before_rollback`
- Final decision depends on updated beliefs, which should be recorded.

### network_issue_suspected

Purpose: test context-sensitive reasoning when health check failure may not be caused by the deployed candidate.

Initial conditions:

- Candidate passes build, tests, security, and staging.
- Production health check fails or is inconclusive.
- Context suggests an external network or infrastructure issue.

Events:

- Production health check fails.
- Network issue flag is true.
- A reobservation may confirm recovery or continued failure.

Telemetry:

- Availability may be low.
- Error rate may be inconclusive.
- `network_issue_suspected` is true.

Expected result:

- Traditional decision: `rollback`
- BDI decision: `pause_reobserve_then_decide`
- The agent should not treat the first failed signal as sufficient evidence by itself.

## Minimum Scenario Fields For Later Implementation

```yaml
name: production_unstable
release: candidate
initial_state:
  production_version: stable
events:
  build_status: passed
  test_status: passed
  security_status: passed
  staging_deploy: passed
  staging_health: passed
  production_deploy: passed
  production_health: failed
telemetry:
  error_rate: 0.12
  latency_p95_ms: 900
  availability: 0.91
context:
  network_issue_suspected: false
expected:
  traditional_decision: rollback
  bdi_decision: rollback_after_unstable_belief
```

## Scenario Success Criteria

- All required scenarios are represented as data in later phases.
- Adding a new scenario does not require changing core action scripts.
- Each scenario can produce events, telemetry, beliefs, selected actions, and results.
- At least one scenario makes the BDI outcome differ from the traditional outcome.
