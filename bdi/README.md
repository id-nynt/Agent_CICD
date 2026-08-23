# Jason BDI CI/CD Runtime

This folder contains the active Jason BDI controller and the legacy static scenario scaffolding. The active runtime is `deployment_agent.asl` plus `CicdEnvironment.java`; the legacy `cicd_agent.asl` and `run_agent_for_scenario.sh` path is retained for audit/history only.

Files:

```text
bdi/cicd_agent.asl
bdi/deployment_agent.asl
bdi/project.mas2j
bdi/run_deployment_agent.sh
bdi/run_agent_for_scenario.sh
```

## Persistent Deployment Agent

`bdi/deployment_agent.asl` is the persistent controller used by the current prototype.

It adopts:

```prolog
!deliver_release(candidate).
```

and decomposes that root goal into:

```text
prepare candidate
build candidate
test candidate
security scan candidate
deploy to staging
verify staging
deploy to production
verify production
maintain reliability
```

This agent uses visible `.print(...)` statements, calls real shell CI/CD actions through the plain Jason environment bridge, and reacts to Prometheus telemetry percepts while it remains alive.

Run the persistent MAS:

```powershell
jason bdi\project.mas2j
```

If your current terminal is already inside `bdi/`, run:

```powershell
jason project.mas2j
```

or from Git Bash:

```sh
./bdi/run_deployment_agent.sh
```

Gradle is optional for this phase. If you prefer Gradle from inside `bdi/`, use:

```powershell
gradle run
```

The local `bdi/build.gradle` is configured to run `project.mas2j` relative to the `bdi/` directory.

## Plain Jason Action Bridge

Phase 3A adds a plain Jason environment class:

```text
bdi/src/env/CicdEnvironment.java
```

`bdi/project.mas2j` registers it with:

```mas2j
environment: CicdEnvironment
```

The environment maps Jason actions to the existing shell action interface:

| Jason action | Shell script |
| --- | --- |
| `build(candidate)` | `cicd/actions/build.sh candidate` |
| `test(candidate)` | `cicd/actions/test.sh candidate` |
| `security_scan(candidate)` | `cicd/actions/security_scan.sh candidate` |
| `deploy(candidate, staging)` | `cicd/actions/deploy.sh staging candidate` |
| `deploy(candidate, production)` | `cicd/actions/deploy.sh production candidate` |
| `health_check(staging)` | `cicd/actions/health_check.sh staging` |
| `health_check(production)` | `cicd/actions/health_check.sh production` |
| `rollback(production)` | `cicd/actions/rollback.sh production` |

Action exit codes become percepts such as:

```prolog
status(build, passed).
status(build, failed).
status(deploy(staging), passed).
status(health_check(production), failed).
environment(production, unstable).
```

Runtime bridge logs are written to:

```text
bdi/logs/cicd_environment.log
```

This log is intentionally ignored by Git. Use it as local evidence that Jason invoked the environment and the environment invoked shell scripts.

Example verification when Docker Desktop is not running:

```powershell
cd bdi
jason project.mas2j
```

In another terminal:

```powershell
Get-Content .\logs\cicd_environment.log -Tail 40
jason agent mind deployment_agent
jason agent status deployment_agent
```

Expected local evidence when Docker Desktop is stopped:

```text
[CicdEnvironment] action ... cicd\actions\build.sh candidate
[CicdEnvironment] exit_code=1 script=build.sh
[CicdEnvironment] percept status(build, failed)
```

and:

```text
status(build,failed)[source(percept)]
```

For the full successful release path, start Docker Desktop first. The deploy and rollback scripts require Docker Compose and the Docker engine.

## Failure-Path Verification

Phase 3B adds force-failure switches for testing Jason control flow without editing `cicd/actions/*.sh`.

Supported switches:

| Switch | Forced percept |
| --- | --- |
| `BDI_FORCE_BUILD_FAIL=true` | `status(build, failed)` |
| `BDI_FORCE_TEST_FAIL=true` | `status(test, failed)` |
| `BDI_FORCE_SECURITY_SCAN_FAIL=true` | `status(security_scan, failed)` |
| `BDI_FORCE_DEPLOY_STAGING_FAIL=true` | `status(deploy(staging), failed)` |
| `BDI_FORCE_HEALTH_CHECK_STAGING_FAIL=true` | `status(health_check(staging), failed)` and `environment(staging, unstable)` |
| `BDI_FORCE_DEPLOY_PRODUCTION_FAIL=true` | `status(deploy(production), failed)` |
| `BDI_FORCE_HEALTH_CHECK_PRODUCTION_FAIL=true` | `status(health_check(production), failed)` and `environment(production, unstable)` |
| `BDI_FORCE_ROLLBACK_PRODUCTION_FAIL=true` | `status(rollback(production), failed)` |

Example build-failure test:

```powershell
cd bdi
$env:BDI_FORCE_BUILD_FAIL="true"
jason project.mas2j
```

In another terminal:

```powershell
jason agent mind deployment_agent
Get-Content .\logs\cicd_environment.log -Tail 40
```

Expected:

```text
status(build,failed)[source(percept)]
```

and no later deployment percepts from that run.

Verified Phase 3B build-failure evidence:

```text
[CicdEnvironment] forced_failure stage=build env=BDI_FORCE_BUILD_FAIL
[CicdEnvironment] percept status(build, failed)
```

Agent mind:

```text
status(build,failed)[source(percept)]
```

Clear the switch afterward:

```powershell
Remove-Item Env:\BDI_FORCE_BUILD_FAIL
```

For production recovery testing, start Docker Desktop first, then use one of:

```powershell
$env:BDI_FORCE_DEPLOY_PRODUCTION_FAIL="true"
$env:BDI_FORCE_HEALTH_CHECK_PRODUCTION_FAIL="true"
```

Expected recovery evidence includes:

```text
status(rollback(production),passed)[source(percept)]
```

Verified Phase 3B production-health failure evidence:

```text
[CicdEnvironment] forced_failure stage=health_check_production env=BDI_FORCE_HEALTH_CHECK_PRODUCTION_FAIL
[CicdEnvironment] percept status(health_check(production), failed)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment] action ... cicd\actions\rollback.sh production
[CicdEnvironment] percept status(rollback(production), passed)
[CicdEnvironment] percept environment(production, stable)
```

If rollback is also forced to fail:

```powershell
$env:BDI_FORCE_ROLLBACK_PRODUCTION_FAIL="true"
```

the expected decision path is manual intervention.

## Dynamic Prometheus Telemetry Perceptions

Phase 4 adds periodic Prometheus polling inside the plain Jason environment bridge. This keeps the same running `deployment_agent` alive while runtime telemetry becomes Jason percepts.

The environment reads thresholds from:

```text
telemetry/thresholds.yml
```

Current threshold semantics:

| Raw value | Percept state |
| --- | --- |
| `error_rate > 0.05` | `metric(production, error_rate, high)` |
| `error_rate <= 0.05` | `metric(production, error_rate, normal)` |
| `latency_p95_ms > 500` | `metric(production, latency, high)` |
| `latency_p95_ms <= 500` | `metric(production, latency, normal)` |
| `availability < 0.99` | `metric(production, availability, low)` |
| `availability >= 0.99` | `metric(production, availability, high)` |

Any bad telemetry state updates:

```prolog
environment(production, unstable).
```

Otherwise the environment is:

```prolog
environment(production, stable).
```

Telemetry settings:

| Variable | Default | Meaning |
| --- | --- | --- |
| `BDI_TELEMETRY_ENABLED` | `true` | Set to `false` to disable polling |
| `BDI_TELEMETRY_INTERVAL_SECONDS` | `10` | Polling interval |
| `BDI_TELEMETRY_GRACE_SECONDS` | `15` | Skip production telemetry briefly after deploy/rollback |
| `BDI_PROMETHEUS_URL` | `http://localhost:9090` | Prometheus base URL |

The grace window prevents transient Docker restart/scrape gaps from being interpreted as production regressions during deployment.

Run with faster polling for local verification:

```powershell
cd bdi
$env:BDI_TELEMETRY_INTERVAL_SECONDS="3"
$env:BDI_TELEMETRY_GRACE_SECONDS="5"
jason project.mas2j
```

In another terminal:

```powershell
Get-Content .\logs\cicd_environment.log -Tail 80
jason agent mind deployment_agent
py ..\telemetry\prometheus_adapter.py production --pretty
```

Expected log evidence:

```text
[CicdEnvironment][telemetry] thresholds error_rate_high_gt=0.05 latency_p95_ms_high_gt=500.0 availability_low_lt=0.99
[CicdEnvironment][telemetry] polling enabled interval_seconds=3
[CicdEnvironment][telemetry] skipped production poll during deployment grace window
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=1.0000(high) environment=stable
```

Expected Jason mind evidence:

```text
metric(production,availability,high)[source(percept)]
metric(production,error_rate,normal)[source(percept)]
metric(production,latency,normal)[source(percept)]
environment(production,stable)[source(percept)]
release_monitoring_enabled(production)[source(self)]
```

The agent has a reactive plan for post-release telemetry instability:

```prolog
+environment(production, unstable)
  : release_monitoring_enabled(production)
    & status(deploy(production), passed)
    & not recovery_attempted(production)
<- !recover_production(telemetry_unstable).
```

That means telemetry instability can trigger Jason recovery after the release has reached the reliability-monitoring phase.

## Closed Perception-Reasoning-Action Loop

Phase 5 adds a focused closed-loop demo:

```powershell
.\experiments\run_bdi_closed_loop.ps1
```

The scenario:

```text
Jason deploys candidate through CicdEnvironment
Production /health passes
The runner sends failing POST /pay traffic as stimulus only
Prometheus reports high production error rate
CicdEnvironment updates telemetry percepts
deployment_agent reacts to environment(production, unstable)
Jason invokes rollback(production)
CicdEnvironment calls cicd/actions/rollback.sh production
Rollback result becomes status(rollback(production), passed)
```

The runner does not decide rollback. It resets the local runtime, starts Jason, sends traffic, waits for evidence, and writes the result report.

Expected command result:

```text
[closed_loop] PASS: Jason closed loop triggered rollback from telemetry.
```

Evidence is written to:

```text
experiments/bdi_closed_loop_results/production_telemetry_rollback.md
```

Important evidence patterns:

```text
[CicdEnvironment][telemetry] production error_rate=1.0000(high) ... environment=unstable
[CicdEnvironment] action ... cicd\actions\rollback.sh production
[CicdEnvironment] percept status(rollback(production), passed)
```

Expected Jason mind evidence includes:

```text
recovery_reason(telemetry_unstable)[source(self)]
decision(rollback_production)[source(self)]
status(rollback(production),passed)[source(percept)]
```

On the audited Windows/Jason CLI 3.3.0 setup, the MAS starts and can be confirmed with:

```powershell
jason mas list
jason agent list
jason agent status deployment_agent
```

Expected registration:

```text
cicd_bdi
deployment_agent
```

The audited `jason agent status deployment_agent` output showed the agent alive with one waiting intention after the release-goal decomposition reached `!keep_alive`.

The local Jason 3 launcher is daemon-oriented in this setup, so `.print(...)` output may not stream back to the captured terminal even though the MAS and agent are registered. The AgentSpeak file still contains explicit prints so a console-capable Jason run can show the goal/subgoal trace.

## Legacy Static Scenario Agent

Generate beliefs first:

```sh
./telemetry/belief_mapper.sh
```

Prepare and run one scenario:

```sh
./bdi/run_agent_for_scenario.sh success_stable
```

By default, the runner prints a deterministic modeled BDI trace from the generated beliefs. That output is produced by Bash logic in `bdi/run_agent_for_scenario.sh`, not by the Jason runtime.

This default mode is useful as legacy demonstration scaffolding, but it should not be used as evidence that Jason selected plans, adopted intentions, or invoked CI/CD actions.

To also try the installed Jason CLI:

```sh
./bdi/run_agent_for_scenario.sh success_stable --jason
```

Audit note from 2026-08-23:

- `jason --version` reports `Jason CLI 3.3.0`.
- The `--jason` branch is reachable and prints `[bdi_runner] running Jason via java -jar`.
- In the audited `success_stable` run, the Jason command exited successfully but did not emit the agent's `.print(...)` trace to the captured console.
- Therefore, the current repository proves that Jason files are generated and that the Jason launcher can be attempted, but the normal experiment path still relies on the modeled Bash trace for decisions.

The runner creates scenario-specific files under:

```text
bdi/generated/
```

You can run the generated `.mas2j` file manually in a Jason environment if needed.

Expected decisions are documented in:

```text
docs/bdi_goal_model.md
```

## Current Runtime Boundary

Current static BDI path:

```text
telemetry/generated_beliefs/<scenario>.asl
  -> prepended to bdi/cicd_agent.asl
  -> bdi/generated/<scenario>_agent.asl
  -> modeled trace printed by bdi/run_agent_for_scenario.sh
```

Active persistent controller path:

```text
bdi/project.mas2j
  -> bdi/deployment_agent.asl
  -> root goal !deliver_release(candidate)
  -> CicdEnvironment.java
  -> cicd/actions/*.sh
  -> Prometheus telemetry percepts
  -> AgentSpeak recovery / pause / stop / release plans
```

Legacy modeled experiment path:

```text
experiments/compile_results.py or experiments/real_telemetry_runner.py
  -> calls bdi/run_agent_for_scenario.sh without --jason
  -> parses lines starting with "Decision:"
  -> records that parsed value as the BDI decision
```

For real-telemetry experiments, `experiments/real_telemetry_runner.py` also invokes shell CI/CD actions itself. If the parsed modeled BDI decision is `rollback_production`, the Python runner invokes `cicd/actions/rollback.sh production` externally.

So, at the current implemented state:

- Jason is the controller for the persistent `deployment_agent` path.
- Generated `.asl` beliefs are static scenario inputs.
- The legacy scenario runner still uses static generated beliefs and modeled Bash traces.
- The persistent `deployment_agent` path invokes real shell CI/CD actions through `CicdEnvironment`.
- Action results and Prometheus telemetry are dynamically updated as Jason percepts in the active path.
- The closed-loop demo proves perception -> reasoning -> action -> new perception for production rollback.

The legacy path remains useful for comparing how the project evolved, but it should not be used as evidence that Jason made runtime decisions.

## Expanded Scenario Suite

Phase 6 adds a Jason-controlled scenario suite:

```text
experiments/bdi_scenario_catalog.json
experiments/run_bdi_scenario_suite.ps1
docs/bdi_scenario_suite.md
```

Run all scenarios:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\run_bdi_scenario_suite.ps1
```

Run one scenario:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\run_bdi_scenario_suite.ps1 -Scenario production_high_error_rate
```

The suite currently covers:

```text
success_stable
build_failure
test_failure
security_failure
staging_instability
production_high_error_rate
high_latency
network_suspected
transient_recovery
rollback_unavailable
```

The runner only configures stimuli, sends traffic, and collects evidence. Decisions such as `stop_pipeline`, `pause_reobserve`, `rollback_production`, and `manual_intervention_required` are recorded when `deployment_agent` calls `record_decision(...)` from AgentSpeak plans.

Results are written to:

```text
experiments/bdi_scenario_results/summary.md
experiments/bdi_scenario_results/<scenario>/result.json
experiments/bdi_scenario_results/<scenario>/summary.md
```

## Traditional vs BDI Comparison

Phase 7 adds a comparison runner:

```powershell
py .\experiments\run_traditional_vs_bdi_comparison.py
```

It writes:

```text
experiments/traditional_vs_bdi_results/comparison_report.md
experiments/traditional_vs_bdi_results/comparison_results.json
```

The traditional controller runs the fixed shell-action sequence. The BDI controller is executed through the Jason scenario suite, and the comparison runner only records the BDI evidence; it does not select BDI decisions.
