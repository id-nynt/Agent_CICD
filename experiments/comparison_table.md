# Experiment Comparison Table

Phase 5 compares traditional CI/CD expectations with BDI decisions over the same scenarios.

| Scenario | Traditional Decision | BDI Decision | Selected BDI Actions | Success | Explanation |
| --- | --- | --- | --- | --- | --- |
| success_stable | release_success | release_complete | build(candidate), test(candidate), security_scan(candidate), deploy(staging, candidate), health_check(staging), deploy(production, candidate), health_check(production) | true | Both complete the release. |
| production_unstable | rollback | rollback_production | build(candidate), test(candidate), security_scan(candidate), deploy(staging, candidate), health_check(staging), deploy(production, candidate), health_check(production), rollback(production) | true | Both recover, but BDI decision is justified by unstable beliefs. |
| stage_failure | stop_pipeline | stop_pipeline | build(candidate), test(candidate) | true | Both stop before production; BDI preserves reliability goal. |
| rollback_midway_recovery | rollback | pause_reobserve | build(candidate), test(candidate), security_scan(candidate), deploy(staging, candidate), health_check(staging), deploy(production, candidate), health_check(production), pause(reobserve_before_rollback), reobserve(production) | true | BDI delays rollback because context suggests reobservation. |
| network_issue_suspected | rollback | pause_reobserve | build(candidate), test(candidate), security_scan(candidate), deploy(staging, candidate), health_check(staging), deploy(production, candidate), health_check(production), pause(network_issue_suspected), reobserve(production) | true | BDI delays rollback because context suggests reobservation. |

## What Differs

Traditional CI/CD follows stage outcomes and predefined recovery expectations. In these experiments, a production failure leads to a rollback expectation.

BDI CI/CD reasons over symbolic beliefs derived from telemetry and context. It can still choose rollback when production is unstable, but it can also pause and reobserve when beliefs such as `network_issue_suspected(true).` or `reobserve_after_failure(true).` make immediate rollback less explainable.

The context-aware scenarios are `rollback_midway_recovery` and `network_issue_suspected`, where the BDI decision is `pause_reobserve` while the traditional decision remains `rollback`.
