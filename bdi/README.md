# First BDI CI/CD Agent

Phase 4 adds a first Jason/AgentSpeak model for CI/CD release reasoning.

Files:

```text
bdi/cicd_agent.asl
bdi/deployment_agent.asl
bdi/project.mas2j
bdi/run_deployment_agent.sh
bdi/run_agent_for_scenario.sh
```

## Persistent Deployment Agent

`bdi/deployment_agent.asl` is the persistent controller starting point for the next architecture phase.

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

This agent uses visible `.print(...)` statements and calls real shell CI/CD actions through the plain Jason environment bridge. It does not poll telemetry yet.

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

Current persistent controller path:

```text
bdi/project.mas2j
  -> bdi/deployment_agent.asl
  -> root goal !deliver_release(candidate)
  -> visible AgentSpeak goal/subgoal decomposition
  -> waits for future perception/action bridge
```

Current experiment path:

```text
experiments/compile_results.py or experiments/real_telemetry_runner.py
  -> calls bdi/run_agent_for_scenario.sh without --jason
  -> parses lines starting with "Decision:"
  -> records that parsed value as the BDI decision
```

For real-telemetry experiments, `experiments/real_telemetry_runner.py` also invokes shell CI/CD actions itself. If the parsed modeled BDI decision is `rollback_production`, the Python runner invokes `cicd/actions/rollback.sh production` externally.

So, at the current audited state:

- Jason is not the default controller.
- Generated `.asl` beliefs are static scenario inputs.
- Beliefs are not dynamically updated in a persistent running Jason agent.
- Jason does not currently invoke the real shell CI/CD actions.
- There is not yet a closed perception -> reasoning -> action -> new perception loop controlled by Jason.

The next implementation step should be a persistent Jason or JaCaMo runtime with an environment/artifact that:

1. exposes CI/CD status and telemetry as perceptions;
2. invokes the existing `cicd/actions/*.sh` scripts as actions;
3. updates observable state while the agent remains alive;
4. lets Jason plans, not Bash/Python decision parsing, choose release, rollback, pause/reobserve, or stop.
