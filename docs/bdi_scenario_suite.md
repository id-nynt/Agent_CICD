# BDI Scenario Suite

Phase 6 expands the prototype from one closed-loop demo into a reproducible scenario suite.

The catalog is:

```text
experiments/bdi_scenario_catalog.json
```

The runner is:

```text
experiments/run_bdi_scenario_suite.ps1
```

The runner configures scenario stimuli with environment variables, starts the Jason MAS, sends payment traffic when needed, and collects evidence. It does not choose rollback, stop, pause, or manual intervention. Those decisions must appear as beliefs in `deployment_agent`.

## Run

Run every scenario:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\run_bdi_scenario_suite.ps1
```

Run one scenario:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\run_bdi_scenario_suite.ps1 -Scenario production_high_error_rate
```

Use faster local telemetry polling:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\run_bdi_scenario_suite.ps1 -TelemetryIntervalSeconds 3 -TelemetryGraceSeconds 5
```

The suite writes:

```text
experiments/bdi_scenario_results/summary.md
experiments/bdi_scenario_results/<scenario>/result.json
experiments/bdi_scenario_results/<scenario>/summary.md
```

## Scenarios

| Scenario | BDI capability |
| --- | --- |
| `success_stable` | Complete release when action results and telemetry are healthy. |
| `build_failure` | Stop release at the build gate before deployment. |
| `test_failure` | Stop release at the test gate before security scan and deployment. |
| `security_failure` | Stop release at the security gate before staging deployment. |
| `staging_instability` | Treat staging health as a production gate. |
| `production_deploy_failure` | Roll back when production deployment fails after earlier gates passed. |
| `production_health_failure` | Roll back when production deployment succeeds but health verification fails. |
| `production_high_error_rate` | Roll back when `/health` passes but business endpoint telemetry fails. |
| `production_health_transient_retry` | Roll back after a transient production health failure, verify recovery, then continue deploying the same candidate. |
| `high_latency` | Pause and reobserve latency-only instability instead of immediate rollback. |
| `network_suspected` | Escalate telemetry unavailability as suspected network/observability failure. |
| `transient_recovery` | Pause, reobserve, and keep the release after telemetry recovers. |
| `rollback_unavailable` | Escalate to manual intervention when rollback itself fails. |

## Success Criteria

Each scenario passes when expected Jason evidence is observed. For manual inspection, use:

```powershell
jason agent mind deployment_agent
```

The automated runner primarily checks `bdi/logs/cicd_environment.log`, because the local Jason CLI can be daemon-oriented and `agent mind` may not always flush cleanly during automation. The log records percepts added by `CicdEnvironment` and `record_decision(...)` calls made by Jason plans.

Forbidden action patterns must not appear in:

```text
bdi/logs/cicd_environment.log
```

For example, build failure should show:

```text
status(build,failed)[source(percept)]
decision(stop_pipeline)[source(self)]
stop_reason(build_failed)[source(self)]
```

and should not show staging or production deploy actions.

## What The Runner Does Not Do

The runner does not decide:

```text
release_complete
stop_pipeline
rollback_production
pause_reobserve
manual_intervention_required
```

Those decisions are selected in `bdi/deployment_agent.asl`. The runner configures environment variables, starts Jason, sends HTTP traffic as stimulus, and waits for evidence.

## Tested Evidence

The current result folders are under:

```text
experiments/bdi_scenario_results/
```

Each scenario has:

```text
result.json
summary.md
```

Examples:

```text
production_high_error_rate -> metric(production,error_rate,high), decision(rollback_production)
production_health_transient_retry -> decision(rollback_then_retry_production), decision(continue_deploy_candidate)
high_latency -> metric(production,latency,high), decision(pause_reobserve)
network_suspected -> telemetry(production,unavailable), decision(manual_intervention_required)
transient_recovery -> decision(reobserve_recovered), decision(release_complete)
```

## Limitations

The suite is a local reproducibility harness. It is not a production deployment test. Docker timing and Prometheus scrape windows can affect runtime duration, so targeted single-scenario runs are often clearer for supervisor review than one long all-scenario run.
