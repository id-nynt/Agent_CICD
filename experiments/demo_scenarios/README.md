# Demo Scenario Scripts

Each script runs one BDI scenario through:

```text
experiments/run_bdi_scenario_suite.ps1
```

Run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\demo_scenarios\08_production_high_error_rate.ps1
```

Available scripts:

```text
01_success_stable.ps1
02_build_failure.ps1
03_test_failure.ps1
04_security_failure.ps1
05_staging_instability.ps1
06_production_deploy_failure.ps1
07_production_health_failure.ps1
08_production_high_error_rate.ps1
09_high_latency.ps1
10_network_suspected.ps1
11_transient_recovery.ps1
12_rollback_unavailable.ps1
13_production_health_transient_retry.ps1
```

The scripts automate setup and evidence collection. They do not choose the BDI decision; the decision still comes from `bdi/deployment_agent.asl`.
