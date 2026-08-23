# Traditional vs BDI Comparison

Phase 7 compares two controllers over the same local payment-service CI/CD action interface.

The comparison runner is:

```text
experiments/run_traditional_vs_bdi_comparison.py
```

The traditional path runs a fixed sequence:

```text
build -> test -> security_scan -> deploy staging -> health_check staging -> deploy production -> health_check production
```

If a production deploy or production health gate fails, it calls:

```text
cicd/actions/rollback.sh production
```

The BDI path invokes the Phase 6 Jason scenario runner. Jason decisions are made by `deployment_agent.asl`; the comparison runner only reads the resulting evidence.

## Run

Default fair runtime comparison set:

```powershell
py .\experiments\run_traditional_vs_bdi_comparison.py
```

Selected scenarios:

```powershell
py .\experiments\run_traditional_vs_bdi_comparison.py --scenarios success_stable production_high_error_rate high_latency
```

Outputs:

```text
experiments/traditional_vs_bdi_results/comparison_report.md
experiments/traditional_vs_bdi_results/comparison_results.json
experiments/traditional_vs_bdi_results/<scenario>.json
```

## Fairness Boundary

Both paths use `cicd/actions/*.sh`.

The default Phase 7 scenario set focuses on runtime stimuli that can be shared fairly:

```text
success_stable
production_high_error_rate
high_latency
network_suspected
transient_recovery
rollback_unavailable
```

The Phase 6 build/test/security forced-failure cases remain useful BDI control-flow tests, but their failures are injected through the Jason environment bridge rather than through the public shell scripts. They are therefore not part of the default fair comparison set.

## Evidence To Review

For each scenario, inspect:

```text
traditional.final_decision
traditional.actions
traditional.final_production_version
bdi.final_decision
bdi.bdi_percepts_and_beliefs
bdi.final_production_version
comparison_note
```

The comparison is research evidence for a local prototype. It does not claim production readiness.

## Current Supervisor Report

The generated report is:

```text
experiments/traditional_vs_bdi_results/comparison_report.md
```

The current reviewed comparison includes:

```text
success_stable
production_high_error_rate
high_latency
```

Key result:

```text
production_high_error_rate:
  traditional -> release_complete, production candidate
  BDI -> rollback_production, production stable
```

This is the clearest reliability contribution: `/health` can pass while `/pay` fails, so the fixed pipeline completes, while the BDI controller reacts to telemetry-derived instability.

Another key result:

```text
high_latency:
  traditional -> release_complete
  BDI -> pause_reobserve
```

This is the clearest explainability contribution: the BDI decision records why it did not immediately rollback, using `reobserve_reason(high_latency)`.

## Regenerate Without Rerunning Docker

After individual scenario JSON files exist, regenerate the Markdown table with:

```powershell
py .\experiments\run_traditional_vs_bdi_comparison.py --from-existing --scenarios success_stable production_high_error_rate high_latency
```

This mode only aggregates existing evidence.
