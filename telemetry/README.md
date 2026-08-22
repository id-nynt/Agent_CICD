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

The mapper can also read Prometheus adapter JSON shaped like:

```json
{
  "environment": "production",
  "telemetry": {
    "availability": 1.0,
    "error_rate": 0.0,
    "latency_p95_ms": 25.0
  }
}
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

Generate beliefs from live Prometheus adapter JSON:

```powershell
py telemetry/prometheus_adapter.py production --pretty | Out-File -Encoding utf8 telemetry/live_production.json
py telemetry/belief_mapper.py telemetry/live_production.json
```

This writes:

```text
telemetry/generated_beliefs/production_live.asl
```

On Windows PowerShell, use:

```powershell
py telemetry/belief_mapper.py
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

## Prometheus Adapter

Phase 10 adds a small Prometheus adapter:

```text
telemetry/prometheus_adapter.py
```

It queries the local Prometheus HTTP API and emits the same raw telemetry field names used by the simulated scenarios:

```json
{
  "environment": "production",
  "source": "prometheus",
  "telemetry": {
    "availability": 1.0,
    "error_rate": 0.0,
    "latency_p95_ms": 25.0
  }
}
```

Start the local runtime first:

```sh
docker compose up --build
```

Generate a little traffic so Prometheus has request metrics to scrape:

```powershell
Invoke-RestMethod -Method POST -Uri http://localhost:8002/pay -ContentType "application/json" -Body '{"amount": 10}'
Invoke-RestMethod -Method POST -Uri http://localhost:8002/refund -ContentType "application/json" -Body '{"amount": 10}'
```

Query production telemetry:

```powershell
py telemetry/prometheus_adapter.py production --pretty
```

Query staging telemetry:

```powershell
py telemetry/prometheus_adapter.py staging --pretty
```

Useful direct Prometheus check:

```powershell
Invoke-RestMethod "http://localhost:9090/api/v1/query?query=up"
```

Run adapter tests:

```powershell
py telemetry/test_prometheus_adapter.py
```

The adapter does not change the belief format. The belief mapper can map adapter JSON directly into live environment beliefs such as:

```prolog
telemetry_source(prometheus).
telemetry_environment(production).
metric(production, error_rate, normal).
metric(production, latency, normal).
metric(production, availability, high).
environment(production, stable).
```

## Scope

This telemetry layer does not add Alertmanager, OpenTelemetry, Kubernetes, GitHub APIs, Jason plan changes, or ML. It keeps raw telemetry and symbolic beliefs separate for explainable research experiments.
