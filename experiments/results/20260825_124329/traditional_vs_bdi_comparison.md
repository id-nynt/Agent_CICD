# Traditional Vs BDI Comparison: Observed Evidence

Generated: 2026-08-25T13:00:28

Source logs: logs/

| Code | Scenario | BDI Observed Result | Traditional Observed Result | Comparison |
| --- | --- | --- | --- | --- |
| 01 | Successful delivery | PASS: BDI completed the root delivery goal and recorded release_complete. Log: 01_successful_delivery_bdi.log | PASS: Traditional fixed pipeline completed the happy path. Log: 01_successful_delivery_traditional.log | BDI adds explicit belief/goal/plan reasoning beyond the fixed shell sequence. |
| 02 | Telemetry-driven production failure | PASS: BDI saw high Prometheus error-rate telemetry, rolled back, restored reliability, and failed candidate delivery. Log: 02_telemetry_driven_production_failure_bdi.log | PASS: Traditional pipeline accepted the health-passing candidate and did not rollback. Log: 02_telemetry_driven_production_failure_traditional.log | BDI adds explicit belief/goal/plan reasoning beyond the fixed shell sequence. |
| 03 | High latency | PASS: BDI classified latency as high and chose pause/reobserve. Log: 03_high_latency_bdi.log | PASS: Traditional pipeline accepted the release without pause/reobserve reasoning. Log: 03_high_latency_traditional.log | BDI adds explicit belief/goal/plan reasoning beyond the fixed shell sequence. |
| 04 | Observability failure | PASS: BDI perceived telemetry unavailable/network suspected and escalated uncertainty. Log: 04_observability_failure_bdi.log | PASS: Traditional pipeline did not use telemetry as a decision source. Log: 04_observability_failure_traditional.log | BDI adds explicit belief/goal/plan reasoning beyond the fixed shell sequence. |
| 05 | Transient health failure and retry | PASS: BDI restored reliability after one failed health check, retried the same candidate, and succeeded. Log: 05_transient_health_failure_and_retry_bdi.log | PASS: Traditional path does not see the Java-only one-shot BDI hook. Log: 05_transient_health_failure_and_retry_traditional.log | BDI adds explicit belief/goal/plan reasoning beyond the fixed shell sequence. |
| 06 | Build gate failure | PASS: BDI stopped delivery when the build gate percept failed. Log: 06_build_gate_failure_bdi.log | PASS: Traditional shell path passed because BDI_FORCE_BUILD_FAIL is a Java BDI test hook. Log: 06_build_gate_failure_traditional.log | BDI adds explicit belief/goal/plan reasoning beyond the fixed shell sequence. |
| 07 | Rollback unavailable | PASS: BDI tried rollback after telemetry degradation, perceived rollback failure, and requested manual intervention. Log: 07_rollback_unavailable_bdi.log | PASS: Traditional path had no BDI recovery action or manual-intervention reasoning. Log: 07_rollback_unavailable_traditional.log | BDI adds explicit belief/goal/plan reasoning beyond the fixed shell sequence. |

## Important Notes

- This report is based on evidence found in the saved logs, not only process exit codes.
- The wrapper run captured Docker progress correctly, but PowerShell did not preserve child exit codes in the initial JSON; use this observed report for supervisor discussion.
- Scenario 04 contains BDI evidence for pause/reobserve and manual intervention, even though the scenario script's own final assertion reported failure because of a text-pattern mismatch.
- Scenario 02 remains the strongest live telemetry proof: real /pay traffic changed Prometheus metrics, then Jason recovered production and failed candidate delivery.
