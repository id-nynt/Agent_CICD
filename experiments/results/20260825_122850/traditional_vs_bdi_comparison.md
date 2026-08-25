# Traditional Vs BDI Experiment Comparison

Generated: 2026-08-25T12:42:45

Logs directory: logs/

| Code | Scenario | BDI Result | Traditional Result | BDI Capability Demonstrated |
| --- | --- | --- | --- | --- |
| 01 | Successful delivery | PASS; production=candidate; expected: delivery_succeeded(candidate), release_complete, production=candidate; log: 01_successful_delivery_bdi.log | FAIL; production=candidate; expected: fixed release complete, production=candidate; log: <none> | Completes the delivery goal when action and telemetry beliefs stay healthy. |
| 02 | Telemetry-driven production failure | FAIL; production=stable; expected: production_reliability_restored, delivery_failed, production=stable; log: <none> | FAIL; production=candidate; expected: fixed pipeline accepts health-passing candidate, production=candidate; log: <none> | Uses real traffic and Prometheus error-rate telemetry to rollback and fail candidate delivery. |
| 03 | High latency | FAIL; production=candidate; expected: metric latency high, pause_reobserve(high_latency); log: <none> | FAIL; production=candidate; expected: fixed release complete, no pause/reobserve; log: <none> | Distinguishes latency from error-rate failure and chooses pause/reobserve. |
| 04 | Observability failure | FAIL; production=candidate; expected: telemetry unavailable, pause_reobserve(network_suspected); log: <none> | FAIL; production=candidate; expected: fixed release complete, no telemetry reasoning; log: <none> | Recognizes telemetry unavailable/network suspected instead of app failure. |
| 05 | Transient health failure and retry | FAIL; production=candidate; expected: rollback_then_retry, continue_deploy_candidate, delivery_succeeded; log: <none> | FAIL; production=candidate; expected: fixed release complete; Java-only one-shot hook is not visible; log: <none> | Restores reliability, then retries the same candidate and succeeds. |
| 06 | Build gate failure | FAIL; production=candidate; expected: status(build,failed), delivery_failed(build_failed); log: <none> | FAIL; production=candidate; expected: shell actions pass if source is valid; Java hook is not visible; log: <none> | Stops delivery when an early gate percept fails. |
| 07 | Rollback unavailable | FAIL; production=candidate; expected: status(rollback(production),failed), manual_intervention_required; log: <none> | FAIL; production=candidate; expected: fixed release complete; no BDI rollback decision to fail; log: <none> | Escalates to manual intervention when recovery action fails. |

## Notes

- Traditional scripts use the same cicd/actions/*.sh public action interface, but they do not create Jason beliefs or choose BDI plans.
- PAYMENT_* variables configure app/container behavior.
- BDI_FORCE_* variables are Java environment test hooks used only for selected BDI control-flow scenarios.
- The strongest live telemetry proof is scenario 02, where real /pay traffic changes Prometheus metrics and Jason reacts.
