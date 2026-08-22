# BDI CI/CD Research Prototype

This repository is a research prototype for an autonomous CI/CD pipeline using a BDI multi-agent system.

## Phase 1: Demo App And CI/CD Actions

Phase 1 provides a minimal file-based payment service and a shell-callable CI/CD action layer. The goal is to create simple actions that a later BDI agent can choose from; this phase does not implement BDI reasoning, scenario simulation, telemetry mapping, Prometheus, OpenTelemetry, Kubernetes, GitHub API integration, or ML.

The demo service has two versions:

| Version | Location | Purpose |
| --- | --- | --- |
| `stable` | `app/versions/stable/` | Current production baseline |
| `candidate` | `app/versions/candidate/` | Release candidate for validation and deployment |

Runtime state is stored under `runtime/`.

### Run Actions

From the repository root:

```sh
./cicd/actions/reset.sh
./cicd/actions/build.sh candidate
./cicd/actions/test.sh candidate
./cicd/actions/security_scan.sh candidate
./cicd/actions/deploy.sh staging candidate
./cicd/actions/health_check.sh staging
./cicd/actions/deploy.sh production candidate
./cicd/actions/health_check.sh production
```

Rollback can be tested after a production deployment:

```sh
./cicd/actions/rollback.sh production
```

The baseline traditional pipeline shape is documented in:

```text
cicd/pipeline_baseline.yml
```

Each action is intentionally independent so later phases can call the same action interface from a scenario runner or BDI agent.

## Phase 2: Scenario Simulation

Phase 2 adds data-driven scenarios under `simulation/scenarios/` and a local runner that records machine-readable event logs under `simulation/event_log/`.

Run one scenario:

```sh
./simulation/scenario_runner.sh simulation/scenarios/success_stable.yml
```

Run all scenarios:

```sh
./simulation/scenario_runner.sh --all
```

On Windows PowerShell, use Git Bash if plain `bash` points to WSL:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' simulation/scenario_runner.sh --all
```

The runner executes real Phase 1 actions when a scenario stage is marked `passed`, records simulated failures when a stage is marked `failed`, and writes JSON logs for later telemetry-to-belief mapping and BDI reasoning phases.

## Phase 3: Telemetry To Beliefs

Phase 3 maps Phase 2 event logs into symbolic beliefs for later BDI reasoning.

Generate belief files from all scenario logs:

```sh
./telemetry/belief_mapper.sh
```

On Windows PowerShell:

```powershell
python telemetry/belief_mapper.py
```

Run threshold tests:

```powershell
python telemetry/test_belief_mapper.py
```

Generated beliefs are written to `telemetry/generated_beliefs/`.

## Phase 4: First BDI Agent

Phase 4 adds a first Jason/AgentSpeak release agent:

```text
bdi/cicd_agent.asl
bdi/project.mas2j
```

Prepare one scenario-specific agent:

```sh
./bdi/run_agent_for_scenario.sh success_stable
```

The runner prints the modeled BDI trace from the scenario beliefs and generates Jason files under `bdi/generated/`.

The BDI goal model and expected scenario decisions are documented in:

```text
docs/bdi_goal_model.md
```

## Phase 5: Experiment Results

Run all scenarios, regenerate beliefs, run BDI traces, and compile comparable results:

```sh
./experiments/run_all_scenarios.sh
```

Outputs:

```text
experiments/results/*.json
experiments/comparison_table.md
```

## Phase 6: Upgrade Hooks

Phase 6 documents lightweight extension points for future research:

```text
docs/upgrades.md
upgrade_hooks/
```

The hooks cover future monitoring adapters, CI platform executors, dataset-generated scenarios, failure-risk beliefs, and multi-agent extensions. They are stubs only; no heavy external integration is implemented.

## Phase 7: Real Payment Service With Metrics

Phase 7 adds a small Flask payment service under `app/payment_service/`. It does not replace the CI/CD shell action interface yet; later phases can deploy and scrape this service.

Run locally:

```sh
cd app/payment_service
python -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
python service.py
```

On Windows PowerShell:

```powershell
cd app/payment_service
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python service.py
```

Smoke test:

```sh
curl http://localhost:8000/health
curl -X POST http://localhost:8000/pay -H "Content-Type: application/json" -d '{"amount": 10}'
curl -X POST http://localhost:8000/refund -H "Content-Type: application/json" -d '{"amount": 10}'
curl http://localhost:8000/metrics
```

Useful environment variables:

| Variable | Example | Purpose |
| --- | --- | --- |
| `SERVICE_VERSION` | `stable` or `candidate` | Adds a stable version label to service responses and metrics |
| `FORCE_ERROR_RATE` | `0.25` | Randomly fails about 25% of `/pay` and `/refund` requests |
| `FAILURE_MODE` | `always_error`, `pay_error`, `refund_error`, or `unhealthy` | Forces deterministic failure modes for scenarios |
| `EXTRA_LATENCY_MS` | `500` | Adds fixed latency to health and payment endpoints |
| `PORT` | `8000` | Selects the local HTTP port |

Docker is optional for this phase:

```sh
docker build -t bdi-payment-service app/payment_service
docker run --rm -p 8000:8000 -e SERVICE_VERSION=candidate bdi-payment-service
```

The Prometheus-compatible metrics endpoint is available at:

```text
http://localhost:8000/metrics
```

## Phase 8: Local Docker Compose Runtime

Phase 8 runs two local payment service instances and Prometheus. This keeps the prototype local and explainable while making telemetry collection real.

Services:

| Service | Version | Local URL | Purpose |
| --- | --- | --- | --- |
| `payment-staging` | `candidate` | `http://localhost:8001` | Candidate release target |
| `payment-production` | `stable` | `http://localhost:8002` | Production baseline |
| `prometheus` | n/a | `http://localhost:9090` | Scrapes service metrics |

Start the local runtime:

```sh
docker compose up --build
```

On Windows PowerShell, test the running services:

```powershell
Invoke-WebRequest -UseBasicParsing http://localhost:8001/health
Invoke-WebRequest -UseBasicParsing http://localhost:8002/health
Invoke-WebRequest -UseBasicParsing http://localhost:9090/-/ready
```

Open the Prometheus targets page:

```text
http://localhost:9090/targets
```

Expected targets:

```text
payment-staging
payment-production
```

Both should show as `UP` after Prometheus has had a few seconds to scrape them.

Direct metrics endpoints:

```text
http://localhost:8001/metrics
http://localhost:8002/metrics
```

Stop the local runtime:

```sh
docker compose down
```

The Compose file keeps failure and latency controls explicit. To simulate a bad candidate, edit the `payment-staging` environment values in `docker-compose.yml`, for example:

```yaml
FAILURE_MODE: pay_error
EXTRA_LATENCY_MS: "500"
```

Then restart:

```sh
docker compose up --build
```

## Phase 9: CI/CD Actions Target Local Services

Phase 9 keeps the public action interface shell-callable, but points deployment and health checks at the Docker Compose services from Phase 8.

The command shape is unchanged:

```sh
./cicd/actions/build.sh candidate
./cicd/actions/test.sh candidate
./cicd/actions/security_scan.sh candidate
./cicd/actions/deploy.sh staging candidate
./cicd/actions/health_check.sh staging
./cicd/actions/deploy.sh production candidate
./cicd/actions/health_check.sh production
./cicd/actions/rollback.sh production
```

What each action now does:

| Action | Real-service behavior |
| --- | --- |
| `build.sh VERSION` | Builds the local payment service Docker image when Docker Compose is available |
| `test.sh VERSION` | Validates Compose config, Python syntax, expected API routes, and metric names |
| `security_scan.sh VERSION` | Scans owned service/runtime files for simple secret patterns |
| `deploy.sh staging VERSION` | Starts or recreates `payment-staging` with `SERVICE_VERSION=VERSION` |
| `deploy.sh production VERSION` | Starts or recreates `payment-production` with `SERVICE_VERSION=VERSION` |
| `health_check.sh ENVIRONMENT` | Calls the real `/health` endpoint on port `8001` or `8002` |
| `rollback.sh production` | Recreates production with `SERVICE_VERSION=stable` |

Runtime state is still recorded under:

```text
runtime/state/
```

Useful files include:

```text
runtime/state/staging_version.txt
runtime/state/production_version.txt
runtime/state/previous_production_version.txt
runtime/state/staging_health_checked_at.txt
runtime/state/production_health_checked_at.txt
```

If Docker is unavailable:

```text
build.sh can still validate local service files and Python syntax.
test.sh can still run local Python and source checks.
security_scan.sh can still scan owned service/runtime files.
deploy.sh, health_check.sh, and rollback.sh require Docker Compose because they operate on real local services.
```

On Windows PowerShell, run the shell scripts through Git Bash:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/build.sh candidate
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/test.sh candidate
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/security_scan.sh candidate
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/deploy.sh staging candidate
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/health_check.sh staging
```

## Phase 12: Real Telemetry Experiments

Phase 12 runs real local CI/CD actions, generates payment traffic, queries Prometheus, maps telemetry into BDI beliefs, and records comparable experiment results.

Run:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' experiments/run_real_telemetry_scenarios.sh
```

Outputs:

```text
experiments/real_results/*.json
experiments/real_comparison_table.md
```

The runner currently includes:

| Scenario | Purpose |
| --- | --- |
| `real_success` | Healthy candidate release with stable Prometheus telemetry |
| `real_production_unstable` | `/health` passes, but `/pay` failures make Prometheus-derived beliefs unstable |

Read the comparison table:

```powershell
Get-Content experiments/real_comparison_table.md
```

The unstable real scenario demonstrates why BDI telemetry reasoning is useful: traditional CI/CD sees passing shell actions and health checks, while BDI sees `environment(production, unstable).` from real payment metrics and chooses rollback.

## Phase 13: GitHub Actions Baseline

Phase 13 adds a simple traditional CI workflow:

```text
.github/workflows/traditional-ci.yml
```

It runs on push and pull request, then calls the same public shell action interface used locally:

```sh
./cicd/actions/build.sh candidate
./cicd/actions/test.sh candidate
./cicd/actions/security_scan.sh candidate
```

What it proves:

```text
The repository has a visible traditional CI baseline.
The public shell action interface works in GitHub Actions.
The payment service can be built, checked, and scanned outside the local experiment runner.
```

What it does not prove:

```text
It does not deploy to cloud.
It does not use GitHub as the BDI control plane.
It does not run the real telemetry experiment comparison.
It does not replace local Docker Compose, Prometheus, or Jason/BDI reasoning.
```
