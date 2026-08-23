# Detailed Execution Walkthrough: What Happens Behind The Stage

This document explains the current repository in plain language, but with enough detail to trace the real execution path.

The main example is the BDI scenario:

```text
production_high_error_rate
```

That scenario proves this idea:

```text
Production /health can pass, but real /pay traffic can fail.
Prometheus sees the failures.
The Jason BDI agent receives telemetry-derived beliefs.
The agent chooses rollback.
The rollback script restores the stable production version.
```

## 0. BDI Model In This Project

The BDI model lives mainly in:

```text
bdi/
```

Important files:

| File | Meaning |
| --- | --- |
| `bdi/project.mas2j` | Jason project file. It starts the MAS, one agent, and one environment. |
| `bdi/deployment_agent.asl` | The real current BDI agent. It contains beliefs, goals, plans, and decisions. |
| `bdi/src/env/CicdEnvironment.java` | Java environment bridge between Jason and the outside world. |
| `bdi/cicd_agent.asl` | Older static/legacy agent used by the generated-belief demo path. |
| `bdi/run_agent_for_scenario.sh` | Older legacy runner that can print modeled traces. Not the main real BDI runtime. |

The active BDI architecture has:

```text
1 Jason agent
1 Jason environment
```

There are no subagents yet.

| Runtime part | Function |
| --- | --- |
| `deployment_agent` | Decides the release workflow and reacts to new beliefs. |
| `CicdEnvironment` | Executes shell scripts, queries Prometheus, and inserts percepts into Jason. |

The agent's main goal is:

```text
deliver_release(candidate)
```

Human-readable meaning:

```text
Try to safely deliver the candidate version.
Build it, test it, scan it, deploy it to staging, verify staging,
deploy it to production, verify production, then keep watching reliability.
```

The agent can decide:

| Decision | Meaning |
| --- | --- |
| `release_complete` | The release is accepted. |
| `stop_pipeline` | Stop before production because an earlier gate failed. |
| `rollback_production` | Restore stable production. |
| `pause_reobserve` | Wait and observe again before acting. |
| `manual_intervention_required` | Escalate to a human. |

## 1. What Process Starts The Demo?

For the main closed-loop demo, this process starts everything:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\run_bdi_closed_loop.ps1
```

For a named scenario such as high production error rate:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\run_bdi_scenario_suite.ps1 -Scenario production_high_error_rate
```

What the runner does:

1. Clears or resets local evidence files.
2. Resets Docker Compose runtime with `docker compose down --remove-orphans`.
3. Sets environment variables for the scenario.
4. Starts Jason with `bdi/project.mas2j`.
5. Sends HTTP traffic when the scenario needs runtime stimulus.
6. Waits for evidence in `bdi/logs/cicd_environment.log`.
7. Writes JSON and Markdown result files.

Important boundary:

```text
The runner starts the demo and creates stimulus.
The runner does not choose the BDI decision.
The Jason agent chooses the BDI decision.
```

## 2. What Components Are Running?

During the real BDI demo, these components run:

| Component | Runtime type | Usually visible where |
| --- | --- | --- |
| Jason MAS | Java/Jason process | `jason mas list` |
| `deployment_agent` | Jason agent | `jason agent mind deployment_agent` |
| `CicdEnvironment` | Java class inside Jason runtime | `bdi/logs/cicd_environment.log` |
| `payment-staging` | Docker container | `localhost:8001` |
| `payment-production` | Docker container | `localhost:8002` |
| `prometheus` | Docker container | `localhost:9090` |
| Scenario runner | PowerShell process | terminal output |

Check Docker containers:

```powershell
docker ps
```

Check Prometheus:

```powershell
Invoke-WebRequest -UseBasicParsing http://localhost:9090/-/ready
```

Check production payment service:

```powershell
Invoke-WebRequest -UseBasicParsing http://localhost:8002/health
```

## 3. What Does Each Component Do?

| Component | One-sentence explanation |
| --- | --- |
| Scenario runner | Starts the experiment, configures faults, and collects evidence. |
| Jason MAS | Hosts the BDI agent and environment. |
| `deployment_agent` | Chooses what CI/CD action should happen next. |
| `CicdEnvironment` | Converts Jason actions into shell script calls and converts telemetry into percepts. |
| Shell action scripts | Actually build, test, deploy, health-check, and rollback the local service. |
| Docker Compose | Runs the fake staging service, fake production service, and Prometheus. |
| Payment service | Produces business responses and Prometheus metrics. |
| Prometheus | Pulls `/metrics` from services and stores time-series samples. |

## 4. What Calls What?

There are two important call paths.

### 4.1 Action Path

This is how a BDI action becomes a real CI/CD effect.

```text
deployment_agent.asl
  calls deploy(candidate, production)

CicdEnvironment.java
  receives the external action
  maps it to cicd/actions/deploy.sh production candidate

deploy.sh
  runs docker compose up for payment-production

Docker
  starts or recreates the production container

CicdEnvironment.java
  sees shell exit code
  adds status(deploy(production), passed) or failed as a Jason percept
```

Example mapping:

| Jason action | Java method effect | Shell script |
| --- | --- | --- |
| `build(candidate)` | Run build stage | `cicd/actions/build.sh candidate` |
| `test(candidate)` | Run test stage | `cicd/actions/test.sh candidate` |
| `security_scan(candidate)` | Run scan stage | `cicd/actions/security_scan.sh candidate` |
| `deploy(candidate, staging)` | Deploy staging | `cicd/actions/deploy.sh staging candidate` |
| `deploy(candidate, production)` | Deploy production | `cicd/actions/deploy.sh production candidate` |
| `health_check(production)` | Check production `/health` | `cicd/actions/health_check.sh production` |
| `rollback(production)` | Restore stable production | `cicd/actions/rollback.sh production` |

### 4.2 Telemetry Path

This is how runtime behavior becomes BDI beliefs.

```text
Payment service handles /pay, /refund, /health
  -> service.py updates in-memory Prometheus metric objects

Payment service exposes /metrics
  -> metrics are text in Prometheus exposition format

Prometheus scrapes /metrics every 5 seconds
  -> samples are stored inside Prometheus time-series database

CicdEnvironment polls Prometheus HTTP API
  -> receives JSON query responses

CicdEnvironment applies thresholds
  -> converts numbers into symbolic percepts

Jason receives percepts
  -> deployment_agent belief base changes

AgentSpeak plans react
  -> rollback, pause, release, stop, or manual intervention
```

## 5. Where Does Telemetry Originate?

Telemetry originates in:

```text
app/payment_service/service.py
```

The payment service creates Prometheus metrics using `prometheus_client`.

Important metrics:

| Metric | Meaning |
| --- | --- |
| `payment_service_requests_total` | Count of handled requests. |
| `payment_service_errors_total` | Count of failed payment/refund requests. |
| `payment_service_request_latency_seconds` | Request duration histogram. |
| `payment_service_health` | Gauge: 1 means healthy, 0 means unhealthy. |

These metrics live in the running Python process memory first.

They are exposed at:

```text
GET /metrics
```

For production on the host machine:

```text
http://localhost:8002/metrics
```

Inside Docker network, Prometheus scrapes:

```text
http://payment-production:8000/metrics
```

## 6. How Does Prometheus Obtain Telemetry?

Prometheus is configured in:

```text
runtime/prometheus/prometheus.yml
```

It contains scrape jobs for:

```text
payment-staging:8000
payment-production:8000
```

Prometheus is pull-based.

That means:

```text
The payment service does not push metrics to Prometheus.
Prometheus periodically calls /metrics and pulls the latest values.
```

Current scrape interval:

```text
5 seconds
```

Prometheus stores the scraped samples internally in its own time-series database inside the container. The repo does not write those samples to JSON files by default.

You can query Prometheus manually:

```powershell
py telemetry/prometheus_adapter.py production --pretty
```

That script calls the Prometheus HTTP API and prints JSON.

## 7. Where Is Telemetry Converted Into BDI Beliefs?

In the real Jason runtime, telemetry is converted inside:

```text
bdi/src/env/CicdEnvironment.java
```

Important functions:

| Function | What it does |
| --- | --- |
| `startTelemetryPolling()` | Starts a background polling loop when the environment initializes. |
| `pollTelemetry("production")` | Queries Prometheus for production metrics. |
| `queryPrometheus(...)` | Calls Prometheus HTTP API. |
| `loadThresholds()` | Reads thresholds from `telemetry/thresholds.yml`. |
| `updateMetric(...)` | Removes old metric percepts and adds new ones. |
| `updateStatus(...)` | Adds status/environment percepts such as stable or unstable. |

This conversion is real time in the sense that it happens periodically while Jason is running.

It is not triggered manually by `belief_mapper.py`.

Current default behavior:

```text
CicdEnvironment starts polling automatically when Jason starts.
Polling interval defaults to 10 seconds.
Scenario runners often set it to 3 seconds for demos.
```

The thresholds are:

```text
telemetry/thresholds.yml
```

Example:

```text
error_rate_high_gt: 0.05
latency_p95_ms_high_gt: 500
availability_low_lt: 0.99
```

Meaning:

```text
If error rate > 0.05, belief becomes metric(production,error_rate,high).
If latency p95 > 500 ms, belief becomes metric(production,latency,high).
If availability < 0.99, belief becomes metric(production,availability,low).
If any of those is bad, environment(production,unstable) is added.
```

## 8. Are Converted Beliefs Stored Anywhere?

There are three different places to understand.

### 8.1 Live Jason Belief Base

The actual active beliefs are stored inside the running Jason agent.

Inspect them with:

```powershell
cd bdi
jason agent mind deployment_agent
```

Example:

```text
metric(production,error_rate,high)[source(percept)]
environment(production,unstable)[source(percept)]
decision(rollback_production)[source(self)]
```

### 8.2 Environment Log

The environment writes evidence to:

```text
bdi/logs/cicd_environment.log
```

This is a log file, not the agent's belief store.

It is useful because it shows:

```text
which shell action was called
which script exit code happened
which percept was added
which decision-recording action Jason called
```

Example:

```text
[CicdEnvironment] percept status(rollback(production), passed)
[CicdEnvironment][decision] rollback_production
```

### 8.3 Legacy Generated Belief Files

The folder:

```text
telemetry/generated_beliefs/
```

belongs to the older static scenario path.

Those `.asl` files are not the live belief base of the persistent Jason controller. They are legacy scaffolding.

## 9. Which `.asl` Plans React To Telemetry Beliefs?

All active plans are in:

```text
bdi/deployment_agent.asl
```

Important plan groups:

### 9.1 Normal Release Goal

When the agent starts, it adopts:

```text
deliver_release(candidate)
```

Human-readable behavior:

```text
build -> test -> security scan -> staging deploy -> staging health check
-> production deploy -> production health check -> reliability monitoring
```

### 9.2 High Error Rate / General Production Instability

When production becomes unstable after deployment and monitoring is enabled:

```text
environment(production, unstable)
```

If it is not specifically telemetry unavailable or latency-only, the agent runs:

```text
recover_production(telemetry_unstable)
```

That leads to:

```text
rollback(production)
```

### 9.3 High Latency

If production is unstable because latency is high, but error rate is not high:

```text
metric(production, latency, high)
```

The agent chooses:

```text
pause_reobserve(high_latency)
```

Meaning:

```text
Do not rollback immediately.
Wait and check whether the condition remains bad.
```

### 9.4 Telemetry Unavailable / Network Suspected

If telemetry polling fails:

```text
telemetry(production, unavailable)
network(production, suspected)
```

The agent chooses:

```text
pause_reobserve(network_suspected)
```

If it still cannot observe production, it records:

```text
manual_intervention_required
```

### 9.5 Rollback Result

After rollback:

```text
status(rollback(production), passed)
```

The agent records:

```text
decision(rollback_production)
```

If rollback fails:

```text
status(rollback(production), failed)
```

The agent records:

```text
decision(manual_intervention_required)
```

## 10. How Does An Agent Action Affect The CI/CD Pipeline?

The agent does not directly modify Docker.

It acts through this chain:

```text
AgentSpeak action
  -> CicdEnvironment Java method
  -> shell script in cicd/actions/
  -> Docker Compose / curl / filesystem state
  -> shell exit code
  -> percept back to Jason
```

Example rollback:

```text
deployment_agent chooses rollback(production)
  -> CicdEnvironment receives rollback(production)
  -> CicdEnvironment calls cicd/actions/rollback.sh production
  -> rollback.sh sets production version to stable
  -> docker compose recreates payment-production
  -> rollback.sh exits 0
  -> CicdEnvironment adds status(rollback(production), passed)
  -> CicdEnvironment adds environment(production, stable)
  -> deployment_agent records decision(rollback_production)
```

This is how a BDI plan affects the simulated CI/CD pipeline.

## 11. Complete Failure Scenario

Scenario:

```text
production_high_error_rate
```

### Step 1: Scenario Starts

Command:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\run_bdi_scenario_suite.ps1 -Scenario production_high_error_rate
```

The runner reads:

```text
experiments/bdi_scenario_catalog.json
```

For this scenario, it configures production so `/pay` fails:

```text
PAYMENT_PRODUCTION_FAILURE_MODE=pay_error
```

### Step 2: Jason Starts Immediately

The runner starts Jason:

```text
jason project.mas2j
```

from the `bdi/` directory.

Jason loads:

```text
bdi/project.mas2j
```

That starts:

```text
deployment_agent
CicdEnvironment
```

Important point:

```text
The BDI agent is running from the beginning of the release.
It is not started after telemetry conversion.
```

### Step 3: Environment Starts Polling

When `CicdEnvironment` initializes, it:

1. Finds the repository root.
2. Finds Git Bash.
3. Opens `bdi/logs/cicd_environment.log`.
4. Reads `telemetry/thresholds.yml`.
5. Starts periodic Prometheus polling.

Early polling may fail or show no data if production is not deployed yet. That is normal during startup.

### Step 4: Agent Executes Release Plan

The agent's root goal starts:

```text
deliver_release(candidate)
```

It calls actions:

```text
build(candidate)
test(candidate)
security_scan(candidate)
deploy(candidate, staging)
health_check(staging)
deploy(candidate, production)
health_check(production)
```

Each action goes through `CicdEnvironment`.

For example:

```text
deploy(candidate, production)
  -> cicd/actions/deploy.sh production candidate
  -> docker compose starts payment-production
```

### Step 5: Production Health Passes

The production health check calls:

```text
http://localhost:8002/health
```

The service returns:

```text
OK
```

The environment adds:

```text
status(health_check(production), passed)
environment(production, stable)
```

At this point, a traditional fixed pipeline would usually say:

```text
release_complete
```

### Step 6: Runtime Failure Happens

The scenario runner sends POST requests to:

```text
http://localhost:8002/pay
```

Because production is configured with:

```text
FAILURE_MODE=pay_error
```

the `/pay` endpoint returns failures.

Inside `service.py`, this increments:

```text
payment_service_errors_total
payment_service_requests_total
```

### Step 7: Prometheus Scrapes Metrics

Prometheus scrapes:

```text
payment-production:8000/metrics
```

It stores the new request/error samples internally.

The data is not written to a repo file by default. It is stored inside Prometheus and can be queried through the Prometheus HTTP API.

### Step 8: CicdEnvironment Polls Prometheus

The Java environment periodically queries Prometheus.

It asks for values like:

```text
production error rate
production latency p95
production availability
```

Prometheus returns JSON.

The environment reads the numeric values and compares them to thresholds.

### Step 9: Telemetry Becomes BDI Percepts

If the error rate is high, the environment adds:

```text
metric(production, error_rate, high)
environment(production, unstable)
```

It also removes stale alternatives, such as:

```text
metric(production, error_rate, normal)
environment(production, stable)
```

This matters because the agent should reason over the latest state, not old state.

### Step 10: Agent Plan Becomes Applicable

The agent has a reactive plan for:

```text
environment(production, unstable)
```

Because production was deployed and monitoring is enabled, the plan becomes applicable.

The selected recovery goal is:

```text
recover_production(telemetry_unstable)
```

### Step 11: Agent Executes Rollback

The recovery plan calls:

```text
rollback(production)
```

This is a Jason external action.

`CicdEnvironment` receives it and calls:

```text
cicd/actions/rollback.sh production
```

### Step 12: Rollback Changes Docker State

The rollback script:

1. Sets production version to `stable`.
2. Recreates the `payment-production` container.
3. Starts Prometheus if needed.
4. Writes runtime state files under `runtime/state/`.

Important runtime state file:

```text
runtime/state/production_version.txt
```

After rollback, it should contain:

```text
stable
```

### Step 13: New Percepts Are Added

If rollback succeeds, the environment adds:

```text
status(rollback(production), passed)
environment(production, stable)
```

The agent records:

```text
decision(rollback_production)
```

### Step 14: Evidence Is Written

Evidence appears in:

```text
bdi/logs/cicd_environment.log
experiments/bdi_scenario_results/production_high_error_rate/result.json
experiments/bdi_scenario_results/production_high_error_rate/summary.md
```

Expected log lines include:

```text
[CicdEnvironment][telemetry] production error_rate=1.0000(high) ... environment=unstable
[CicdEnvironment][decision] recovery_reason reason=telemetry_unstable
[CicdEnvironment] action ... cicd\actions\rollback.sh production
[CicdEnvironment] percept status(rollback(production), passed)
[CicdEnvironment][decision] rollback_production
```

## 12. Which Files Are Actually Necessary?

For the `production_high_error_rate` scenario, the necessary files are:

### BDI Runtime

```text
bdi/project.mas2j
bdi/deployment_agent.asl
bdi/src/env/CicdEnvironment.java
bdi/build.gradle
```

### CI/CD Action Interface

```text
cicd/actions/build.sh
cicd/actions/test.sh
cicd/actions/security_scan.sh
cicd/actions/deploy.sh
cicd/actions/health_check.sh
cicd/actions/rollback.sh
```

### Application And Runtime

```text
app/payment_service/service.py
app/payment_service/Dockerfile
app/payment_service/requirements.txt
docker-compose.yml
runtime/prometheus/prometheus.yml
telemetry/thresholds.yml
```

### Scenario Execution

```text
experiments/bdi_scenario_catalog.json
experiments/run_bdi_scenario_suite.ps1
```

### Evidence Outputs

These are generated when the scenario runs:

```text
bdi/logs/cicd_environment.log
runtime/state/
experiments/bdi_scenario_results/
```

## 13. What Happens If You Run Components Separately?

### Run Docker Compose Only

Command:

```powershell
docker compose up --build
```

What happens:

```text
payment-staging starts on localhost:8001
payment-production starts on localhost:8002
prometheus starts on localhost:9090
Prometheus begins scraping /metrics
No BDI decisions happen
```

### Run Jason Only

Command:

```powershell
cd bdi
jason project.mas2j
```

What happens:

```text
deployment_agent starts
CicdEnvironment starts
agent begins deliver_release(candidate)
agent invokes shell actions
Docker services may be created by deploy.sh
telemetry polling starts
```

### Run Prometheus Adapter Only

Command:

```powershell
py telemetry/prometheus_adapter.py production --pretty
```

What happens:

```text
Python queries Prometheus once
Python prints JSON telemetry
No Jason belief is updated
No BDI decision happens
```

### Run Legacy Belief Mapper

Command:

```powershell
py telemetry/belief_mapper.py telemetry/live_production.json
```

What happens:

```text
Python converts a telemetry JSON file into generated .asl beliefs
This belongs to the legacy static scenario path
It does not update the running deployment_agent belief base
```

## 14. Final Mental Model

The easiest way to understand the project is:

```text
Docker runs the service.
The service exposes metrics.
Prometheus stores metrics.
Jason runs from the beginning.
CicdEnvironment connects Jason to the outside world.
Shell scripts change the CI/CD system.
Prometheus polling changes Jason beliefs.
AgentSpeak plans react to those beliefs.
The chosen plan calls another shell action.
The system state changes again.
```

That loop is the research prototype:

```text
perceive -> believe -> plan -> act -> observe new state
```
