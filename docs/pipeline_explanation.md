# Pipeline Explanation

This document explains the two pipeline styles in this repository:

1. Traditional CI/CD pipeline
2. BDI-enhanced CI/CD pipeline with real telemetry

It also explains how to run them, where to read the results, how to interpret the output, and what the prototype can prove.

## 1. Traditional Pipeline

The traditional pipeline is a sequence of shell-callable actions.

The public action interface is:

```text
cicd/actions/build.sh
cicd/actions/test.sh
cicd/actions/security_scan.sh
cicd/actions/deploy.sh
cicd/actions/health_check.sh
cicd/actions/rollback.sh
```

The command shape is intentionally simple:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/build.sh candidate
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/test.sh candidate
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/security_scan.sh candidate
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/deploy.sh staging candidate
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/health_check.sh staging
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/deploy.sh production candidate
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/health_check.sh production
```

Rollback:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/rollback.sh production
```

### What Each Action Does

| Action | Purpose |
| --- | --- |
| `build.sh candidate` | Builds the local payment service image or validates files if Docker is unavailable |
| `test.sh candidate` | Checks service syntax, expected routes, metrics, and Compose config |
| `security_scan.sh candidate` | Runs a simple source/config scan for secret-like strings |
| `deploy.sh staging candidate` | Starts/recreates the staging service with `SERVICE_VERSION=candidate` |
| `health_check.sh staging` | Calls `http://localhost:8001/health` |
| `deploy.sh production candidate` | Starts/recreates production with `SERVICE_VERSION=candidate` |
| `health_check.sh production` | Calls `http://localhost:8002/health` |
| `rollback.sh production` | Restores production to `SERVICE_VERSION=stable` |

### Traditional Pipeline Logic

Traditional CI/CD mostly asks:

```text
Did each stage pass?
```

Example:

```text
build passed
test passed
security scan passed
staging deploy passed
staging health passed
production deploy passed
production health passed
```

If all pass, traditional CI/CD usually says:

```text
release_success
```

If a production health check fails, traditional CI/CD usually says:

```text
rollback
```

The strength is simplicity. The weakness is that a service can pass `/health` while important business operations such as `/pay` fail.

## 2. New BDI Telemetry Pipeline

The new pipeline keeps the same shell actions but adds telemetry-derived reasoning.

The real telemetry path is:

```text
Payment service
  -> Prometheus metrics
  -> telemetry/prometheus_adapter.py
  -> telemetry/belief_mapper.py
  -> BDI beliefs
  -> bdi/run_agent_for_scenario.sh
  -> BDI decision
  -> experiment result
```

### Step 1: Run Local Services

Start the local runtime:

```powershell
docker compose up --build
```

This starts:

| Service | URL | Role |
| --- | --- | --- |
| `payment-staging` | `http://localhost:8001` | Candidate service |
| `payment-production` | `http://localhost:8002` | Production service |
| `prometheus` | `http://localhost:9090` | Metrics collector |

### Step 2: Generate Real Traffic

The payment service exposes:

```text
GET  /health
POST /pay
POST /refund
GET  /metrics
```

Example traffic:

```powershell
Invoke-RestMethod -Method POST -Uri http://localhost:8002/pay -ContentType "application/json" -Body '{"amount": 10}'
Invoke-RestMethod -Method POST -Uri http://localhost:8002/refund -ContentType "application/json" -Body '{"amount": 10}'
```

### Step 3: Prometheus Scrapes Metrics

Prometheus reads:

```text
payment_service_requests_total
payment_service_errors_total
payment_service_request_latency_seconds_bucket
payment_service_health
```

These metrics answer:

```text
How many requests happened?
How many failed?
How slow were they?
Is the service healthy?
```

### Step 4: Adapter Produces Raw Telemetry

Run:

```powershell
py telemetry/prometheus_adapter.py production --pretty
```

Example:

```json
{
  "environment": "production",
  "telemetry": {
    "availability": 1.0,
    "error_rate": 0.5,
    "latency_p95_ms": 4.75
  }
}
```

This is still numeric telemetry. The BDI agent does not reason directly over these numbers.

### Step 5: Belief Mapper Produces Symbolic Beliefs

Run:

```powershell
py telemetry/prometheus_adapter.py production --pretty | Out-File -Encoding utf8 telemetry/live_production.json
py telemetry/belief_mapper.py telemetry/live_production.json
```

Output:

```text
telemetry/generated_beliefs/production_live.asl
```

Example beliefs:

```prolog
telemetry_source(prometheus).
telemetry_environment(production).
metric(production, error_rate, high).
metric(production, latency, normal).
metric(production, availability, high).
environment(production, unstable).
```

The threshold rules are in:

```text
telemetry/thresholds.yml
```

Current default thresholds:

| Telemetry | Rule |
| --- | --- |
| `error_rate > 0.05` | error rate is high |
| `latency_p95_ms > 500` | latency is high |
| `availability < 0.99` | availability is low |

### Step 6: BDI Agent Reasons

The BDI runner reads a `.asl` belief file.

Run one generated scenario:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' bdi/run_agent_for_scenario.sh real_production_unstable
```

The runner prints a modeled BDI trace.

Example decision:

```text
Decision: rollback_production
```

## How The BDI Agent Works

The BDI agent follows this pattern:

```text
Beliefs: what the system currently knows
Desires: what the system wants to achieve
Intentions: what the system commits to doing
```

### Beliefs

Examples:

```prolog
status(build, passed).
status(test, passed).
status(health_check(production), passed).
metric(production, error_rate, high).
environment(production, unstable).
rollback_available(production).
```

### Desires

The agent wants to:

```text
deliver the release
maintain reliability
recover if production is unstable
record experiment results
```

### Intentions

Depending on beliefs, it chooses intentions such as:

```text
release_complete
rollback_production
pause_reobserve
stop_pipeline
manual_intervention_required
```

### Example Reasoning

If production is stable:

```prolog
environment(production, stable).
```

BDI chooses:

```text
release_complete
```

If production is unstable and rollback is available:

```prolog
environment(production, unstable).
rollback_available(production).
```

BDI chooses:

```text
rollback_production
```

If production looks unstable but context suggests uncertainty:

```prolog
network_issue_suspected(true).
```

BDI may choose:

```text
pause_reobserve
```

## Run The Full Real-Telemetry Experiment

Use:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' experiments/run_real_telemetry_scenarios.sh
```

This runner:

1. Starts Docker Compose.
2. Calls CI/CD actions.
3. Deploys the candidate service.
4. Generates `/pay` and `/refund` traffic.
5. Waits for Prometheus scraping.
6. Queries Prometheus.
7. Generates BDI beliefs.
8. Runs BDI reasoning.
9. Writes JSON results.
10. Writes a Markdown comparison table.

## Where To Read Results

Real-telemetry results:

```text
experiments/real_results/*.json
experiments/real_comparison_table.md
```

Simulated results:

```text
experiments/results/*.json
experiments/comparison_table.md
```

Generated beliefs:

```text
telemetry/generated_beliefs/*.asl
```

Generated BDI files:

```text
bdi/generated/
```

## How To Interpret Real Results

Open:

```powershell
Get-Content experiments/real_comparison_table.md
```

You should see scenarios like:

| Scenario | Meaning |
| --- | --- |
| `real_success` | Healthy traffic, stable metrics, BDI completes release |
| `real_production_unstable` | Health passes, payment errors occur, BDI rolls back |

The important comparison is:

```text
Traditional decision: release_success
BDI decision: rollback_production
```

This means:

```text
The normal health check passed.
The deeper payment telemetry showed production was unstable.
The BDI agent made a safer decision based on telemetry-derived beliefs.
```

## What Can Be Proved

This prototype can support these claims:

```text
The CI/CD action interface can remain simple and shell-callable.
Real Prometheus metrics can replace simulated telemetry.
Numeric telemetry can be mapped into symbolic BDI beliefs.
BDI can make context-aware release decisions from those beliefs.
BDI can detect a production issue that a simple health check misses.
The simulated scenario path and real telemetry path can coexist.
```

## What Cannot Be Proved Yet

This prototype does not prove:

```text
production-grade deployment safety
real payment correctness
Kubernetes readiness
cloud deployment reliability
machine learning prediction quality
GitHub-controlled autonomous operations
multi-agent coordination
```

Those are possible future extensions, not current prototype claims.

## What To Read First

Recommended order:

1. `README.md`
2. `docs/pipeline_explanation.md`
3. `app/payment_service/service.py`
4. `telemetry/prometheus_adapter.py`
5. `telemetry/belief_mapper.py`
6. `bdi/run_agent_for_scenario.sh`
7. `experiments/real_comparison_table.md`
8. `experiments/real_results/real_production_unstable.json`

## Short Summary

Traditional CI/CD asks:

```text
Did the stage pass?
```

The BDI pipeline asks:

```text
Given deployment status, telemetry, and context, what should the release agent intend to do?
```

That difference is the core research contribution of this prototype.
