# Real Telemetry Experiment Comparison

Phase 12 compares traditional CI/CD action outcomes with BDI decisions derived from Prometheus telemetry.

| Scenario | Traditional Decision | BDI Decision | Error Rate | P95 Latency ms | Availability | Success | Explanation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| real_success | release_success | release_complete | 0.0000 | 4.75 | 1.0000 | true | Both complete because real telemetry remains stable. |
| real_production_unstable | release_success | rollback_production | 0.5000 | 4.75 | 1.0000 | true | Traditional health checks pass, but BDI rolls back because real payment metrics are unstable. |

## Notes

The traditional decision here is based on shell action success and `/health` checks. The unstable scenario deliberately keeps `/health` passing while `/pay` traffic fails, so Prometheus-derived beliefs expose a problem that simple health checks miss.
