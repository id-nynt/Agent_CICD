# Real Telemetry Experiment Comparison

Phase 16 runs real telemetry scenarios from `experiments/real_scenarios.yml` and compares traditional CI/CD expectations with BDI decisions derived from Prometheus telemetry.

| Scenario | Traditional Decision | Expected BDI | Actual BDI | Error Rate | P95 Latency ms | Availability | Success | Explanation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| real_high_error_rate | release_success | rollback_production | rollback_production | 1.0000 | 4.75 | 1.0000 | true | BDI can roll back from telemetry-derived production instability that a health-check-only pipeline would miss. |

## Notes

The traditional decision is based on shell action success and `/health` checks. The BDI decision is produced from generated symbolic beliefs, including Prometheus-derived error rate, latency, availability, environment stability, and context beliefs such as reobserve or suspected network issues.
