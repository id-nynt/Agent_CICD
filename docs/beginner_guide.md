# Beginner Guide: BDI CI/CD Prototype

This guide explains the project from a high level first, then gradually moves into the details. It is written for a reader who is new to CI/CD, BDI agents, Jason, and Prometheus.

## 1. What Is This Project About?

This project is a research prototype about making CI/CD decisions more intelligent and explainable.

A normal CI/CD pipeline usually follows fixed steps:

```text
build -> test -> scan -> deploy -> health check
```

If every step passes, the pipeline usually says the release is successful. But in real systems, a release can pass a simple health check while still having problems. For example:

```text
/health returns OK
but /pay is failing for real users
```

This project explores whether a BDI agent can do better.

BDI means:

```text
Beliefs -> Desires -> Intentions
```

In this project:

- Beliefs are facts the agent knows, such as "production error rate is high".
- Desires are goals, such as "deliver the release safely".
- Intentions are selected plans, such as "rollback production" or "pause and reobserve".

The research question is:

```text
Can a BDI agent make CI/CD release decisions more context-aware and explainable than a fixed pipeline?
```

## 2. What Exists In The Codebase?

The project has several major parts.

| Part | Folder/File | What it does |
| --- | --- | --- |
| Demo application | `app/payment_service/` | A small fake payment service used to generate metrics. |
| CI/CD actions | `cicd/actions/` | Shell scripts for build, test, deploy, health check, rollback. |
| Docker runtime | `docker-compose.yml` | Runs staging, production, and Prometheus locally. |
| Prometheus config | `runtime/prometheus/prometheus.yml` | Tells Prometheus where to collect metrics. |
| BDI agent | `bdi/deployment_agent.asl` | The Jason AgentSpeak agent that makes decisions. |
| Jason environment bridge | `bdi/src/env/CicdEnvironment.java` | Connects Jason actions to shell scripts and telemetry. |
| Jason project config | `bdi/project.mas2j` | Starts the Jason agent and environment. |
| Scenario runner | `experiments/run_bdi_scenario_suite.ps1` | Runs BDI scenarios and records evidence. |
| Comparison runner | `experiments/run_traditional_vs_bdi_comparison.py` | Compares fixed pipeline vs BDI controller. |
| Documentation | `docs/` | Explains architecture, scenarios, and results. |

## 3. The Big Picture Architecture

Think of the system as four layers.

```text
Layer 1: Application
  Payment service runs in Docker and exposes /health, /pay, /refund, /metrics

Layer 2: CI/CD action scripts
  Shell scripts build, test, deploy, health check, and rollback the service

Layer 3: Monitoring
  Prometheus scrapes /metrics and stores runtime telemetry

Layer 4: BDI controller
  Jason agent reads action results and telemetry as beliefs, then chooses plans
```

The important idea is that the BDI agent does not replace the shell scripts.

Instead, it controls when to call them.

```text
BDI agent decides what should happen next
CI/CD scripts perform the actual work
Prometheus provides runtime evidence
```

## 4. What Is The Demo Application?

The demo app is a fake payment service.

It has these endpoints:

| Endpoint | Method | Meaning |
| --- | --- | --- |
| `/health` | GET | Returns whether the service is alive. |
| `/pay` | POST | Simulates a payment operation. |
| `/refund` | POST | Simulates a refund operation. |
| `/metrics` | GET | Exposes Prometheus metrics. |

If you open `/pay` in a browser, you may see `Method Not Allowed`. That is normal because browsers use GET, but `/pay` requires POST.

Use this instead:

```powershell
Invoke-RestMethod -Method POST -Uri http://localhost:8002/pay -ContentType "application/json" -Body '{"amount": 10}'
```

## 5. What Is The Traditional CI/CD Pipeline?

The traditional pipeline is a fixed sequence of shell scripts.

It runs:

```text
build candidate
test candidate
security scan candidate
deploy candidate to staging
health check staging
deploy candidate to production
health check production
```

Those scripts are in:

```text
cicd/actions/
```

Example:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' cicd/actions/build.sh candidate
```

The traditional pipeline is simple and predictable, but it has a limitation:

```text
After production health check passes, it does not keep reasoning about new telemetry.
```

So if `/health` passes but `/pay` starts failing, the traditional pipeline may still consider the release successful.

## 6. What Is The BDI Agent?

The active BDI agent is:

```text
bdi/deployment_agent.asl
```

It is written in AgentSpeak for Jason.

Its main goal is:

```text
deliver release candidate safely
```

It breaks that goal into smaller goals:

```text
prepare candidate
validate candidate
deploy to staging
verify staging
deploy to production
verify production
maintain reliability
```

The BDI agent can decide:

| Decision | Meaning |
| --- | --- |
| `release_complete` | The release looks safe. |
| `stop_pipeline` | Stop before production because a gate failed. |
| `rollback_production` | Restore the stable production version. |
| `pause_reobserve` | Wait and check again before acting. |
| `manual_intervention_required` | Human help is needed. |

## 7. What Is The Jason Environment Bridge?

Jason does not directly run shell scripts by itself.

The bridge file does that:

```text
bdi/src/env/CicdEnvironment.java
```

It translates between:

```text
Jason action
```

and:

```text
real shell script
```

Example:

| Jason action | Real script called |
| --- | --- |
| `build(candidate)` | `cicd/actions/build.sh candidate` |
| `deploy(candidate, production)` | `cicd/actions/deploy.sh production candidate` |
| `rollback(production)` | `cicd/actions/rollback.sh production` |

It also turns results into beliefs.

For example, if build succeeds:

```text
status(build, passed)
```

If production telemetry is bad:

```text
environment(production, unstable)
```

## 8. Where Does Telemetry Come From?

Telemetry starts inside the payment service.

The payment service records:

```text
request count
error count
latency
availability
```

Prometheus collects these metrics from:

```text
http://payment-production:8000/metrics
http://payment-staging:8000/metrics
```

The Jason environment bridge queries Prometheus periodically.

Then it converts raw numbers into simple beliefs:

| Raw telemetry | BDI belief |
| --- | --- |
| Error rate is high | `metric(production, error_rate, high)` |
| Latency is high | `metric(production, latency, high)` |
| Availability is low | `metric(production, availability, low)` |
| Any bad metric exists | `environment(production, unstable)` |

This is important because the BDI agent reasons over symbolic beliefs, not raw numbers.

## 9. How To Run The Main Demo

Run this from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\run_bdi_closed_loop.ps1
```

What happens:

1. The script resets the local Docker runtime.
2. It starts the Jason BDI agent.
3. The agent builds, tests, scans, deploys, and health-checks the service.
4. The script sends failing `/pay` traffic as a stimulus.
5. Prometheus records the payment failures.
6. The Jason environment sees high error rate.
7. The BDI agent decides production is unstable.
8. The BDI agent calls rollback.
9. Production returns to the stable version.

Expected output:

```text
[closed_loop] PASS: Jason closed loop triggered rollback from telemetry.
```

Evidence is saved in:

```text
experiments/bdi_closed_loop_results/production_telemetry_rollback.md
```

## 10. How To Run One Scenario

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\run_bdi_scenario_suite.ps1 -Scenario production_high_error_rate
```

What this scenario proves:

```text
Production /health can pass while /pay fails.
The BDI agent can still detect the problem through Prometheus telemetry.
The BDI agent rolls back production.
```

Scenario results are saved in:

```text
experiments/bdi_scenario_results/production_high_error_rate/
```

## 11. How To Compare Traditional Pipeline vs BDI

Run:

```powershell
py .\experiments\run_traditional_vs_bdi_comparison.py --scenarios success_stable production_high_error_rate high_latency
```

What happens:

1. The traditional fixed pipeline runs a scenario.
2. The Jason BDI controller runs the same scenario.
3. The script records what each controller decided.
4. It writes a Markdown report.

Report location:

```text
experiments/traditional_vs_bdi_results/comparison_report.md
```

Important result:

| Scenario | Traditional pipeline | BDI controller |
| --- | --- | --- |
| `success_stable` | Completes release | Completes release |
| `production_high_error_rate` | Completes release | Rolls back |
| `high_latency` | Completes release | Pauses and reobserves |

This is the core research evidence.

## 12. One Complete Execution Story

Here is the complete story for `production_high_error_rate`.

```text
The demo starts
  -> scenario runner starts Jason

Jason begins release
  -> deployment_agent adopts the goal: deliver_release(candidate)

Agent calls CI/CD actions
  -> build
  -> test
  -> security scan
  -> deploy staging
  -> health check staging
  -> deploy production
  -> health check production

Production health passes
  -> traditional pipeline would normally stop here and say success

The scenario sends failing /pay traffic
  -> payment service records errors

Prometheus scrapes /metrics
  -> high error rate appears in Prometheus

CicdEnvironment queries Prometheus
  -> converts high error rate into BDI belief

BDI belief changes
  -> metric(production, error_rate, high)
  -> environment(production, unstable)

AgentSpeak plan becomes applicable
  -> deployment_agent sees production is unstable
  -> recovery plan is selected

Agent acts
  -> rollback(production)

CicdEnvironment executes rollback
  -> cicd/actions/rollback.sh production

Production returns to stable
  -> status(rollback(production), passed)
  -> environment(production, stable)
```

## 13. What Files Are Needed For That Story?

Minimum important files:

```text
bdi/project.mas2j
bdi/deployment_agent.asl
bdi/src/env/CicdEnvironment.java
cicd/actions/*.sh
app/payment_service/service.py
docker-compose.yml
runtime/prometheus/prometheus.yml
telemetry/thresholds.yml
experiments/run_bdi_scenario_suite.ps1
experiments/bdi_scenario_catalog.json
```

## 14. What Is Real And What Is Legacy?

Real current BDI runtime:

```text
bdi/deployment_agent.asl
bdi/src/env/CicdEnvironment.java
bdi/project.mas2j
```

Legacy scaffolding:

```text
bdi/cicd_agent.asl
bdi/run_agent_for_scenario.sh
telemetry/generated_beliefs/
experiments/compile_results.py
experiments/real_telemetry_runner.py
```

The legacy path can print modeled traces. Those traces are useful history, but they are not proof that Jason made the decision.

For supervisor review, focus on the persistent Jason path.

## 15. Limitations

This is not production-ready software.

Current limitations:

```text
local Docker only
single BDI agent
simple deterministic plans
no Kubernetes
no cloud deployment
no machine learning
no persistent database of decisions
no multi-agent JaCaMo/CArtAgO system yet
```

The prototype proves a narrower point:

```text
A Jason BDI agent can use CI/CD action results and Prometheus telemetry as beliefs, then choose explainable release, rollback, pause, stop, or manual-intervention plans.
```
