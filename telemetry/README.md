# Telemetry To Belief Mapping

Phase 3 converts Phase 2 scenario files or event logs and simulated telemetry into symbolic BDI beliefs.

The BDI agent should not reason over raw metrics such as `0.12` or `900`. It should reason over beliefs such as:

```prolog
metric(production, error_rate, high).
metric(production, latency, high).
environment(production, unstable).
```

## Inputs

The mapper can read scenario YAML files from:

```text
simulation/scenarios/
```

It can also read JSON event logs from:

```text
simulation/event_log/
```

These logs are produced by:

```sh
./simulation/scenario_runner.sh --all
```

## Thresholds

Threshold rules live in:

```text
telemetry/thresholds.yml
```

Current defaults:

| Raw telemetry | Belief rule |
| --- | --- |
| `error_rate > 0.05` | `metric(production, error_rate, high).` |
| `error_rate <= 0.05` | `metric(production, error_rate, normal).` |
| `latency_p95_ms > 500` | `metric(production, latency, high).` |
| `latency_p95_ms <= 500` | `metric(production, latency, normal).` |
| `availability < 0.99` | `metric(production, availability, low).` |
| `availability >= 0.99` | `metric(production, availability, high).` |

Any bad production metric means:

```prolog
environment(production, unstable).
```

A failed production health check also makes production unstable.

## Run Mapper

Generate beliefs for all event logs:

```sh
./telemetry/belief_mapper.sh
```

Generate beliefs for one event log:

```sh
./telemetry/belief_mapper.sh simulation/event_log/production_unstable.json
```

Generate beliefs directly from one scenario file:

```sh
./telemetry/belief_mapper.sh simulation/scenarios/production_unstable.yml
```

On Windows PowerShell, use:

```powershell
python telemetry/belief_mapper.py
```

Outputs are written to:

```text
telemetry/generated_beliefs/
```

## Run Tests

```sh
python telemetry/test_belief_mapper.py
```

The tests verify normal metrics, bad metrics, and strict threshold boundaries.

## Scope

This phase does not connect to Prometheus, OpenTelemetry, Kubernetes, GitHub APIs, Jason, or ML. It is a local mapping layer for explainable research experiments.
