# Agent Instructions For This Project

Project: Autonomous CI/CD pipeline using BDI multi-agent system

This file captures the project-specific requirements that must guide future work in this repository.

## Core Research Goal

Build a research prototype showing how a traditional CI/CD pipeline can be managed by a BDI agent.

The prototype must demonstrate:

- Beliefs: CI/CD stage status, environment state, and later telemetry-derived facts.
- Desires/goals: deliver release, maintain reliability, recover from failure.
- Intentions/plans: build, test, security scan, deploy, health check, rollback, pause, reobserve, continue.
- Actions: concrete CI/CD actions that map to the traditional pipeline.

## Phase 1 Must Be The Implementation Baseline

Phase 2 must learn from and preserve the Phase 1 CI/CD implementation style.

Phase 1 uses shell scripts as the CI/CD action interface:

```sh
./scripts/build.sh
./scripts/run-tests.sh
./scripts/security-scan.sh
./scripts/deploy.sh staging
./scripts/health-check.sh staging
./scripts/deploy.sh production
./scripts/health-check.sh production
./scripts/rollback.sh production
```

In Phase 2, keep the same shell-script style, but under the Phase 2 structure:

```sh
./cicd/scripts/build.sh v2
./cicd/scripts/run-tests.sh v2
./cicd/scripts/security-scan.sh v2
./cicd/scripts/deploy.sh staging v2
./cicd/scripts/health-check.sh staging
./cicd/scripts/deploy.sh production v2
./cicd/scripts/health-check.sh production
./cicd/scripts/rollback.sh production
```

Do not make Python, JavaScript, or another language the public CI/CD action interface unless the user explicitly approves it.

If helper code in another language is introduced later, explain why and keep shell scripts as the stable interface.

## Phase 2.1 Current Scope

Implement Day 1 only:

- Minimum baseline CI/CD system.
- Simple file-based payment service, consistent with Phase 1.
- Local shell scripts for build, test, security scan, staging deploy, production deploy, health check, and rollback.
- Traditional YAML pipeline showing the non-BDI baseline.
- First Jason BDI agent that follows the same pipeline sequence through beliefs, goals, and plans.
- Success scenario where the release completes end to end.

Do not integrate yet:

- Prometheus.
- OpenTelemetry.
- Kubernetes.
- Cloud deployment.
- GitHub API.
- Dataset-driven failure forecasting.
- ML.
- Multi-agent negotiation.

## Required Structure

Use this structure unless the existing repo gives a stronger reason:

```text
app/
  v1/
    config.json
    health.txt
    index.html
  v2/
    config.json
    health.txt
    index.html

cicd/
  traditional-pipeline.yml
  scripts/
    build.sh
    run-tests.sh
    security-scan.sh
    deploy.sh
    health-check.sh
    rollback.sh
    reset.sh
    show-state.sh
    pipeline-success.sh

bdi/
  cicd_agent.asl
  project.mas2j

experiments/
  scenarios/
    day1_success.json
  run-day1-baseline.sh
  results/

state/
deployments/
  staging/
  production/

0_private/
  phase2_bdi_cicd_3_day_plan.md
  phase2_1_current_summary.md
```

## Traditional Pipeline Shape

The baseline YAML must clearly show:

```yaml
stages:
  - build
  - test
  - security
  - staging
  - production
```

And the stages must call shell scripts:

```yaml
build:
  stage: build
  script:
    - ./cicd/scripts/build.sh v2

test:
  stage: test
  script:
    - ./cicd/scripts/run-tests.sh v2

security:
  stage: security
  script:
    - ./cicd/scripts/security-scan.sh v2

staging:
  stage: staging
  script:
    - ./cicd/scripts/deploy.sh staging v2
    - ./cicd/scripts/health-check.sh staging

production:
  stage: production
  script:
    - ./cicd/scripts/deploy.sh production v2
    - ./cicd/scripts/health-check.sh production
  on_failure:
    - ./cicd/scripts/rollback.sh production
```

## BDI Requirements

The Jason agent must include:

- A root goal named `!deliver_release`.
- Symbolic beliefs for stage and environment state.
- Plans that mirror the traditional success path.

Minimum BDI workflow:

```text
!deliver_release
  -> !run_build
  -> !run_tests
  -> !run_security_scan
  -> !deploy(staging)
  -> !verify(staging)
  -> !deploy(production)
  -> !verify(production)
  -> release complete
```

Example symbolic beliefs:

```prolog
status(build, pending).
status(build, passed).
status(test, passed).
status(security, passed).
environment(staging, stable).
environment(production, stable).
```

## Testing Requirements

The Day 1 verification command should be shell-based:

```sh
bash experiments/run-day1-baseline.sh
```

It must prove:

- Build runs.
- Tests run.
- Security scan runs.
- Staging deploy runs.
- Staging health check runs.
- Production deploy runs.
- Production health check runs.
- Final result is release success.

Expected action sequence:

```text
build
test
security_scan
deploy_staging
health_check_staging
deploy_production
health_check_production
```

Expected result:

```text
final_decision = release_success
success = true
```

## Documentation Requirements

Keep these documents updated:

- `0_private/phase2_bdi_cicd_3_day_plan.md`
- `0_private/phase2_1_current_summary.md`
- `docs/day1_baseline.md`

The documents must not describe a Python-based CI/CD implementation unless that is actually the approved design.

## Important Consistency Rule

There should be no mixed public CI/CD interface.

Correct:

```text
YAML -> shell scripts -> file-based app/deployment/state operations
BDI agent -> symbolic model of the same shell-script actions
```

Incorrect:

```text
YAML -> Python scripts directly
runner -> Python scripts directly
shell scripts -> thin wrappers around Python without explanation
```

For this research prototype, shell scripts are the source of truth for CI/CD actions.

