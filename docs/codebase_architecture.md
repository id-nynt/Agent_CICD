# Codebase And Architecture Explanation

This document explains the repository structure and architecture in beginner-friendly language.

Use this document when you want to answer:

```text
What folders exist?
What does each component do?
Which files matter?
How do the parts connect?
What should I read first?
```

## 1. One-Sentence Project Summary

This project is a local research prototype where a Jason BDI agent controls a simulated CI/CD release pipeline, observes Prometheus telemetry from a fake payment service, and decides whether to release, rollback, pause, stop, or ask for manual intervention.

## 2. High-Level Architecture

The project has five main layers.

```text
+---------------------------------------------------------------+
| Experiment Layer                                              |
| PowerShell/Python runners configure scenarios and collect logs |
+-----------------------------+---------------------------------+
                              |
                              v
+---------------------------------------------------------------+
| BDI Control Layer                                             |
| Jason deployment_agent chooses plans from beliefs              |
+-----------------------------+---------------------------------+
                              |
                              v
+---------------------------------------------------------------+
| Environment Bridge Layer                                      |
| CicdEnvironment maps Jason actions/percepts to the outside     |
+-----------------------------+---------------------------------+
                              |
                              v
+---------------------------------------------------------------+
| CI/CD Action Layer                                            |
| Shell scripts build, test, deploy, health check, rollback      |
+-----------------------------+---------------------------------+
                              |
                              v
+---------------------------------------------------------------+
| Runtime + Telemetry Layer                                     |
| Docker payment services produce metrics scraped by Prometheus  |
+---------------------------------------------------------------+
```

In simple words:

```text
Runners start experiments.
Jason decides.
Java bridge connects Jason to scripts and telemetry.
Scripts change the running services.
Prometheus observes the services.
Telemetry becomes new Jason beliefs.
```

## 3. Folder Tree

Important project folders:

```text
260023_BDI_CICD/
|
|-- app/
|   `-- payment_service/
|       |-- service.py
|       |-- Dockerfile
|       |-- requirements.txt
|       `-- .dockerignore
|
|-- cicd/
|   |-- actions/
|   |   |-- build.sh
|   |   |-- test.sh
|   |   |-- security_scan.sh
|   |   |-- deploy.sh
|   |   |-- health_check.sh
|   |   |-- rollback.sh
|   |   `-- reset.sh
|   `-- pipeline_baseline.yml
|
|-- bdi/
|   |-- project.mas2j
|   |-- deployment_agent.asl
|   |-- cicd_agent.asl
|   |-- run_deployment_agent.sh
|   |-- run_agent_for_scenario.sh
|   |-- build.gradle
|   |-- settings.gradle
|   `-- src/
|       `-- env/
|           `-- CicdEnvironment.java
|
|-- telemetry/
|   |-- prometheus_adapter.py
|   |-- belief_mapper.py
|   |-- thresholds.yml
|   |-- generated_beliefs/
|   `-- tests...
|
|-- runtime/
|   `-- prometheus/
|       `-- prometheus.yml
|
|-- experiments/
|   |-- run_bdi_closed_loop.ps1
|   |-- run_bdi_scenario_suite.ps1
|   |-- bdi_scenario_catalog.json
|   |-- run_traditional_vs_bdi_comparison.py
|   |-- bdi_scenario_results/
|   |-- bdi_closed_loop_results/
|   `-- traditional_vs_bdi_results/
|
|-- docs/
|   |-- beginner_guide.md
|   |-- execution_walkthrough.md
|   |-- codebase_architecture.md
|   |-- architecture.md
|   |-- bdi_goal_model.md
|   |-- bdi_scenario_suite.md
|   |-- traditional_vs_bdi_comparison.md
|   `-- supervisor_review.md
|
|-- docker-compose.yml
|-- README.md
`-- .gitignore
```

## 4. What Each Major Folder Does

| Folder | Role | Beginner explanation |
| --- | --- | --- |
| `app/payment_service/` | Demo application | The fake service being deployed and observed. |
| `cicd/actions/` | CI/CD action scripts | The real operational commands: build, test, deploy, rollback. |
| `bdi/` | BDI controller | The Jason agent and Java bridge that decide and act. |
| `telemetry/` | Telemetry utilities | Python tools and thresholds for Prometheus data. |
| `runtime/prometheus/` | Monitoring config | Prometheus scrape configuration. |
| `experiments/` | Scenario execution | Scripts and outputs for BDI scenarios and comparisons. |
| `docs/` | Explanation | Human-readable architecture, walkthroughs, and reports. |

## 5. Application Layer

Location:

```text
app/payment_service/
```

Important file:

```text
app/payment_service/service.py
```

What it does:

```text
Runs a fake payment service.
Provides /health, /pay, /refund, and /metrics.
Can simulate failures or latency using environment variables.
Exports Prometheus metrics.
```

Endpoints:

| Endpoint | Method | Purpose |
| --- | --- | --- |
| `/health` | GET | Says whether the service is healthy. |
| `/pay` | POST | Simulates a payment. |
| `/refund` | POST | Simulates a refund. |
| `/metrics` | GET | Exposes metrics for Prometheus. |

Failure controls:

| Environment variable | Effect |
| --- | --- |
| `FAILURE_MODE=pay_error` | `/pay` returns errors. |
| `FAILURE_MODE=refund_error` | `/refund` returns errors. |
| `FAILURE_MODE=unhealthy` | `/health` fails. |
| `FORCE_ERROR_RATE=0.5` | Randomly fails around 50 percent of operations. |
| `EXTRA_LATENCY_MS=800` | Adds latency to requests. |

These variables are set indirectly by Docker Compose variables such as:

```text
PAYMENT_PRODUCTION_FAILURE_MODE
PAYMENT_PRODUCTION_EXTRA_LATENCY_MS
```

## 6. Runtime Layer

Location:

```text
docker-compose.yml
```

This file defines three important containers:

```text
payment-staging
payment-production
prometheus
```

Container-to-port mapping:

| Container | Host URL | Purpose |
| --- | --- | --- |
| `payment-staging` | `http://localhost:8001` | Candidate service in staging. |
| `payment-production` | `http://localhost:8002` | Stable or candidate service in production. |
| `prometheus` | `http://localhost:9090` | Metrics database and query API. |

Architecture:

```text
            +-------------------+
            |   Prometheus      |
            | localhost:9090    |
            +---------+---------+
                      |
          scrapes /metrics every 5s
                      |
       +--------------+--------------+
       |                             |
+------v--------+             +------v----------+
| payment       |             | payment         |
| staging       |             | production      |
| localhost:8001|             | localhost:8002  |
+---------------+             +-----------------+
```

## 7. CI/CD Action Layer

Location:

```text
cicd/actions/
```

These scripts are the public CI/CD interface.

That means both traditional and BDI paths should use these scripts, rather than duplicating deployment logic elsewhere.

| Script | What it does |
| --- | --- |
| `build.sh` | Builds or validates the payment service image/files. |
| `test.sh` | Runs simple service and compose checks. |
| `security_scan.sh` | Performs simple secret-pattern scanning. |
| `deploy.sh` | Starts/recreates staging or production service. |
| `health_check.sh` | Calls `/health` on staging or production. |
| `rollback.sh` | Restores production to the stable version. |
| `reset.sh` | Resets local runtime state. |

Simple action flow:

```text
build.sh
  -> test.sh
    -> security_scan.sh
      -> deploy.sh staging candidate
        -> health_check.sh staging
          -> deploy.sh production candidate
            -> health_check.sh production
```

Rollback flow:

```text
rollback.sh production
  -> sets production version to stable
  -> recreates payment-production container
  -> writes runtime/state/production_version.txt
```

## 8. BDI Layer

Location:

```text
bdi/
```

Important active files:

| File | Purpose |
| --- | --- |
| `project.mas2j` | Jason project configuration. |
| `deployment_agent.asl` | Active AgentSpeak BDI agent. |
| `src/env/CicdEnvironment.java` | Jason environment bridge. |
| `build.gradle` | Optional Gradle build/run configuration. |

Legacy files:

| File | Status |
| --- | --- |
| `cicd_agent.asl` | Older static scenario-style agent. |
| `run_agent_for_scenario.sh` | Older runner that can print modeled traces. |

### Active BDI Runtime Structure

```text
+-------------------------------+
| Jason MAS: cicd_bdi           |
|                               |
|  +-------------------------+  |
|  | Agent: deployment_agent |  |
|  | Goals, plans, beliefs   |  |
|  +------------+------------+  |
|               |
| external actions / percepts
|               |
|  +------------v------------+  |
|  | Environment:            |  |
|  | CicdEnvironment.java    |  |
|  +-------------------------+  |
+-------------------------------+
```

There is currently:

```text
one agent
one environment
no subagents
no multi-agent JaCaMo system yet
```

### What The Agent Wants

The agent wants to:

```text
deliver the candidate release safely
```

It decomposes that into:

```text
prepare candidate
validate candidate
deploy to staging
verify staging
deploy to production
verify production
maintain reliability
```

### What The Agent Can Do

The agent can call external actions:

```text
build(candidate)
test(candidate)
security_scan(candidate)
deploy(candidate, staging)
deploy(candidate, production)
health_check(staging)
health_check(production)
rollback(production)
```

Those are not just printed text. They are received by `CicdEnvironment.java`, which calls the real scripts under `cicd/actions/`.

## 9. Environment Bridge Layer

Location:

```text
bdi/src/env/CicdEnvironment.java
```

This is one of the most important files in the project.

It does two jobs:

```text
Job 1: Convert Jason actions into real shell script calls.
Job 2: Convert shell results and Prometheus telemetry into Jason percepts.
```

Action conversion:

```text
Jason: build(candidate)
Java: runScript("build.sh", "candidate")
Shell: cicd/actions/build.sh candidate
```

Telemetry conversion:

```text
Prometheus raw number: error_rate = 1.0
Threshold: error_rate > 0.05
Jason percept: metric(production,error_rate,high)
Jason percept: environment(production,unstable)
```

It writes evidence to:

```text
bdi/logs/cicd_environment.log
```

## 10. Telemetry Layer

Location:

```text
telemetry/
```

Important files:

| File | Purpose |
| --- | --- |
| `thresholds.yml` | Defines high/low thresholds for telemetry. |
| `prometheus_adapter.py` | Queries Prometheus once and prints JSON. |
| `belief_mapper.py` | Legacy converter from telemetry JSON to generated `.asl` beliefs. |
| `generated_beliefs/` | Legacy generated belief files. |

Important distinction:

```text
Current real BDI runtime:
  CicdEnvironment.java queries Prometheus and updates Jason percepts directly.

Legacy/static workflow:
  prometheus_adapter.py and belief_mapper.py can generate .asl belief files.
```

So:

```text
prometheus_adapter.py is useful for manual inspection.
belief_mapper.py is useful for legacy generated-belief experiments.
CicdEnvironment.java is the live conversion path for the active Jason controller.
```

## 11. Experiment Layer

Location:

```text
experiments/
```

Important files:

| File | Purpose |
| --- | --- |
| `run_bdi_closed_loop.ps1` | Focused end-to-end demo of telemetry-triggered rollback. |
| `run_bdi_scenario_suite.ps1` | Runs named BDI scenarios. |
| `bdi_scenario_catalog.json` | Defines scenario settings and expected evidence. |
| `run_traditional_vs_bdi_comparison.py` | Compares fixed pipeline with BDI controller. |
| `bdi_scenario_results/` | Generated BDI scenario evidence. |
| `traditional_vs_bdi_results/` | Generated comparison report and JSON. |

The experiment runners do not replace the BDI agent.

They do setup work:

```text
reset Docker
set environment variables
start Jason
send HTTP traffic
wait for evidence
write result files
```

The BDI decisions still come from:

```text
bdi/deployment_agent.asl
```

## 12. Documentation Layer

Location:

```text
docs/
```

Recommended reading order:

| Document | Purpose |
| --- | --- |
| `beginner_guide.md` | Gentle introduction to the whole project. |
| `execution_walkthrough.md` | Detailed step-by-step runtime behavior. |
| `codebase_architecture.md` | This codebase and architecture map. |
| `architecture.md` | Direct answers to trace questions. |
| `bdi_goal_model.md` | BDI beliefs, goals, plans, and decisions. |
| `bdi_scenario_suite.md` | Scenario catalog and how to run it. |
| `traditional_vs_bdi_comparison.md` | Traditional-vs-BDI evaluation. |
| `supervisor_review.md` | Short review entry point. |

## 13. Runtime Data And Evidence

Some files are source code. Some are generated while running.

Generated runtime/evidence paths:

| Path | Generated by | Meaning |
| --- | --- | --- |
| `bdi/logs/cicd_environment.log` | `CicdEnvironment` | Action/percept/decision evidence log. |
| `runtime/state/` | Shell action scripts | Current deployed version and timestamps. |
| `experiments/bdi_scenario_results/` | Scenario runner | Scenario JSON and Markdown summaries. |
| `experiments/bdi_closed_loop_results/` | Closed-loop runner | Focused rollback demo evidence. |
| `experiments/traditional_vs_bdi_results/` | Comparison runner | Traditional-vs-BDI report and JSON. |

Important:

```text
Prometheus metric samples are stored inside Prometheus, not as repo JSON files by default.
Jason live beliefs are stored inside the running Jason agent, not as repo files.
Logs and JSON results are evidence snapshots, not the live belief store.
```

## 14. Complete Component Connection Diagram

```text
                         +----------------------------+
                         | experiments/*.ps1 / *.py   |
                         | setup, traffic, evidence   |
                         +-------------+--------------+
                                       |
                                       v
                         +----------------------------+
                         | Jason MAS                  |
                         | bdi/project.mas2j          |
                         +-------------+--------------+
                                       |
                         +-------------v--------------+
                         | deployment_agent.asl       |
                         | beliefs, goals, plans      |
                         +-------------+--------------+
                                       |
                            external actions / percepts
                                       |
                         +-------------v--------------+
                         | CicdEnvironment.java       |
                         | action bridge + telemetry  |
                         +------+---------------+-----+
                                |               |
                    shell action|               |Prometheus HTTP API query
                                |               |
             +------------------v---+       +---v----------------+
             | cicd/actions/*.sh    |       | Prometheus         |
             | build/test/deploy    |       | localhost:9090     |
             +----------+-----------+       +---+----------------+
                        |                   scrape /metrics
                        |                       |
                        v                       v
             +----------------------+   +----------------------+
             | Docker Compose       |   | payment service      |
             | staging/production   |   | /pay /refund /health |
             +----------------------+   | /metrics             |
                                        +----------------------+
```

## 15. Traditional vs BDI Architecture

Traditional pipeline:

```text
fixed script order
  -> build
  -> test
  -> scan
  -> deploy
  -> health check
  -> final decision
```

BDI pipeline:

```text
goal-driven agent
  -> calls same scripts
  -> receives action-result beliefs
  -> receives telemetry beliefs
  -> selects context-sensitive plan
  -> can continue after deploy-time health check
```

Core difference:

```text
Traditional pipeline mostly reasons at stage boundaries.
BDI controller can continue reasoning from changing beliefs after deployment.
```

## 16. What To Say In A Presentation

Short explanation:

```text
This project keeps the CI/CD action layer simple and unchanged.
The innovation is a Jason BDI control layer above it.
The BDI agent treats action results and telemetry as beliefs.
It uses explicit AgentSpeak plans to decide release, rollback, pause, stop, or manual intervention.
Prometheus provides runtime evidence that a simple health-check pipeline can miss.
```

Concrete example:

```text
In production_high_error_rate, /health passes but /pay fails.
The traditional pipeline completes because the health check passed.
The BDI controller sees high error-rate telemetry and rolls back.
That demonstrates improved reliability and explainability in the prototype.
```
