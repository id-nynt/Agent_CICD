# Supervisor Review Guide

Start here for Phase 8 review.

## What Is Real

The real BDI runtime is:

```text
bdi/project.mas2j
bdi/deployment_agent.asl
bdi/src/env/CicdEnvironment.java
cicd/actions/*.sh
docker-compose.yml
runtime/prometheus/prometheus.yml
```

In this path, Jason runs `deployment_agent`, calls external actions, receives percepts, and selects AgentSpeak plans.

## What Is Legacy Scaffolding

The legacy modeled path is:

```text
bdi/run_agent_for_scenario.sh
bdi/cicd_agent.asl
telemetry/generated_beliefs/*.asl
experiments/compile_results.py
experiments/real_telemetry_runner.py
```

When run in default mode, that path prints modeled traces from Bash/Python-generated inputs. It should not be used as evidence that Jason made runtime decisions.

## Recommended Reading Order

1. `README.md`
2. `docs/beginner_guide.md`
3. `docs/execution_walkthrough.md`
4. `docs/codebase_architecture.md`
5. `docs/architecture.md`
6. `docs/bdi_goal_model.md`
7. `docs/bdi_closed_loop_demo.md`
8. `docs/bdi_scenario_suite.md`
9. `docs/traditional_vs_bdi_comparison.md`
10. `bdi/audit_current_runtime.md`

## Main Evidence Commands

Closed loop:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\run_bdi_closed_loop.ps1
```

One BDI scenario:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\run_bdi_scenario_suite.ps1 -Scenario production_high_error_rate
```

Comparison report:

```powershell
py .\experiments\run_traditional_vs_bdi_comparison.py --from-existing --scenarios success_stable production_high_error_rate high_latency
```

Inspect evidence:

```powershell
Get-Content .\bdi\logs\cicd_environment.log -Tail 120
Get-Content .\experiments\traditional_vs_bdi_results\comparison_report.md
```

Inspect live Jason beliefs while the MAS is running:

```powershell
cd bdi
jason agent mind deployment_agent
```

## Research Contribution

The contribution is not new CI/CD shell automation. The shell action interface stays intentionally simple.

The contribution is the BDI control layer:

```text
action result / telemetry percepts
  -> symbolic beliefs
  -> explicit goals and context-sensitive plans
  -> explainable decisions
```

The strongest demonstrated cases are:

| Scenario | Traditional result | BDI result | Contribution |
| --- | --- | --- | --- |
| `production_high_error_rate` | Completes release because `/health` passes | Rolls back from high error-rate telemetry | Reliability after deploy-time gates |
| `high_latency` | Completes release | Pauses/reobserves | Explainable ambiguity handling |
| `network_suspected` | No post-release reasoning loop | Manual intervention after observability failure | Safer escalation |
| `transient_recovery` | No reobserve intention | Keeps release after recovery | Avoids unnecessary rollback |

## Limitations And Future Extensions

Current limitations:

```text
local Docker-only runtime
single Jason agent
simple deterministic plans
no CArtAgO/JaCaMo artifacts yet
no Kubernetes/cloud deployment
no persistent event database
no machine learning
no production security hardening
```

Reasonable future extensions:

```text
multi-agent JaCaMo version
CArtAgO artifacts for pipeline and telemetry resources
durable event store for belief/action history
broader scenario suite
formal evaluation metrics for reliability and explainability
CI integration that invokes Jason in a controlled environment
```
