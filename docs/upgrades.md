# Upgrade Hooks

Phase 6 defines future extension points without implementing heavy integrations.

The current prototype already has:

```text
events -> telemetry -> beliefs -> goals/plans -> actions -> results
```

The upgrade hooks preserve that shape. Each future technique should replace or enrich one layer rather than bypassing the architecture.

## Hook Summary

| Future Upgrade | Existing Layer It Connects To | Current Stub |
| --- | --- | --- |
| Prometheus/OpenTelemetry adapter | telemetry | `upgrade_hooks/prometheus_otel_adapter_stub.py` |
| GitHub Actions or GitLab CI executor | actions | `upgrade_hooks/platform_action_executor_stub.sh` |
| Dataset-to-scenario generator | events and scenarios | `upgrade_hooks/dataset_to_scenario_stub.py` |
| Failure prediction module | beliefs | `upgrade_hooks/failure_prediction_stub.py` |
| Multi-agent extension | goals/plans | documented below |

These stubs are intentionally small. They show data contracts only.

## 1. Prometheus/OpenTelemetry Adapter

Current source:

```text
simulation/scenarios/*.yml
simulation/event_log/*.json
```

Current mapping:

```text
scenario telemetry -> telemetry/belief_mapper.py -> telemetry/generated_beliefs/*.asl
```

Future connection:

```text
Prometheus/OpenTelemetry -> telemetry adapter -> belief mapper -> BDI beliefs
```

The adapter should output the same telemetry shape used today:

```json
{
  "environment": "production",
  "telemetry": {
    "error_rate": 0.02,
    "latency_p95_ms": 240,
    "availability": 0.995
  }
}
```

The belief mapper can then continue producing:

```prolog
metric(production, error_rate, normal).
metric(production, latency, normal).
metric(production, availability, high).
environment(production, stable).
```

Stub:

```sh
python upgrade_hooks/prometheus_otel_adapter_stub.py
```

Do not connect to real monitoring until the scenario-based prototype is stable.

## 2. GitHub Actions Or GitLab CI Executor

Current action layer:

```text
cicd/actions/*.sh
```

Current BDI action vocabulary:

```text
build(candidate)
test(candidate)
security_scan(candidate)
deploy(staging, candidate)
health_check(staging)
deploy(production, candidate)
health_check(production)
rollback(production)
```

Future connection:

```text
BDI selected action -> platform executor -> GitHub/GitLab job -> event log -> belief update
```

The executor should preserve the existing action names. The implementation behind the action may change from local shell script to CI platform job, but the BDI model should not need to change.

Stub:

```sh
./upgrade_hooks/platform_action_executor_stub.sh deploy production candidate
```

Expected contract:

```json
{
  "requested_action": "deploy",
  "target": "production",
  "version": "candidate",
  "status": "not_executed"
}
```

## 3. Dataset-To-Scenario Generator

Current scenario source:

```text
simulation/scenarios/*.yml
```

Future connection:

```text
GHALogs or CI/CD failure dataset -> scenario generator -> simulation/scenarios/*.yml
```

The generator should create scenario files that match the current schema:

```yaml
name: dataset_generated_example
initial_state:
  stable_version: stable
  production_version: stable
release:
  candidate_version: candidate
stages:
  build: passed
  test: failed
telemetry:
  error_rate: 0.01
  latency_p95_ms: 140
  availability: 0.999
context:
  network_issue_suspected: false
  reobserve_after_failure: false
expected:
  traditional_decision: stop_pipeline
  bdi_decision: abandon_release_or_request_fix
```

Stub:

```sh
python upgrade_hooks/dataset_to_scenario_stub.py
```

The generated scenarios should still be run by:

```sh
./simulation/scenario_runner.sh --all
```

## 4. Failure Prediction Module

Current belief source:

```text
telemetry/generated_beliefs/*.asl
```

Future connection:

```text
experiment history or dataset features -> predictor -> risk beliefs -> BDI agent
```

The predictor should output symbolic beliefs, not raw model scores:

```prolog
failure_risk(production, high).
prediction_source(dataset_model).
```

The BDI agent can later add plans such as:

```prolog
+!deploy_to_production : failure_risk(production, high)
  <- !pause_and_reobserve.
```

Stub:

```sh
python upgrade_hooks/failure_prediction_stub.py
```

Do not add ML until the existing deterministic experiments are complete and explainable.

## 5. Multi-Agent Extension Plan

Current BDI design:

```text
one cicd_agent
```

Future multi-agent split:

| Agent | Responsibility | Beliefs It Cares About | Actions |
| --- | --- | --- | --- |
| `release_agent` | Deliver candidate release | stage status, candidate version | build, test, deploy |
| `reliability_agent` | Protect production stability | metrics, environment status | pause, reobserve, recommend rollback |
| `security_agent` | Evaluate security stage and risk | security scan status, vulnerability signals | approve or block release |
| `rollback_agent` | Execute recovery plans | previous production version, rollback availability | rollback, verify recovery |
| `experiment_agent` | Record comparable results | decisions, selected actions, final state | write result records |

Future connection:

```text
shared beliefs -> specialized agents -> coordination protocol -> selected action -> results
```

Do not introduce negotiation yet. A safe next step is a two-agent model:

```text
release_agent asks reliability_agent whether production is safe.
```

## Compatibility Rules

Future upgrades should obey these rules:

- Keep scenario files runnable.
- Keep `telemetry/generated_beliefs/*.asl` readable by the BDI layer.
- Keep action names stable.
- Keep experiment outputs machine-readable.
- Add new beliefs rather than replacing existing ones.
- Preserve explainability before adding prediction or external automation.

## Current Validation

After adding or changing an upgrade hook, run:

```sh
./experiments/run_all_scenarios.sh
```

The current deterministic prototype must continue to pass before any future integration is considered acceptable.
