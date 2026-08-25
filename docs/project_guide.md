# BDI CI/CD Project Guide

This is the single high-level guide for the current project state.

It explains what the project is about, how it developed, what is currently implemented, how the architecture works, and which experiments should be demonstrated.

## 1. Topic And Requirements

### Topic

This project is a research prototype for autonomous CI/CD using a Jason BDI agent.

The main research question is:

```text
Can a BDI controller make CI/CD decisions more explainable and adaptive than a fixed traditional pipeline?
```

The system simulates a payment service deployment. A traditional pipeline would usually run build, test, security scan, deploy, and health check in a fixed order. The BDI version uses beliefs, goals, and plans to decide whether to continue delivery, pause and reobserve, rollback, defer delivery, or mark the candidate as failed.

### Main Requirement

The BDI controller should pursue this objective:

```text
Deliver the candidate successfully while preserving production reliability.
```

That means the agent must distinguish:

```text
candidate delivered successfully
candidate delivery failed
candidate delivery deferred
production reliability restored
```

Rollback is not counted as delivery success. Rollback is a safety/recovery action that may restore production reliability, while the candidate may still be failed or deferred.

### Expected Research Contribution

The prototype should show that a BDI agent can:

```text
1. Invoke real CI/CD actions.
2. Perceive action results as beliefs.
3. Perceive Prometheus telemetry as changing beliefs.
4. Select different plans depending on current context.
5. Explain why it chose release, rollback, pause, defer, fail, or retry.
6. Continue pursuing candidate delivery when recovery is reasonable.
7. Use rollback only when production safety requires it.
```

## 2. Big Development Phases

### Phase 1: Traditional Pipeline

Purpose:

```text
Build a normal CI/CD baseline.
```

The traditional side uses shell scripts under:

```text
cicd/actions/
```

These scripts are the public CI/CD action interface:

```text
build.sh
test.sh
security_scan.sh
deploy.sh
health_check.sh
rollback.sh
```

This phase proves the local service can be built, tested, deployed, checked, and rolled back with normal scripts.

### Phase 2: Framework With BDI

Purpose:

```text
Introduce Jason as the decision controller.
```

The Jason project is:

```text
bdi/project.mas2j
```

The main agent is:

```text
bdi/deployment_agent.asl
```

The first version was mostly a hierarchical CI/CD sequence expressed in AgentSpeak. It proved that Jason could execute visible goals and subgoals, but it was still close to a procedural pipeline.

### Phase 3: Plain Jason Environment Bridge

Purpose:

```text
Connect Jason actions to real shell actions.
```

The Java bridge is:

```text
bdi/src/env/CicdEnvironment.java
```

Jason actions such as:

```text
build(candidate)
deploy(candidate, production)
rollback(production)
```

are handled by Java and mapped to real shell scripts under:

```text
cicd/actions/
```

This phase is important because Bash/Python no longer decides the BDI outcome. Jason calls an action, Java executes the real script, and Java returns a percept such as:

```text
status(build, passed)
status(deploy(production), failed)
```

### Phase 4: Integrate Telemetry

Purpose:

```text
Make production telemetry become live Jason beliefs.
```

The payment service exposes Prometheus metrics at:

```text
/metrics
```

Prometheus scrapes the staging and production services. Then `CicdEnvironment.java` polls Prometheus and converts numeric values into symbolic BDI percepts:

```text
metric(production,error_rate,high)
metric(production,latency,normal)
metric(production,availability,high)
environment(production,stable)
```

This phase makes the agent reactive to the environment, not only to action exit codes.

### Phase 5: Closed Perception-Reasoning-Action Loop

Purpose:

```text
Prove that telemetry can change beliefs and trigger a Jason action.
```

The strongest example is:

```text
production /health passes
-> candidate enters canary observation
-> controlled real /pay traffic is generated
-> FORCE_ERROR_RATE makes some requests fail probabilistically
-> Prometheus measures a high error rate
-> Jason perceives production unstable
-> Jason rolls back
-> Jason marks production reliability restored
-> Jason marks candidate delivery failed
```

This demonstrates:

```text
perceive -> reason -> act -> perceive again
```

### Phase 6: Scenario Expansion

Purpose:

```text
Show different BDI capabilities.
```

Scenario categories include:

```text
successful delivery
telemetry-driven production failure
high latency
observability failure
transient health failure and retry
build/test/security gate failures
rollback unavailable
```

The current active manual demos are focused, not a huge scenario suite:

```text
experiments/demo_successful_path.md
experiments/demo_failed_telemetry_path.md
experiments/manual_demo_pipeline.md
```

Older broader scenario-suite work is under:

```text
experiments/archive/
```

### Phase 7: Traditional Vs BDI Comparison

Purpose:

```text
Compare a fixed pipeline with the BDI controller.
```

The intended comparison is:

```text
traditional pipeline:
  fixed action sequence
  usually accepts release after scripts and /health pass

BDI controller:
  action sequence plus beliefs
  observes telemetry
  can rollback, pause, defer, fail, or retry based on context
```

Current status: older comparison artifacts exist in `experiments/archive/`. The current recommended supervisor demonstration is the manual successful path plus telemetry-driven failure path.

### Phase 8: Strengthen BDI Model Presentation

Purpose:

```text
Explain the architecture clearly and avoid overclaiming.
```

This phase created beginner-oriented documentation, diagrams, and manual walkthroughs. The key correction was to distinguish:

```text
real Jason decisions
legacy modeled traces
telemetry-driven scenarios
controlled fault-injection scenarios
```

### Phase 9: Strengthen BDI Goal And Failure Handling

Purpose:

```text
Make the agent more clearly goal-directed.
```

The latest update added explicit outcome semantics:

```text
delivery_succeeded(candidate)
delivery_failed(candidate, Reason)
delivery_deferred(candidate, Reason)
production_reliability_restored
production_reliability_restored(Reason)
```

This makes the research claim stronger because rollback is no longer treated as delivery success.

The latest proof case:

```text
candidate reaches production
-> production /health passes
-> canary observation opens
-> 80 real POST /pay requests are sent
-> FORCE_ERROR_RATE=0.20 causes a measured error rate around 20 percent
-> Prometheus exposes the changed metric
-> CicdEnvironment maps it to environment(production,unstable)
-> Jason rolls back production
-> production_reliability_restored(telemetry_unstable)
-> delivery_failed(candidate,telemetry_unstable)
```

Another proof case:

```text
production health fails once
-> Jason rolls back
-> production reliability restored
-> Jason retries candidate delivery
-> delivery_succeeded(candidate)
```

## 3. Current State Of The Project

### Finished

The current project has:

```text
local payment service
Docker Compose staging and production
Prometheus scraping
CI/CD shell action interface
Jason MAS configuration
Jason deployment_agent
Java environment bridge
action-result percepts
Prometheus telemetry percepts
production canary observation window
explicit delivery outcome beliefs
rollback/retry path for recoverable production health failure
telemetry-driven rollback path using real generated traffic and Prometheus metrics
outcome guards so delayed canary completion cannot overwrite a failed/deferred delivery as success
manual successful-path guide
manual telemetry-failure guide
overall manual demo pipeline
```

### Recently Verified

A goal-persistence test was run successfully with Docker Desktop:

```text
goal_persistence_test=True
[CicdEnvironment][decision] production_reliability_restored reason=health_failed
[CicdEnvironment][decision] rollback_then_retry_production reason=health_failed
[CicdEnvironment][decision] continue_deploy_candidate reason=health_failed
[CicdEnvironment][decision] delivery_succeeded reason=candidate
```

This proves the agent can restore reliability and continue pursuing the original candidate delivery goal.

A telemetry-driven failure test was also run successfully:

```text
PAYMENT_PRODUCTION_FAILURE_MODE=none
PAYMENT_PRODUCTION_FORCE_ERROR_RATE=0.20
80 real POST /pay requests during canary
[CicdEnvironment][telemetry] production error_rate=0.2222(high) ... environment=unstable
[CicdEnvironment][decision] recovery_reason reason=telemetry_unstable
[CicdEnvironment][decision] production_reliability_restored reason=telemetry_unstable
[CicdEnvironment][decision] delivery_failed reason=telemetry_unstable
runtime/state/production_version.txt = stable
```

This proves the current failure demo is telemetry-driven: traffic changes service metrics, Prometheus observes the metrics, Java converts them to BDI percepts, and Jason chooses rollback/failure handling.

### Still Remaining

The project is not production-ready. Remaining work includes:

```text
true midway fault injection for build/test/security without restarting Jason
full cancellation of obsolete intentions, beyond the current outcome guards
more systematic traditional-vs-BDI comparison using the newest outcome semantics
better persistent experiment result storage
possible JaCaMo/CArtAgO migration later, if the research needs artifacts/environments
more polished supervisor-facing report
```

## 4. Architecture

## 4.1 Component Overview

```text
User / demo script
        |
        v
Jason MAS
        |
        v
deployment_agent.asl
        |
        v
CicdEnvironment.java
        |
        +--> cicd/actions/*.sh
        |       |
        |       v
        |   Docker Compose
        |       |
        |       v
        |   payment-staging / payment-production
        |
        +--> Prometheus HTTP API
                |
                v
            telemetry percepts
```

## 4.2 Important Folders And Files

```text
app/payment_service/service.py
  Flask payment service, endpoints, failure modes, metrics.

docker-compose.yml
  Runs payment-staging, payment-production, and Prometheus.

cicd/actions/*.sh
  Public CI/CD shell action interface.

runtime/prometheus/prometheus.yml
  Prometheus scrape configuration.

telemetry/thresholds.yml
  Numeric thresholds for symbolic telemetry classification.

bdi/project.mas2j
  Jason MAS file. Registers deployment_agent and CicdEnvironment.

bdi/deployment_agent.asl
  Main BDI controller.

bdi/src/env/CicdEnvironment.java
  Java bridge between Jason and the local CI/CD environment.

bdi/logs/cicd_environment.log
  Main evidence log.

experiments/manual_demo_pipeline.md
  Overall manual demo workflow.

experiments/demo_successful_path.md
experiments/demo_successful_path.ps1
  Successful delivery demo.

experiments/demo_failed_telemetry_path.md
experiments/demo_failed_telemetry_path.ps1
  Telemetry-driven rollback/failure demo.
```

## 5. App Details

The app is:

```text
app/payment_service/service.py
```

It exposes:

```text
GET  /health
POST /pay
POST /refund
GET  /metrics
```

Important note:

```text
/pay and /refund are POST endpoints.
Opening them in a browser with GET shows Method Not Allowed.
That is normal.
```

## 5.1 App Environment Variables

The project uses environment variables in three different places. This is the part that is easy to confuse.

```text
PowerShell variable on your machine
        |
        v
Docker Compose variable substitution
        |
        v
Container variable read by service.py
```

Example:

```powershell
$env:PAYMENT_PRODUCTION_FAILURE_MODE="none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE="0.20"
```

These variables are not read directly by Flask from your Windows terminal. Docker Compose reads them and passes them into the production container using the names that `service.py` expects.

In `docker-compose.yml`:

```yaml
FAILURE_MODE: ${PAYMENT_PRODUCTION_FAILURE_MODE:-none}
FORCE_ERROR_RATE: ${PAYMENT_PRODUCTION_FORCE_ERROR_RATE:-0}
```

Then `app/payment_service/service.py` reads the inside-container names:

```python
FAILURE_MODE = os.getenv("FAILURE_MODE", "none").strip().lower()
FORCE_ERROR_RATE = float(os.getenv("FORCE_ERROR_RATE", "0") or 0)
```

So the complete path is:

```text
PAYMENT_PRODUCTION_FAILURE_MODE
-> Docker Compose
-> FAILURE_MODE inside payment-production container
-> service.py chooses deterministic failure behavior

PAYMENT_PRODUCTION_FORCE_ERROR_RATE
-> Docker Compose
-> FORCE_ERROR_RATE inside payment-production container
-> service.py chooses probabilistic failure behavior
```

The app itself reads these variables inside the container:

| Variable | Values | Meaning | Result |
| --- | --- | --- | --- |
| `SERVICE_VERSION` | `stable`, `candidate` | Labels the running version. | Response JSON and metrics include the version. |
| `FAILURE_MODE` | `none` | Normal behavior. | `/health`, `/pay`, `/refund` succeed unless random error is configured. |
| `FAILURE_MODE` | `pay_error` | Fail `/pay`. | POST `/pay` returns 500 and increments error metrics. |
| `FAILURE_MODE` | `refund_error` | Fail `/refund`. | POST `/refund` returns 500 and increments error metrics. |
| `FAILURE_MODE` | `always_error`, `error`, `fail` | Fail all business operations. | `/pay` and `/refund` return 500. |
| `FAILURE_MODE` | `unhealthy`, `down` | Health failure mode. | `/health` returns 503 and health gauge becomes 0. |
| `FORCE_ERROR_RATE` | `0.0` to `1.0` | Random failure probability. | Example: `0.5` means roughly half business requests fail. |
| `EXTRA_LATENCY_MS` | integer ms | Adds latency to requests. | Can make latency telemetry high. |
| `ENABLE_OTEL` | `true`, `false` | Optional OpenTelemetry console spans. | Not central to the current BDI demo. |
| `PORT` | integer | Internal service port. | Docker uses `8000` inside containers. |

Docker Compose maps scenario variables into app variables:

| Compose variable | Container variable |
| --- | --- |
| `PAYMENT_STAGING_VERSION` | `SERVICE_VERSION` |
| `PAYMENT_STAGING_FAILURE_MODE` | `FAILURE_MODE` |
| `PAYMENT_STAGING_FORCE_ERROR_RATE` | `FORCE_ERROR_RATE` |
| `PAYMENT_STAGING_EXTRA_LATENCY_MS` | `EXTRA_LATENCY_MS` |
| `PAYMENT_PRODUCTION_VERSION` | `SERVICE_VERSION` |
| `PAYMENT_PRODUCTION_FAILURE_MODE` | `FAILURE_MODE` |
| `PAYMENT_PRODUCTION_FORCE_ERROR_RATE` | `FORCE_ERROR_RATE` |
| `PAYMENT_PRODUCTION_EXTRA_LATENCY_MS` | `EXTRA_LATENCY_MS` |

Ports:

```text
staging    http://localhost:8001
production http://localhost:8002
prometheus http://localhost:9090
```

## 5.2 Where The Variables Are Defined, Read, And Used

### Outside Docker: Variables You Set In PowerShell

You set these before starting Jason or before manually redeploying a service:

```powershell
$env:PAYMENT_PRODUCTION_FAILURE_MODE="none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE="0.20"
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS="800"
```

They live only in the current PowerShell process environment until you remove them or close the terminal.

They are not stored permanently in the repo.

Cleanup commands remove them from the current terminal:

```powershell
Remove-Item Env:\PAYMENT_PRODUCTION_FAILURE_MODE -ErrorAction SilentlyContinue
```

### Docker Compose: Mapping Layer

File:

```text
docker-compose.yml
```

Staging mapping:

```yaml
SERVICE_VERSION: ${PAYMENT_STAGING_VERSION:-candidate}
FAILURE_MODE: ${PAYMENT_STAGING_FAILURE_MODE:-none}
FORCE_ERROR_RATE: ${PAYMENT_STAGING_FORCE_ERROR_RATE:-0}
EXTRA_LATENCY_MS: ${PAYMENT_STAGING_EXTRA_LATENCY_MS:-0}
```

Production mapping:

```yaml
SERVICE_VERSION: ${PAYMENT_PRODUCTION_VERSION:-stable}
FAILURE_MODE: ${PAYMENT_PRODUCTION_FAILURE_MODE:-none}
FORCE_ERROR_RATE: ${PAYMENT_PRODUCTION_FORCE_ERROR_RATE:-0}
EXTRA_LATENCY_MS: ${PAYMENT_PRODUCTION_EXTRA_LATENCY_MS:-0}
```

The `:-none` or `:-0` part means:

```text
if the outside variable is not set, use this default value
```

Example:

```text
PAYMENT_PRODUCTION_FAILURE_MODE is missing
-> Docker Compose gives FAILURE_MODE=none to the container
```

### Inside The App Container: service.py Reads Values

File:

```text
app/payment_service/service.py
```

Startup reads:

```python
SERVICE_VERSION = os.getenv("SERVICE_VERSION", "stable").strip().lower()
FAILURE_MODE = os.getenv("FAILURE_MODE", "none").strip().lower()
FORCE_ERROR_RATE = float(os.getenv("FORCE_ERROR_RATE", "0") or 0)
EXTRA_LATENCY_MS = int(os.getenv("EXTRA_LATENCY_MS", "0") or 0)
ENABLE_OTEL = os.getenv("ENABLE_OTEL", "false").strip().lower() == "true"
```

These values are read when the container process starts. If you change a PowerShell variable after the container is already running, the running Flask process does not automatically change. You need to redeploy/recreate the container through `deploy.sh`, `rollback.sh`, or `docker compose up`.

## 5.3 How The Current Telemetry Demo Creates Failure

Setting a variable does not create traffic.

The current main failed-path demo uses these values:

```powershell
$env:PAYMENT_PRODUCTION_FAILURE_MODE="none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE="0.20"
```

This means:

```text
when production is next deployed/recreated,
the production container will start with:
  FAILURE_MODE=none
  FORCE_ERROR_RATE=0.20
```

Nothing happens to metrics yet.

Metrics change only when something calls the app.

For the latest telemetry-driven failure demo, the full runtime sequence is:

```text
1. You set PAYMENT_PRODUCTION_FAILURE_MODE=none.
2. You set PAYMENT_PRODUCTION_FORCE_ERROR_RATE=0.20.
3. Jason calls deploy(candidate, production), or you manually redeploy production.
4. deploy.sh exports PAYMENT_PRODUCTION_FAILURE_MODE and PAYMENT_PRODUCTION_FORCE_ERROR_RATE.
5. docker-compose.yml maps them to FAILURE_MODE and FORCE_ERROR_RATE inside the container.
6. service.py starts with FAILURE_MODE=none and FORCE_ERROR_RATE=0.20.
7. Production /health still returns 200 OK because the service is alive.
8. You or the demo script sends real POST /pay traffic during canary.
9. service.py runs should_fail("pay") for each request.
10. should_fail does not match a deterministic failure mode.
11. should_fail evaluates random.random() < FORCE_ERROR_RATE.
12. Some /pay requests return HTTP 200 and some return HTTP 500.
13. service.py increments request metrics for all requests and error metrics only for failed requests.
14. GET /metrics exposes the updated counters.
15. Prometheus scrapes /metrics on its next scrape.
16. CicdEnvironment queries Prometheus.
17. Java sees measured error_rate > threshold.
18. Java updates Jason percepts:
    metric(production,error_rate,high)
    environment(production,unstable)
19. Jason selects the applicable recovery/failure plan.
20. Jason calls rollback(production).
21. CicdEnvironment executes cicd/actions/rollback.sh production.
22. Jason records production_reliability_restored(telemetry_unstable).
23. Jason records delivery_failed(candidate,telemetry_unstable).
```

Because this path is probabilistic, `0.20` does not guarantee exactly 20 failed requests out of 100. It means each request has about a 20 percent chance of failure, so the measured Prometheus error rate should be near that value when enough traffic is sent.

The key function is `should_fail` in `service.py`:

```python
def should_fail(operation: str) -> bool:
    if FAILURE_MODE in {"always_error", "error", "fail"}:
        return True
    if FAILURE_MODE == f"{operation}_error":
        return True
    return random.random() < FORCE_ERROR_RATE
```

For `/pay`, `operation` is:

```text
pay
```

So:

```text
FAILURE_MODE == "pay_error"
```

matches:

```python
FAILURE_MODE == f"{operation}_error"
```

and the app returns failure for `/pay`. In the current main demo, `FAILURE_MODE` is `none`, so this deterministic branch does not run. The code falls through to:

```text
random.random() < FORCE_ERROR_RATE
```

With `FORCE_ERROR_RATE=0.20`, each real `/pay` or `/refund` request has about a 20 percent chance of returning HTTP 500.

This is still not automatic traffic generation. You or a demo script must send requests during the production canary window. The variable only controls how likely each request is to fail once it reaches `service.py`.

### Optional Deterministic Failure Mode

`pay_error` still exists, but it is not the current main telemetry demo.

Use it only when you want every `/pay` request to fail:

```powershell
$env:PAYMENT_PRODUCTION_FAILURE_MODE="pay_error"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE="0"
```

That path is:

```text
real POST /pay request
-> service.py runs should_fail("pay")
-> should_fail sees FAILURE_MODE == "pay_error"
-> /pay returns HTTP 500 every time
-> metrics show an error rate near 1.00
-> Prometheus scrapes it
-> CicdEnvironment maps it to metric(production,error_rate,high)
-> Jason reacts
```

This deterministic mode is useful for control testing, but it is less realistic than the current probabilistic telemetry demo.

## 5.4 What Happens To Metrics

Metrics are not separate files. They are in memory inside the running Flask process and exposed at:

```text
GET /metrics
```

When a request happens, `service.py` calls `record(...)`:

```python
REQUEST_COUNT.labels(...).inc()
REQUEST_LATENCY.labels(...).observe(...)
if status >= 500:
    ERROR_COUNT.labels(...).inc()
```

That means:

```text
successful POST /pay
-> request counter increases
-> latency histogram records duration
-> error counter does not increase

failed POST /pay
-> request counter increases
-> latency histogram records duration
-> error counter increases
```

Then Prometheus periodically scrapes `/metrics`.

Prometheus stores the sampled metric values inside the Prometheus container. The repo does not store each metric sample as a normal text file.

CicdEnvironment asks Prometheus questions such as:

```text
What is the production error rate for /pay and /refund?
What is the production p95 latency?
What is production availability?
```

Then Java converts the numeric answers into BDI beliefs.

## 5.5 Why Some Variables Are Different In The Docs

They belong to different layers:

| Layer | Example variables | Read by | Purpose |
| --- | --- | --- | --- |
| PowerShell / demo setup | `PAYMENT_PRODUCTION_FAILURE_MODE` | Docker Compose and shell scripts | Configure staging/production before container starts. |
| Container app | `FAILURE_MODE` | `service.py` | Actually changes Flask behavior. |
| Java BDI environment | `BDI_TELEMETRY_INTERVAL_SECONDS` | `CicdEnvironment.java` | Controls telemetry polling. |
| Java BDI forced action tests | `BDI_FORCE_BUILD_FAIL` | `CicdEnvironment.java` | Forces action-result percepts for testing. |

So this pair is not contradictory:

```text
PAYMENT_PRODUCTION_FAILURE_MODE
FAILURE_MODE
```

It means:

```text
outside Docker name -> inside container name
```

## 5.6 BDI Variables Are Separate From App Variables

These are read by:

```text
bdi/src/env/CicdEnvironment.java
```

They do not change Flask directly.

| Variable | File that reads it | Meaning |
| --- | --- | --- |
| `BDI_TELEMETRY_ENABLED` | `CicdEnvironment.java` | Turns Prometheus polling on/off. |
| `BDI_TELEMETRY_INTERVAL_SECONDS` | `CicdEnvironment.java` | How often Java polls Prometheus. |
| `BDI_TELEMETRY_GRACE_SECONDS` | `CicdEnvironment.java` | Temporarily skips production telemetry after deploy/rollback. |
| `BDI_OBSERVE_PRODUCTION_CANARY_MS` | `CicdEnvironment.java` | Duration of `observe(production, canary)`. |
| `BDI_FORCE_BUILD_FAIL` | `CicdEnvironment.java` | Force `build(candidate)` to produce `status(build,failed)`. |
| `BDI_FORCE_TEST_FAIL` | `CicdEnvironment.java` | Force `test(candidate)` to produce `status(test,failed)`. |
| `BDI_FORCE_SECURITY_SCAN_FAIL` | `CicdEnvironment.java` | Force `security_scan(candidate)` to produce `status(security_scan,failed)`. |
| `BDI_FORCE_HEALTH_CHECK_PRODUCTION_FAIL_ONCE` | `CicdEnvironment.java` | Force the first `health_check(production)` to fail, then allow later checks to run normally. |

The force-failure variables are checked before Java runs a shell script:

```java
if (truthy(System.getenv("BDI_FORCE_" + envStage + "_FAIL"))) {
    return true;
}
if (truthy(System.getenv("BDI_FORCE_" + envStage + "_FAIL_ONCE"))) {
    return oneShotForcedFailuresUsed.add(envStage);
}
```

These variables are useful for control-flow testing, but they are not the same as telemetry-driven environment failure.

Telemetry-driven failure:

```text
app behavior changes
-> request happens
-> metrics change
-> Prometheus scrapes
-> Java converts telemetry
-> Jason reacts
```

Forced action failure:

```text
Jason calls action
-> Java sees BDI_FORCE_* variable
-> Java returns failed percept
-> Jason reacts
```

## 6. Telemetry

## 6.1 Metrics Defined

The payment service exports four main Prometheus metrics:

| Metric | Type | Meaning |
| --- | --- | --- |
| `payment_service_requests_total` | Counter | Number of HTTP requests, labeled by version, method, endpoint, status. |
| `payment_service_errors_total` | Counter | Number of failed business requests, labeled by version and endpoint. |
| `payment_service_request_latency_seconds` | Histogram | Request latency, used for p95 latency. |
| `payment_service_health` | Gauge | `1` means healthy, `0` means unhealthy. |

## 6.2 How Telemetry Moves

```text
payment service handles request
        |
        v
service.py updates Prometheus metric object
        |
        v
GET /metrics exposes current metric text
        |
        v
Prometheus scrapes /metrics every 5 seconds
        |
        v
CicdEnvironment.java queries Prometheus HTTP API
        |
        v
Java converts numeric metrics into symbolic percepts
        |
        v
Jason belief base updates
```

Prometheus stores samples inside the Prometheus container. The repo does not store every scrape as a normal project file.

The most important live storage is the Jason belief base and the evidence log:

```text
bdi/logs/cicd_environment.log
```

## 6.3 Telemetry Semantics

Thresholds are:

```text
telemetry/thresholds.yml
```

Current rules:

| Telemetry | Threshold | Symbolic belief |
| --- | --- | --- |
| error rate `> 0.05` | bad | `metric(production,error_rate,high)` |
| error rate `<= 0.05` | normal | `metric(production,error_rate,normal)` |
| p95 latency `> 500 ms` | bad | `metric(production,latency,high)` |
| p95 latency `<= 500 ms` | normal | `metric(production,latency,normal)` |
| availability `< 0.99` | bad | `metric(production,availability,low)` |
| availability `>= 0.99` | normal | `metric(production,availability,high)` |

Overall environment belief:

```text
bad metric exists -> environment(production,unstable)
all metrics normal -> environment(production,stable)
Prometheus query fails -> telemetry(production,unavailable)
                          network(production,suspected)
                          environment(production,unstable)
```

## 7. BDI Model

## 7.1 BDI Architecture

The current BDI model has one main agent:

```text
deployment_agent
```

It lives in:

```text
bdi/deployment_agent.asl
```

It is started by:

```text
bdi/project.mas2j
```

The agent's root goal is:

```text
!deliver_release(candidate)
```

Conceptually, the objective is:

```text
deliver candidate successfully while preserving production reliability
```

## 7.2 Goal Hierarchy

```text
!deliver_release(candidate)
|
|-- !prepare_candidate(candidate)
|   `-- build(candidate)
|
|-- !validate_candidate(candidate)
|   |-- test(candidate)
|   `-- security_scan(candidate)
|
|-- !deploy_to_staging(candidate)
|
|-- !verify_staging
|
|-- !deploy_to_production(candidate)
|
|-- !verify_production
|
|-- !observe_production_canary
|
`-- !maintain_reliability
```

## 7.3 Important Beliefs

Action-result beliefs:

```text
status(build,passed)
status(test,passed)
status(security_scan,passed)
status(deploy(staging),passed)
status(deploy(production),passed)
status(health_check(production),passed)
status(rollback(production),passed)
```

Telemetry beliefs:

```text
metric(production,error_rate,high)
metric(production,latency,high)
metric(production,availability,low)
environment(production,unstable)
```

Outcome beliefs:

```text
delivery_succeeded(candidate)
delivery_failed(candidate, Reason)
delivery_deferred(candidate, Reason)
production_reliability_restored
production_reliability_restored(Reason)
```

Decision marker beliefs:

```text
decision(delivery_succeeded)
decision(delivery_failed)
decision(delivery_deferred)
decision(rollback_production)
decision(pause_reobserve)
decision(manual_intervention_required)
```

## 7.4 BDI Mechanisms

The agent demonstrates:

```text
beliefs
achievement goals
hierarchical subgoals
context-sensitive plans
dynamic telemetry percepts
reactive plans for production instability
pause/reobserve behaviour
rollback and retry for a recoverable production health problem
explicit outcome semantics
```

The model is still intentionally small. It does not use an LLM planner or machine learning.

## 8. Java Environment

The Java environment is:

```text
bdi/src/env/CicdEnvironment.java
```

It has two responsibilities.

### 8.1 Jason Action To Real CI/CD Action

```text
Jason action
-> Java executeAction
-> shell script
-> Docker/app/Prometheus effect
-> exit code
-> Jason percept
```

Examples:

| Jason action | Shell/action result |
| --- | --- |
| `build(candidate)` | runs `cicd/actions/build.sh candidate` |
| `test(candidate)` | runs `cicd/actions/test.sh candidate` |
| `security_scan(candidate)` | runs `cicd/actions/security_scan.sh candidate` |
| `deploy(candidate, staging)` | runs `cicd/actions/deploy.sh staging candidate` |
| `deploy(candidate, production)` | runs `cicd/actions/deploy.sh production candidate` |
| `health_check(production)` | runs `cicd/actions/health_check.sh production` |
| `rollback(production)` | runs `cicd/actions/rollback.sh production` |
| `observe(production, canary)` | waits for a canary observation window while telemetry polling continues |

### 8.2 Real Telemetry To Jason Beliefs

```text
Java poller
-> Prometheus query
-> numeric telemetry
-> threshold classification
-> remove stale percept
-> add current percept
```

Important timing variables:

| Variable | Meaning |
| --- | --- |
| `BDI_TELEMETRY_ENABLED` | Turns telemetry polling on/off. |
| `BDI_TELEMETRY_INTERVAL_SECONDS` | How often Java polls Prometheus. |
| `BDI_TELEMETRY_GRACE_SECONDS` | Quiet period after production deploy/rollback. |
| `BDI_OBSERVE_PRODUCTION_CANARY_MS` | How long Jason waits in production canary observation. |

## 9. Logs

Main evidence log:

```text
bdi/logs/cicd_environment.log
```

This log contains:

```text
Java bridge startup
external actions requested by Jason
shell commands executed
script output
script exit code
percepts added to Jason
telemetry polling results
observation window start/end
recorded decisions from AgentSpeak
```

Important evidence examples:

```text
[CicdEnvironment] percept status(build, passed)
[CicdEnvironment][telemetry] production error_rate=0.xxxx(high) ... environment=unstable
[CicdEnvironment][observe] start environment=production phase=canary
[CicdEnvironment][decision] production_reliability_restored reason=health_failed
[CicdEnvironment][decision] delivery_succeeded reason=candidate
[CicdEnvironment][decision] delivery_failed reason=telemetry_unstable
```

You can also inspect Jason beliefs:

```powershell
cd bdi
jason agent mind deployment_agent
```

## 10. Experiments

## 10.1 Primary Demo 1: Successful Delivery

Guide:

```text
experiments/demo_successful_path.md
```

Automation:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\demo_successful_path.ps1
```

Description:

```text
All actions pass.
Production health passes.
Canary observation remains stable.
Jason records delivery_succeeded(candidate).
```

Expected result:

```text
delivery_succeeded(candidate)
decision(delivery_succeeded)
decision(release_complete)
production version = candidate
```

## 10.2 Primary Demo 2: Telemetry-Driven Failure

Guide:

```text
experiments/demo_failed_telemetry_path.md
```

Automation:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\demo_failed_telemetry_path.ps1
```

Description:

```text
Candidate reaches production.
/health passes.
Jason enters canary observation.
POST /pay traffic is generated while FORCE_ERROR_RATE makes some real requests fail.
Prometheus error rate becomes high.
Jason rolls back production.
Jason records candidate delivery failed.
```

Expected result:

```text
metric(production,error_rate,high)
environment(production,unstable)
production_reliability_restored
delivery_failed(candidate,telemetry_unstable)
production version = stable
```

Depending on timing, the failure reason can also be `candidate_unsafe` if the canary handler sees the high error-rate belief first. In both cases, the trigger is the same measured Prometheus telemetry.

## 10.3 Goal Persistence Demo: Recoverable Production Health Failure

Description:

```text
Production health fails once.
Jason rolls back to restore reliability.
Jason verifies production is stable.
Jason retries candidate deployment.
Jason records delivery_succeeded(candidate).
```

Expected result:

```text
production_reliability_restored(health_failed)
decision(rollback_then_retry_production)
decision(continue_deploy_candidate)
delivery_succeeded(candidate)
production version = candidate
```

This is the best scenario for proving that the agent still tries to achieve the candidate delivery goal after a recoverable failure.

## 10.4 High Latency Demo

Description:

```text
Candidate reaches production.
Traffic has high latency but not high error rate.
Jason treats this as ambiguous.
Jason chooses pause_reobserve instead of immediate rollback.
```

Expected result:

```text
metric(production,latency,high)
decision(pause_reobserve)
reobserve_reason(high_latency)
```

This proves the agent does not blindly rollback every telemetry problem.

## 10.5 Observability Failure Demo

Description:

```text
Candidate reaches production.
Prometheus becomes unavailable during canary.
Jason cannot trust telemetry.
Jason pauses/reobserves and may escalate to manual intervention.
```

Expected result:

```text
telemetry(production,unavailable)
network(production,suspected)
decision(pause_reobserve)
decision(manual_intervention_required)
delivery_deferred(candidate, network_suspected)
```

This proves the agent can distinguish application failure from observability failure.

## 10.6 Gate Failure Demos

Examples:

```text
build failure
test failure
security scan failure
staging health failure
rollback unavailable
```

These mostly use controlled action-result fault injection such as:

```text
BDI_FORCE_BUILD_FAIL
BDI_FORCE_TEST_FAIL
BDI_FORCE_SECURITY_SCAN_FAIL
BDI_FORCE_HEALTH_CHECK_PRODUCTION_FAIL_ONCE
```

Expected results:

```text
delivery_failed(candidate, build_failed)
delivery_failed(candidate, test_failed)
delivery_failed(candidate, security_failed)
delivery_deferred(candidate, staging_unstable)
manual_intervention_required when rollback fails
```

Important limitation:

```text
These are useful control-flow tests.
They are not the strongest proof of live telemetry perception.
```

## 11. What To Say In A Presentation

A concise explanation:

```text
This project starts with a normal CI/CD action interface.
Then Jason becomes the controller.
The Java environment lets Jason execute real shell actions.
Prometheus telemetry becomes Jason beliefs.
The agent has a root goal to deliver the candidate while preserving production reliability.
It can now distinguish delivery success, delivery failure, delivery deferral, and production reliability restoration.
The strongest demo is when /health passes but real /pay traffic produces a measured high error rate during canary, causing Jason to rollback, restore production reliability, and mark candidate delivery failed.
The goal-persistence demo shows that rollback is not always final: if the problem is recoverable, Jason restores reliability and retries candidate delivery.
```
