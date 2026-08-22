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
