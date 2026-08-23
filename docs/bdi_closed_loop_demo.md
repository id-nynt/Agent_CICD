# BDI Closed Loop Demo

This demo proves the full Jason-controlled loop:

```text
perceive -> reason -> act -> perceive again
```

The scenario:

```text
1. Jason deploys the candidate to production.
2. Production /health passes.
3. The demo sends failing POST /pay traffic.
4. Prometheus reports high payment error rate.
5. CicdEnvironment maps telemetry to Jason percepts.
6. deployment_agent reacts to environment(production, unstable).
7. Jason invokes rollback(production).
8. CicdEnvironment calls cicd/actions/rollback.sh production.
9. Rollback success becomes a Jason percept.
```

Run from the repository root:

```powershell
.\experiments\run_bdi_closed_loop.ps1
```

Optional faster settings:

```powershell
.\experiments\run_bdi_closed_loop.ps1 -TelemetryIntervalSeconds 3 -TelemetryGraceSeconds 5 -TrafficCount 12
```

The runner orchestrates setup and traffic stimulus only. It does not choose rollback. Rollback must appear because Jason receives telemetry percepts and selects the recovery plan.

Expected result:

```text
[closed_loop] PASS: Jason closed loop triggered rollback from telemetry.
```

Evidence is written to:

```text
experiments/bdi_closed_loop_results/production_telemetry_rollback.md
```

Useful evidence patterns:

```text
[CicdEnvironment][telemetry] production error_rate=1.0000(high)
[CicdEnvironment][telemetry] ... environment=unstable
[CicdEnvironment] action ... cicd\actions\rollback.sh production
[CicdEnvironment] percept status(rollback(production), passed)
```

Expected Jason mind evidence:

```text
metric(production,error_rate,high)[source(percept)]
environment(production,unstable)[source(percept)]
recovery_reason(telemetry_unstable)[source(self)]
decision(rollback_production)[source(self)]
status(rollback(production),passed)[source(percept)]
```

If the scenario times out:

- confirm Docker Desktop is running;
- confirm Prometheus is ready at `http://localhost:9090/-/ready`;
- inspect `bdi/logs/cicd_environment.log`;
- run `py telemetry/prometheus_adapter.py production --pretty`;
- increase `-TimeoutSeconds`.
