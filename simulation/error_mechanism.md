# Scenario Error Mechanism

This document explains how Phase 2 defines and simulates errors.

Phase 2 does not use real monitoring, Jason BDI logic, Kubernetes, Prometheus, OpenTelemetry, GitHub API calls, or ML. It uses scenario data files to decide which CI/CD stages should pass, fail, or not run.

## Core Method

Each scenario is a YAML file in:

```text
simulation/scenarios/
```

The runner reads fields from the scenario file:

```text
initial_state
release
stages
telemetry
context
expected
```

The main control field is `stages`.

Example:

```yaml
stages:
  build: passed
  test: failed
  security_scan: not_run
  staging_deploy: not_run
  staging_health: not_run
  production_deploy: not_run
  production_health: not_run
```

For each stage:

- `passed` means the runner executes the real Phase 1 shell action.
- `failed` means the runner records a simulated failure for that stage.
- `not_run` means the runner records that the stage was not reached.

This keeps scenario errors as data instead of hardcoding them inside the CI/CD scripts.

## Execution Sequence

The runner follows this fixed CI/CD order:

```text
reset
build
test
security_scan
deploy_staging
health_check_staging
deploy_production
health_check_production
rollback expectation or release success
optional reobserve expectation
```

The runner is:

```text
simulation/scenario_runner.sh
```

The CI/CD actions it calls are:

```text
cicd/actions/reset.sh
cicd/actions/build.sh
cicd/actions/test.sh
cicd/actions/security_scan.sh
cicd/actions/deploy.sh
cicd/actions/health_check.sh
cicd/actions/rollback.sh
```

Phase 2 records rollback as an expectation when production fails. It does not execute rollback automatically because the later BDI phase should decide whether to rollback, pause, reobserve, or continue.

## What The Real Action Scripts Check

When a scenario marks a stage as `passed`, the runner calls the real action script.

### reset

Script:

```text
cicd/actions/reset.sh
```

What it does:

- Creates `runtime/deployments/staging`.
- Creates `runtime/deployments/production`.
- Creates `runtime/state`.
- Clears old deployment files.
- Copies `app/versions/stable` into `runtime/deployments/production`.
- Writes `stable` into `runtime/state/production_version.txt`.
- Writes `stable` into `runtime/state/previous_production_version.txt`.

### build

Script:

```text
cicd/actions/build.sh candidate
```

What it checks:

- `app/versions/candidate` exists.
- `config.json`, `health.txt`, and `index.html` exist.
- `config.json` contains a `version` field.

If those checks pass, it writes:

```text
runtime/state/build_version.txt
```

### test

Script:

```text
cicd/actions/test.sh candidate
```

What it checks:

- `app/versions/candidate/config.json` contains `"service": "payment-service"`.
- `app/versions/candidate/health.txt` contains `OK`.

If those checks pass, it writes:

```text
runtime/state/test_version.txt
```

### security_scan

Script:

```text
cicd/actions/security_scan.sh candidate
```

What it checks:

- The candidate directory exists.
- Files under `app/versions/candidate` do not contain simple secret-like patterns such as `password`, `api_key`, `secret`, or an AWS access key pattern.

If those checks pass, it writes:

```text
runtime/state/security_scan_version.txt
```

### deploy_staging

Script:

```text
cicd/actions/deploy.sh staging candidate
```

What it does:

- Checks that the environment is `staging`.
- Checks that `app/versions/candidate` exists.
- Copies candidate files into `runtime/deployments/staging`.
- Writes `candidate` into `runtime/state/staging_version.txt`.

### health_check_staging

Script:

```text
cicd/actions/health_check.sh staging
```

What it checks:

- `runtime/deployments/staging/health.txt` exists.
- The deployed health file contains `OK`.

### deploy_production

Script:

```text
cicd/actions/deploy.sh production candidate
```

What it does:

- Checks that the environment is `production`.
- Checks that `app/versions/candidate` exists.
- Copies the current production version from `runtime/state/production_version.txt` into `runtime/state/previous_production_version.txt`.
- Copies candidate files into `runtime/deployments/production`.
- Writes `candidate` into `runtime/state/production_version.txt`.

### health_check_production

Script:

```text
cicd/actions/health_check.sh production
```

What it checks:

- `runtime/deployments/production/health.txt` exists.
- The deployed health file contains `OK`.

## How Failures Are Defined

There are two kinds of failures.

## 1. Real Action Failure

This happens when a scenario stage is marked `passed`, but the actual script fails.

Example:

```yaml
stages:
  build: passed
```

The runner executes:

```text
cicd/actions/build.sh candidate
```

If `app/versions/candidate/config.json` is missing, the script exits with a non-zero code. The runner records the real error output in the terminal and JSON event log.

## 2. Scenario-Controlled Failure

This happens when the YAML file marks a stage as `failed`.

Example:

```yaml
stages:
  test: failed
```

The runner does not damage files to force the test script to fail. It records:

```text
test FAIL | Scenario marks this stage as failed.
```

This is intentional. Phase 2 is about controlled scenario simulation, so the scenario file is the source of truth for what should happen.

## Stop And Rollback Rules

The runner uses simple rules:

| Failure Point | Runner Decision |
| --- | --- |
| Build fails | Stop pipeline |
| Test fails | Stop pipeline |
| Security scan fails | Stop pipeline |
| Staging deploy fails | Stop pipeline |
| Staging health fails | Stop pipeline |
| Production deploy fails | Record rollback expectation |
| Production health fails | Record rollback expectation |

For pre-production failures, production remains on `stable`.

For production failures, the runner records:

```text
rollback_production NEXT | Rollback to stable is expected by the traditional decision, but not executed in Phase 2.
```

That means:

- Traditional CI/CD would rollback.
- Later BDI logic may rollback, pause, reobserve, or choose another recovery plan.
- Phase 2 only records the expected next action.

## Telemetry And Context

Telemetry fields are simulated values:

```yaml
telemetry:
  error_rate: 0.12
  latency_p95_ms: 900
  availability: 0.91
```

Context fields are simulated flags:

```yaml
context:
  network_issue_suspected: true
  reobserve_after_failure: true
```

In Phase 2, these values are logged but not reasoned over. Phase 3 will map them into beliefs such as:

```prolog
metric(production, error_rate, high).
environment(production, unstable).
network_issue_suspected(true).
```

Phase 4 will use those beliefs for BDI reasoning.

## Outputs

Every scenario run writes a JSON event log to:

```text
simulation/event_log/
```

The terminal output is for human inspection. The JSON log is for later automated analysis.
