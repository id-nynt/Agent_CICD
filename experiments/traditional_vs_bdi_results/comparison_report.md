# Traditional vs Jason BDI Comparison

This report is research evidence for the prototype only. It does not claim production readiness.

Both controllers use the same public shell action interface under `cicd/actions/*.sh`. The traditional controller runs a fixed stage order. The BDI controller runs Jason `deployment_agent` through `CicdEnvironment` and records decisions selected by AgentSpeak plans.

| Scenario | Traditional decision | BDI decision | Traditional production | BDI production | BDI evidence | Improvement / explanation |
| --- | --- | --- | --- | --- | --- | --- |
| success_stable | release_complete | release_complete | candidate | candidate | decision(release_complete), environment(production,stable) | Both controllers make the same final decision; BDI adds explicit percepts and reasons. |
| production_high_error_rate | release_complete | rollback_production | candidate | stable | metric(production,error_rate,high), environment(production,unstable), recovery_reason(telemetry_unstable), decision(rollback_production), status(rollback(production),passed) | BDI improves reliability by reacting to post-release telemetry that the fixed pipeline ignores. |
| high_latency | release_complete | pause_reobserve | candidate | candidate | metric(production,latency,high), decision(pause_reobserve), reobserve_reason(high_latency) | BDI improves explainability by distinguishing ambiguous telemetry from definite failure. |

## Interpretation

- A fixed pipeline can prove the deploy-time gates passed, but it does not keep an intention alive to reason over telemetry after release.
- The BDI controller exposes why it acted through percepts such as `metric(production,error_rate,high)`, `environment(production,unstable)`, `reobserve_reason(high_latency)`, and `manual_reason(network_suspected)`.
- The strongest BDI evidence is in post-release scenarios: high error rate, high latency, network suspected, transient recovery, and rollback unavailable.
- This remains a local research prototype, not production-ready automation.
