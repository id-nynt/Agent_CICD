# Phase 0 Architecture

Research prototype: **Autonomous CI/CD pipeline using BDI multi-agent system**

Phase 0 defines scope and baseline design only. It does not build the demo application, automation scripts, telemetry adapters, BDI agent, infrastructure, or experiment runner.

## Purpose

The prototype should show how a BDI agent can manage a CI/CD release by converting CI/CD events and telemetry into symbolic beliefs, selecting goals and plans, executing actions, and recording explainable results.

Phase 1 is only a traditional CI/CD reference. It provides useful vocabulary such as build, test, security scan, deploy, health check, and rollback. Phase 2 should not copy Phase 1 directly because the research value depends on separating observation, belief formation, reasoning, action selection, and results.

## Required Flow

```text
events -> telemetry -> beliefs -> goals/plans -> actions -> results
```

This flow is the core design boundary for the prototype:

| Layer | Responsibility | Phase 0 Decision |
| --- | --- | --- |
| Events | Record what happened in the pipeline or simulated environment | Use scenario-defined events first |
| Telemetry | Represent measured or simulated operational signals | Use simple scenario values first |
| Beliefs | Convert events and telemetry into symbolic BDI facts | Use explicit, human-readable beliefs |
| Goals and plans | Decide what the agent wants and how it should proceed | Start with one explainable BDI release agent |
| Actions | Execute or model CI/CD operations | Keep actions independent and shell-callable in later phases |
| Results | Store decisions, actions, beliefs, and outcomes | Use machine-readable experiment results later |

## Proposed Repository Shape

The later implementation should keep the experimental layers separate:

```text
app/
  versions/
    stable/
    candidate/

cicd/
  actions/
  pipeline_baseline.yml

simulation/
  scenarios/
  event_log/

telemetry/
  thresholds.yml
  generated_beliefs/

bdi/
  cicd_agent.asl
  project.mas2j

experiments/
  results/

runtime/
  deployments/
  state/

docs/
```

This structure is intentionally different from a direct Phase 1 copy. The action layer may reuse the same kind of shell-script interface, but scenario simulation, telemetry mapping, BDI reasoning, and experiment results should each have their own location and purpose.

## CI/CD Actions

The BDI agent should eventually choose from a small, stable action vocabulary:

| Action | Intent |
| --- | --- |
| `build(candidate)` | Validate that the candidate release can be packaged or prepared |
| `test(candidate)` | Run functional checks for the candidate release |
| `security_scan(candidate)` | Run simple security checks before deployment |
| `deploy(staging, candidate)` | Place the candidate into staging |
| `health_check(staging)` | Verify staging health after deployment |
| `deploy(production, candidate)` | Place the candidate into production |
| `health_check(production)` | Verify production health after deployment |
| `rollback(production)` | Restore the previous production version |
| `pause(reason)` | Delay action when evidence is insufficient or unstable |
| `reobserve(environment)` | Gather updated events or telemetry before deciding |
| `record_result(decision)` | Save the selected decision and outcome for analysis |

Only the core CI/CD actions should execute real local work in early phases. `pause`, `reobserve`, and `record_result` may begin as simulated or logged decisions.

## Design Constraints

- Keep local execution first.
- Keep the demo app intentionally small.
- Keep CI/CD actions independent rather than hidden inside one large pipeline script.
- Do not implement Prometheus, OpenTelemetry, Kubernetes, GitHub API, cloud deployment, or ML in early phases.
- Do not create production-level infrastructure.
- Prefer explicit thresholds and symbolic beliefs over opaque decision logic.
- Keep traditional CI/CD behavior and BDI decision-making behavior comparable but separate.

## Real, Simulated, And Future Work

| Area | Phase 0 Classification | Notes |
| --- | --- | --- |
| Phase 1 traditional pipeline | Real reference | Used only to understand baseline actions and limitations |
| Demo app | Future local implementation | Should be minimal and file-based |
| CI/CD action scripts | Future real local implementation | Shell-callable, independent actions |
| Scenario events | Simulated | Defined by scenario files |
| Telemetry values | Simulated | Simple values such as error rate, latency, availability |
| Belief mapping | Future local implementation | Rule-based thresholds first |
| BDI reasoning | Future local implementation | Jason/AgentSpeak is the likely first implementation |
| Experiment results | Future local implementation | JSON plus Markdown summaries |
| Prometheus/OpenTelemetry | Future work | Adapter replaces simulated telemetry later |
| Kubernetes/cloud deployment | Future work | Not needed for initial research proof |
| GitHub/GitLab API | Future work | Can replace local actions later |
| ML prediction | Future work | Can add beliefs such as `failure_risk(production, high)` |
| Multi-agent coordination | Future work | Start with one release agent first |

## Whole Prototype Success Criteria

The whole prototype is successful when:

- The system has a minimal demo app and independent CI/CD actions.
- Scenario files can produce different CI/CD and environment conditions.
- Telemetry is mapped into explainable symbolic beliefs.
- A BDI agent uses beliefs, goals, and plans to select actions.
- Traditional and BDI decisions can be compared across the same scenarios.
- Results record initial beliefs, updated beliefs, selected actions, final state, and success.
- At least one scenario demonstrates context-aware BDI behavior that differs from the traditional pipeline.
- Future integrations can be added without redesigning the core flow.
