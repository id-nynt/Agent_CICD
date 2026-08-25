# BDI Agent Belief And Goal Model

This document explains the Jason BDI agent in `bdi/deployment_agent.asl`.

It answers four questions:

```text
1. What beliefs can exist?
2. Which beliefs are initial, and which are added later?
3. What are context conditions?
4. What goals, subgoals, and final outcomes exist?
```

## 1. Agent Model In One Picture

The agent is a single Jason agent:

```text
bdi/project.mas2j
        |
        v
deployment_agent
        |
        v
!deliver_release(candidate)
        |
        +--> calls external CI/CD actions
        |
        +--> receives Java percepts
        |
        +--> evaluates AgentSpeak context conditions
        |
        +--> selects plans
        |
        +--> records outcome beliefs
```

The Java environment is:

```text
bdi/src/env/CicdEnvironment.java
```

It gives the agent percepts from two sources:

```text
CI/CD action result
  -> status(..., passed/failed)

Prometheus telemetry
  -> metric(...)
  -> environment(...)
  -> telemetry(...)
  -> network(...)
```

## 2. Belief Categories

In Jason, a belief is something the agent currently accepts as true in its belief base.

This project has three belief categories:

| Category | Who creates it? | Meaning |
| --- | --- | --- |
| Initial self beliefs | `deployment_agent.asl` at startup | Fixed facts the agent begins with. |
| Percept beliefs | `CicdEnvironment.java` | Facts perceived from script results, Docker/app state, and Prometheus telemetry. |
| Internal decision/outcome beliefs | `deployment_agent.asl` during plan execution | Facts the agent adds to remember goals, decisions, outcomes, retries, or manual-intervention reasons. |

## 3. Initial Self Beliefs

These are present when the agent starts.

| Belief | Defined in | Meaning |
| --- | --- | --- |
| `controller_mode(persistent)` | `deployment_agent.asl` | The agent should remain alive for inspection and later perceptions. |
| `candidate(candidate)` | `deployment_agent.asl` | The release candidate being delivered is named `candidate`. |

The startup goal is:

```text
!start_controller
```

That goal immediately adopts:

```text
!deliver_release(candidate)
```

## 4. Percept Beliefs Added By Java

These beliefs are not written directly by the agent. They are added by `CicdEnvironment.java` after real actions or telemetry polling.

### 4.1 CI/CD Action Status Beliefs

These are created after Jason calls an external action.

| Belief | Added when |
| --- | --- |
| `status(build, passed)` | `build.sh candidate` exits with code `0`. |
| `status(build, failed)` | `build.sh candidate` exits non-zero, or `BDI_FORCE_BUILD_FAIL=true`. |
| `status(test, passed)` | `test.sh candidate` exits with code `0`. |
| `status(test, failed)` | `test.sh candidate` exits non-zero, or `BDI_FORCE_TEST_FAIL=true`. |
| `status(security_scan, passed)` | `security_scan.sh candidate` exits with code `0`. |
| `status(security_scan, failed)` | `security_scan.sh candidate` exits non-zero, or `BDI_FORCE_SECURITY_SCAN_FAIL=true`. |
| `status(deploy(staging), passed)` | `deploy.sh staging candidate` exits with code `0`. |
| `status(deploy(staging), failed)` | `deploy.sh staging candidate` exits non-zero. |
| `status(deploy(production), passed)` | `deploy.sh production candidate` exits with code `0`. |
| `status(deploy(production), failed)` | `deploy.sh production candidate` exits non-zero. |
| `status(health_check(staging), passed)` | `health_check.sh staging` exits with code `0`. |
| `status(health_check(staging), failed)` | `health_check.sh staging` exits non-zero. |
| `status(health_check(production), passed)` | `health_check.sh production` exits with code `0`. |
| `status(health_check(production), failed)` | `health_check.sh production` exits non-zero, or `BDI_FORCE_HEALTH_CHECK_PRODUCTION_FAIL_ONCE=true`. |
| `status(rollback(production), passed)` | `rollback.sh production` exits with code `0`. |
| `status(rollback(production), failed)` | `rollback.sh production` exits non-zero, or `BDI_FORCE_ROLLBACK_PRODUCTION_FAIL=true`. |

`CicdEnvironment.java` removes the opposite status before adding the new one. For example, if it adds `status(build, passed)`, it removes `status(build, failed)`.

### 4.2 Environment State Beliefs

These represent whether staging or production is stable.

| Belief | Added when |
| --- | --- |
| `environment(staging, stable)` | Staging health check passes. |
| `environment(staging, unstable)` | Staging health check fails. |
| `environment(production, stable)` | Production health check passes, rollback passes, or telemetry is healthy. |
| `environment(production, unstable)` | Production health check fails, telemetry is unhealthy, or telemetry cannot be queried. |

For each environment, Java replaces stale state. It does not keep both stable and unstable at the same time.

### 4.3 Production Telemetry Metric Beliefs

These are produced by Prometheus polling in `CicdEnvironment.java`.

| Belief | Condition |
| --- | --- |
| `metric(production, error_rate, normal)` | Prometheus error rate is `<= 0.05`. |
| `metric(production, error_rate, high)` | Prometheus error rate is `> 0.05`. |
| `metric(production, latency, normal)` | Prometheus p95 latency is `<= 500 ms`. |
| `metric(production, latency, high)` | Prometheus p95 latency is `> 500 ms`. |
| `metric(production, availability, high)` | Prometheus availability is `>= 0.99`. |
| `metric(production, availability, low)` | Prometheus availability is `< 0.99`. |

The thresholds come from:

```text
telemetry/thresholds.yml
```

Current threshold values:

```text
error_rate_high_gt: 0.05
latency_p95_ms_high_gt: 500
availability_low_lt: 0.99
```

Telemetry state is interpreted like this:

```text
error_rate high
or latency high
or availability low
        |
        v
environment(production, unstable)
```

Otherwise Java adds:

```text
environment(production, stable)
```

### 4.4 Telemetry Availability Beliefs

These appear when Java cannot query Prometheus.

| Belief | Added when |
| --- | --- |
| `telemetry(production, unavailable)` | Prometheus query fails. |
| `network(production, suspected)` | Prometheus query fails, so the agent treats the situation as possible observability/network trouble. |
| `environment(production, unstable)` | Added together with unavailable telemetry because production reliability cannot be trusted. |

When a later Prometheus query succeeds, Java removes:

```text
telemetry(production, unavailable)
network(production, suspected)
```

### 4.5 Observation Beliefs

The agent can call:

```text
observe(production, canary)
```

After waiting for the configured canary duration, Java adds one of:

```text
observation(production, canary, stable)
observation(production, canary, unstable)
observation(production, canary, unknown)
```

The observation is based on the latest environment state Java remembers while telemetry polling continues.

## 5. Internal Beliefs Added By The Agent

These are created by `deployment_agent.asl` during reasoning.

### 5.1 Progress Beliefs

| Belief | Added when | Removed when |
| --- | --- | --- |
| `delivery_in_progress(candidate)` | `!deliver_release(candidate)` starts. | Delivery succeeds, fails, or is deferred. |
| `release_monitoring_enabled(production)` | Production health check passes, or reliability maintenance starts. | Removed before rollback/recovery and then can be re-added after verification. |

### 5.2 Recovery Beliefs

| Belief | Added when | Meaning |
| --- | --- | --- |
| `recovery_attempted(production)` | `!restore_production_reliability(Reason)` starts. | Prevents repeated automatic recovery loops for the same instability. |
| `recovery_reason(Reason)` | Recovery starts. | Remembers why rollback/recovery was attempted. |
| `production_reliability_restored` | Rollback succeeds. | Production was restored to a reliable state. |
| `production_reliability_restored(Reason)` | Rollback succeeds. | Production was restored because of `Reason`. |
| `production_retry_attempted(candidate)` | Health-failure recovery chooses retry. | Prevents endless retry of the same candidate. |
| `reobserve_reason(Reason)` | Agent pauses/reobserves. | Remembers why it paused. |

### 5.3 Decision Marker Beliefs

These beliefs record what decision the agent selected.

| Belief | Added when |
| --- | --- |
| `decision(delivery_succeeded)` | Candidate delivery succeeds. |
| `decision(release_complete)` | Release completes successfully. |
| `decision(delivery_failed)` | Candidate delivery fails. |
| `decision(delivery_deferred)` | Candidate delivery is deferred. |
| `decision(pause_reobserve)` | Agent pauses and waits for telemetry to recover. |
| `decision(reobserve_recovered)` | Telemetry becomes stable after reobserve. |
| `decision(rollback_production)` | Agent chooses rollback as recovery. |
| `decision(rollback_then_retry_production)` | Agent rolls back after transient health failure, then retries the same candidate. |
| `decision(continue_deploy_candidate)` | Agent decides to redeploy the candidate after recovered production is stable. |
| `decision(manual_intervention_required)` | Agent cannot safely continue automatically. |
| `decision(stop_pipeline)` | The `!stop_release(Reason)` plan is used. This is currently defined but not used by the main goal path. |

Important note:

```text
record_decision(...)
```

also writes decision messages to the Java log, but it does not automatically add a Jason belief. A `decision(...)` belief exists only when `deployment_agent.asl` explicitly adds `+decision(...)`.

### 5.4 Outcome And Reason Beliefs

| Belief | Added when | Meaning |
| --- | --- | --- |
| `delivery_succeeded(candidate)` | `!succeed_delivery(candidate)` runs and no failure/defer guard applies. | Candidate was delivered successfully. |
| `delivery_failed(candidate, Reason)` | `!fail_delivery(candidate, Reason)` runs. | Candidate delivery failed. |
| `delivery_failure_reason(Reason)` | Delivery fails. | Stores the failure reason separately. |
| `delivery_deferred(candidate, Reason)` | `!defer_delivery(candidate, Reason)` runs. | Candidate delivery is not finished and should be revisited later. |
| `delivery_defer_reason(Reason)` | Delivery is deferred. | Stores the defer reason separately. |
| `manual_reason(Reason)` | Manual intervention is required. | Stores why automation stopped. |
| `stop_reason(Reason)` | `!stop_release(Reason)` runs. | Stores stop reason. |

## 6. What Are Context Conditions?

In AgentSpeak, a plan has this shape:

```text
+triggering_event
  : context_condition
  <- action_body.
```

The context condition is the part after `:` and before `<-`.

It means:

```text
This plan is applicable only if the triggering event happened
and the context condition is true in the agent's belief base.
```

For example:

```text
+!handle_build_result
  : status(build, passed)
  <- .print("[deployment_agent][belief] status(build, passed)").
```

Plain language:

```text
When the agent has the goal !handle_build_result,
use this plan only if it believes status(build, passed).
```

Another example:

```text
+environment(production, unstable)
  : release_monitoring_enabled(production)
    & status(deploy(production), passed)
    & metric(production, latency, high)
    & not metric(production, error_rate, high)
    & not recovery_attempted(production)
  <- !pause_reobserve(high_latency).
```

Plain language:

```text
When production becomes unstable,
if monitoring is enabled,
and production deployment passed,
and latency is high,
and error rate is not high,
and recovery has not already been attempted,
then pause and reobserve instead of immediately rolling back.
```

## 7. Main Context Conditions In This Agent

| Plan area | Context condition | Meaning |
| --- | --- | --- |
| Build result | `status(build, passed)` | Build succeeded; continue. |
| Build result | `status(build, failed)` | Build failed; fail delivery. |
| Test result | `status(test, passed)` | Tests passed; continue. |
| Test result | `status(test, failed)` | Tests failed; fail delivery. |
| Security result | `status(security_scan, passed)` | Security scan passed; continue. |
| Security result | `status(security_scan, failed)` | Security scan failed; fail delivery. |
| Staging deploy | `status(deploy(staging), passed)` | Staging deploy succeeded; continue. |
| Staging deploy | `status(deploy(staging), failed)` | Staging deploy failed; defer delivery. |
| Staging health | `status(health_check(staging), passed) & environment(staging, stable)` | Staging is healthy; continue. |
| Staging health fallback | no explicit condition | If staging is not proven stable, defer delivery. |
| Production deploy | `status(deploy(production), passed)` | Production deploy succeeded; continue to health and canary. |
| Production deploy | `status(deploy(production), failed)` | Production deploy failed; restore reliability and defer delivery. |
| Production health | `status(health_check(production), passed)` | Production health endpoint passed; enable monitoring. |
| Production health | `status(health_check(production), failed)` | Recover production due to health failure. |
| Production unstable event | `release_monitoring_enabled(production) & status(deploy(production), passed) & telemetry(production, unavailable) & not recovery_attempted(production)` | Treat missing telemetry as uncertainty; pause/reobserve. |
| Production unstable event | `release_monitoring_enabled(production) & status(deploy(production), passed) & metric(production, latency, high) & not metric(production, error_rate, high) & not recovery_attempted(production)` | Latency-only problem; pause/reobserve. |
| Production unstable event | `release_monitoring_enabled(production) & status(deploy(production), passed) & not recovery_attempted(production)` | General production instability; recover production. |
| Canary stable | `observation(production, canary, stable) & environment(production, stable)` | Canary ended stable; continue. |
| Canary telemetry unavailable | `telemetry(production, unavailable)` | Pause/reobserve because observability is not trusted. |
| Canary high latency | `metric(production, latency, high) & not metric(production, error_rate, high)` | Pause/reobserve. |
| Canary high error rate | `metric(production, error_rate, high) & candidate(Candidate)` | Restore production reliability and fail candidate. |
| Canary unstable | `observation(production, canary, unstable) & candidate(Candidate)` | Restore production reliability and fail candidate. |
| Maintain reliability | `environment(production, stable) & candidate(Candidate) & not delivery_failed(Candidate, _) & not delivery_deferred(Candidate, _)` | Production stable and no negative outcome exists; succeed delivery. |
| Maintain reliability | `delivery_failed(Candidate, Reason)` | Skip success because failure already exists. |
| Maintain reliability | `delivery_deferred(Candidate, Reason)` | Skip success because deferral already exists. |
| Maintain reliability | `environment(production, unstable) & candidate(Candidate)` | Restore reliability and fail candidate. |
| Rollback retry | `status(rollback(production), passed) & recovery_reason(health_failed) & candidate(Candidate) & not production_retry_attempted(Candidate)` | Transient health failure recovered; retry same candidate once. |
| Rollback success | `status(rollback(production), passed)` | Rollback completed; keep system alive. |
| Rollback failure | `status(rollback(production), failed)` | Manual intervention required. |
| Reobserve recovered | `environment(production, stable) & candidate(Candidate)` | Telemetry recovered; succeed delivery. |
| Reobserve unavailable | `telemetry(production, unavailable) & candidate(Candidate)` | Observability still unavailable; manual intervention and defer delivery. |
| Reobserve unstable | `environment(production, unstable) & candidate(Candidate)` | Still unstable; rollback and fail candidate. |
| Succeed guard | `delivery_failed(Candidate, Reason)` | Do not overwrite a failed delivery as success. |
| Succeed guard | `delivery_deferred(Candidate, Reason)` | Do not overwrite a deferred delivery as success. |

## 8. Goal And Subgoal System

The root goal is:

```text
!deliver_release(candidate)
```

The goal tree is:

```text
!deliver_release(candidate)
|
|-- !prepare_candidate(candidate)
|   `-- !run_build(candidate)
|       `-- !handle_build_result
|
|-- !validate_candidate(candidate)
|   |-- !run_tests(candidate)
|   |   `-- !handle_test_result
|   |
|   `-- !run_security_scan(candidate)
|       `-- !handle_security_scan_result
|
|-- !deploy_to_staging(candidate)
|   `-- !handle_staging_deploy_result
|
|-- !verify_staging
|   `-- !handle_staging_health_result
|
|-- !deploy_to_production(candidate)
|   `-- !handle_production_deploy_result
|
|-- !verify_production
|   `-- !handle_production_health_result
|
|-- !observe_production_canary
|   `-- !handle_production_canary_observation
|
`-- !maintain_reliability
```

Recovery goals can be triggered from production health checks, telemetry events, or canary observation:

```text
!recover_production(Reason)
|
|-- !restore_production_reliability(Reason)
|   |-- rollback(production)
|   `-- !handle_reliability_restore_result(Reason)
|
`-- !handle_recovery_delivery_outcome(Reason)
```

Retry after a transient health failure:

```text
!handle_rollback_result
|
`-- !verify_recovered_production_before_retry(candidate, health_failed)
    |
    `-- if stable:
        !deploy_to_production(candidate)
        !verify_production
        !observe_production_canary
        !maintain_reliability
```

Pause/reobserve:

```text
!pause_reobserve(Reason)
|
`-- wait
    |
    `-- !handle_reobserve_result(Reason)
```

Final outcome helpers:

```text
!succeed_delivery(Candidate)
!fail_delivery(Candidate, Reason)
!defer_delivery(Candidate, Reason)
!stop_release(Reason)
!keep_alive
```

## 9. External Actions The Agent Can Execute

These look like normal AgentSpeak actions, but Jason sends them to `CicdEnvironment.java`.

| Agent action | Java effect |
| --- | --- |
| `build(candidate)` | Runs `cicd/actions/build.sh candidate`. |
| `test(candidate)` | Runs `cicd/actions/test.sh candidate`. |
| `security_scan(candidate)` | Runs `cicd/actions/security_scan.sh candidate`. |
| `deploy(candidate, staging)` | Runs `cicd/actions/deploy.sh staging candidate`. |
| `deploy(candidate, production)` | Runs `cicd/actions/deploy.sh production candidate`. |
| `health_check(staging)` | Runs `cicd/actions/health_check.sh staging`. |
| `health_check(production)` | Runs `cicd/actions/health_check.sh production`. |
| `rollback(production)` | Runs `cicd/actions/rollback.sh production`. |
| `observe(production, canary)` | Waits during canary while telemetry polling continues, then adds an observation percept. |
| `record_decision(...)` | Writes decision evidence into `bdi/logs/cicd_environment.log`. |

## 10. Possible Final Outcomes

The agent can end the release attempt in these main ways.

### 10.1 Candidate Delivered Successfully

Beliefs:

```text
delivery_succeeded(candidate)
decision(delivery_succeeded)
decision(release_complete)
```

Typical condition:

```text
build passed
test passed
security_scan passed
staging stable
production stable
canary stable
no delivery_failed(...)
no delivery_deferred(...)
```

### 10.2 Candidate Delivery Failed

Beliefs:

```text
delivery_failed(candidate, Reason)
delivery_failure_reason(Reason)
decision(delivery_failed)
```

Possible reasons in the current plans:

```text
build_failed
test_failed
security_failed
candidate_unsafe
telemetry_unstable
production_unstable
high_latency
```

The exact reason depends on which failure plan fired.

### 10.3 Candidate Delivery Deferred

Beliefs:

```text
delivery_deferred(candidate, Reason)
delivery_defer_reason(Reason)
decision(delivery_deferred)
```

Possible reasons in the current plans:

```text
staging_deploy_failed
staging_unstable
production_deploy_failed
reliability_unknown
network_suspected
high_latency
```

Deferral means the agent did not prove the candidate safe enough to mark delivery as successful, but it is not always the same as a failed candidate.

### 10.4 Production Reliability Restored

Beliefs:

```text
production_reliability_restored
production_reliability_restored(Reason)
```

This means rollback succeeded. It does not by itself mean the candidate was delivered successfully.

### 10.5 Manual Intervention Required

Beliefs:

```text
decision(manual_intervention_required)
manual_reason(Reason)
```

Typical causes:

```text
rollback_failed
telemetry unavailable after reobserve
recovered production not stable before retry
```

### 10.6 Release Stopped

Beliefs:

```text
decision(stop_pipeline)
stop_reason(Reason)
```

The `!stop_release(Reason)` helper exists in the agent. The main delivery path currently uses `!fail_delivery(...)` or `!defer_delivery(...)` instead of this helper for most stop cases.

## 11. Outcome Diagram

```text
!deliver_release(candidate)
        |
        v
prepare + validate + staging
        |
        +--> gate failed ------------------> delivery_failed/deferred
        |
        v
deploy production + health check
        |
        +--> health failed ----------------> rollback
        |                                      |
        |                                      +--> stable again -> retry candidate once
        |                                      |
        |                                      `--> rollback failed -> manual intervention
        |
        v
observe production canary
        |
        +--> stable ------------------------> delivery_succeeded(candidate)
        |
        +--> high latency ------------------> pause/reobserve
        |
        +--> telemetry unavailable ---------> pause/reobserve/manual intervention/defer
        |
        +--> high error rate or unstable ---> rollback
                                               |
                                               +--> rollback passed -> reliability restored + delivery_failed
                                               |
                                               `--> rollback failed -> manual intervention
```

## 12. How To Inspect The Belief Base

Start the agent:

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD\bdi
jason project.mas2j
```

Inspect beliefs:

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD\bdi
jason agent mind deployment_agent
```

Watch action, percept, telemetry, and decision evidence:

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
Get-Content .\bdi\logs\cicd_environment.log -Tail 180 -Wait
```
