# Manual Demo Pipeline: Command Summary

This is the short command-first guide. Open several PowerShell terminals and follow the numbered steps. Use Step 5.2 only when the scenario needs an error or environment change.

## Overall Workflow

| Step | What to do | Command |
| --- | --- | --- |
| 1 | Open Terminal 1 and clean old containers/logs. | See **Step 1**. |
| 2 | Open Terminal 2 and watch the Java/Jason environment log. | See **Step 2**. |
| 3 | Open Terminal 3 and start Jason with scenario variables. | See **Step 3**. |
| 4 | Watch the MAS console until the agent reaches the target moment. | Look for build/test/security/staging/production messages. |
| 5 | Let the happy path continue, or prepare for an error scenario. | No command unless the scenario says so. |
| 5.2 | Trigger the scenario condition at the right moment. | Use the matching command in **Trigger Error Moment**. |
| 6 | Inspect Jason beliefs. | See **Step 6**. |
| 7 | Check final production state. | See **Step 7**. |
| 8 | Optionally run the automated version. | See **Automation Commands**. |

## Step 1: Clean State

Run before every manual demo.

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
docker compose down --remove-orphans
if (Test-Path .\bdi\logs\cicd_environment.log) { Clear-Content .\bdi\logs\cicd_environment.log }
```

Clear old environment variables in the same terminal you will use to start Jason.

```powershell
Remove-Item Env:\BDI_TELEMETRY_ENABLED -ErrorAction SilentlyContinue
Remove-Item Env:\BDI_TELEMETRY_INTERVAL_SECONDS -ErrorAction SilentlyContinue
Remove-Item Env:\BDI_TELEMETRY_GRACE_SECONDS -ErrorAction SilentlyContinue
Remove-Item Env:\BDI_OBSERVE_PRODUCTION_CANARY_MS -ErrorAction SilentlyContinue
Remove-Item Env:\BDI_PROMETHEUS_URL -ErrorAction SilentlyContinue
Remove-Item Env:\PAYMENT_STAGING_FAILURE_MODE -ErrorAction SilentlyContinue
Remove-Item Env:\PAYMENT_PRODUCTION_FAILURE_MODE -ErrorAction SilentlyContinue
Remove-Item Env:\PAYMENT_PRODUCTION_FORCE_ERROR_RATE -ErrorAction SilentlyContinue
Remove-Item Env:\PAYMENT_PRODUCTION_EXTRA_LATENCY_MS -ErrorAction SilentlyContinue
Remove-Item Env:\BDI_FORCE_BUILD_FAIL -ErrorAction SilentlyContinue
Remove-Item Env:\BDI_FORCE_TEST_FAIL -ErrorAction SilentlyContinue
Remove-Item Env:\BDI_FORCE_SECURITY_SCAN_FAIL -ErrorAction SilentlyContinue
Remove-Item Env:\BDI_FORCE_HEALTH_CHECK_PRODUCTION_FAIL_ONCE -ErrorAction SilentlyContinue
Remove-Item Env:\BDI_FORCE_ROLLBACK_PRODUCTION_FAIL -ErrorAction SilentlyContinue
```

## Step 2: Watch Environment Log

This is the best evidence window.

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
Get-Content .\bdi\logs\cicd_environment.log -Tail 180 -Wait
```

Look for:

```text
[CicdEnvironment] action ...
[CicdEnvironment] percept ...
[CicdEnvironment][telemetry] ...
[CicdEnvironment][decision] ...
```

## Step 3: Start Jason

Choose one scenario setup, then run `jason project.mas2j`.

### 01 Successful Delivery

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD\bdi
$env:BDI_TELEMETRY_ENABLED="true"
$env:BDI_TELEMETRY_INTERVAL_SECONDS="3"
$env:BDI_TELEMETRY_GRACE_SECONDS="5"
$env:BDI_OBSERVE_PRODUCTION_CANARY_MS="15000"
$env:PAYMENT_STAGING_FAILURE_MODE="none"
$env:PAYMENT_PRODUCTION_FAILURE_MODE="none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE="0"
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS="0"
jason project.mas2j
```

### 02 Telemetry-Driven Production Failure

This config makes real `/pay` requests fail probabilistically after the candidate is deployed.

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD\bdi
$env:BDI_TELEMETRY_ENABLED="true"
$env:BDI_TELEMETRY_INTERVAL_SECONDS="3"
$env:BDI_TELEMETRY_GRACE_SECONDS="5"
$env:BDI_OBSERVE_PRODUCTION_CANARY_MS="35000"
$env:PAYMENT_STAGING_FAILURE_MODE="none"
$env:PAYMENT_PRODUCTION_FAILURE_MODE="none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE="0.20"
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS="0"
jason project.mas2j
```

### 03 High Latency

This config makes production business requests slow.

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD\bdi
$env:BDI_TELEMETRY_ENABLED="true"
$env:BDI_TELEMETRY_INTERVAL_SECONDS="3"
$env:BDI_TELEMETRY_GRACE_SECONDS="5"
$env:BDI_OBSERVE_PRODUCTION_CANARY_MS="25000"
$env:PAYMENT_STAGING_FAILURE_MODE="none"
$env:PAYMENT_PRODUCTION_FAILURE_MODE="none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE="0"
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS="800"
jason project.mas2j
```

### 04 Observability Failure

This makes the Java environment unable to query Prometheus.

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD\bdi
$env:BDI_TELEMETRY_ENABLED="true"
$env:BDI_TELEMETRY_INTERVAL_SECONDS="3"
$env:BDI_TELEMETRY_GRACE_SECONDS="5"
$env:BDI_OBSERVE_PRODUCTION_CANARY_MS="25000"
$env:BDI_PROMETHEUS_URL="http://localhost:19090"
$env:PAYMENT_PRODUCTION_FAILURE_MODE="none"
jason project.mas2j
```

### 05 Transient Health Failure And Retry

This makes the first production health check fail once, then allows retry.

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD\bdi
$env:BDI_TELEMETRY_ENABLED="false"
$env:BDI_OBSERVE_PRODUCTION_CANARY_MS="1000"
$env:BDI_FORCE_HEALTH_CHECK_PRODUCTION_FAIL_ONCE="true"
jason project.mas2j
```

### 06 Build/Test/Security Gate Failure

Choose only one gate flag.

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD\bdi
$env:BDI_TELEMETRY_ENABLED="false"
$env:BDI_FORCE_BUILD_FAIL="true"
jason project.mas2j
```

Alternative gate flags:

```powershell
$env:BDI_FORCE_TEST_FAIL="true"
$env:BDI_FORCE_SECURITY_SCAN_FAIL="true"
```

### 07 Rollback Unavailable

This creates telemetry degradation and then makes rollback fail.

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD\bdi
$env:BDI_TELEMETRY_ENABLED="true"
$env:BDI_TELEMETRY_INTERVAL_SECONDS="3"
$env:BDI_TELEMETRY_GRACE_SECONDS="5"
$env:BDI_OBSERVE_PRODUCTION_CANARY_MS="35000"
$env:PAYMENT_STAGING_FAILURE_MODE="none"
$env:PAYMENT_PRODUCTION_FAILURE_MODE="none"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE="0.20"
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS="0"
$env:BDI_FORCE_ROLLBACK_PRODUCTION_FAIL="true"
jason project.mas2j
```

## Step 4: Wait For The Target Moment

Watch Terminal 2 and the MAS console.

```text
For telemetry scenarios, wait until deploy(candidate, production) passes and observe(production, canary) starts.
For gate scenarios, no manual trigger is needed because the failure happens at build/test/security.
For transient health retry, no manual trigger is needed because the one-shot health failure is configured before Jason starts.
```

## Step 5.2: Trigger Error Moment

Use these only after the correct moment in Step 4.

### Trigger Production Error-Rate Telemetry

Run after production deployment passes and canary observation starts.

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
1..80 | ForEach-Object {
  try {
    Invoke-RestMethod -Method POST -Uri http://localhost:8002/pay -ContentType "application/json" -Body "{`"amount`": $_}" | Out-Null
  } catch {}
  Start-Sleep -Milliseconds 150
}
```

Expected effect: app metrics change, Prometheus scrapes them, Java emits `metric(production,error_rate,high)`, and Jason chooses rollback.

### Trigger High-Latency Telemetry

Run after production deployment passes and canary observation starts.

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
1..40 | ForEach-Object {
  Invoke-RestMethod -Method POST -Uri http://localhost:8002/pay -ContentType "application/json" -Body "{`"amount`": $_}" | Out-Null
}
```

Expected effect: app latency metrics change, Prometheus scrapes them, Java emits `metric(production,latency,high)`, and Jason pauses/reobserves.

### Trigger Observability Failure Manually

Usually this is configured before Jason starts with `BDI_PROMETHEUS_URL=http://localhost:19090`. If you want a visible infrastructure interruption instead, stop Prometheus during canary.

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
docker compose stop prometheus
```

Expected effect: Java emits `telemetry(production,unavailable)` and `network(production,suspected)`, and Jason escalates uncertainty/manual intervention.

## Step 6: Inspect Agent Mind

Run while Jason is still alive.

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD\bdi
jason agent mind deployment_agent
```

Useful beliefs to look for:

```text
delivery_succeeded(candidate)
delivery_failed(candidate, Reason)
delivery_deferred(candidate, Reason)
production_reliability_restored
decision(rollback_production)
decision(pause_reobserve)
decision(rollback_then_retry_production)
decision(manual_intervention_required)
metric(production,error_rate,high)
metric(production,latency,high)
telemetry(production,unavailable)
environment(production,unstable)
```

## Step 7: Check Final State

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
Get-Content .\runtime\state\production_version.txt
Invoke-WebRequest -UseBasicParsing http://localhost:8002/health
py .\telemetry\prometheus_adapter.py production --pretty
```

Expected version:

```text
candidate = successful delivery
stable    = rollback happened
```

## Automation Commands

Run one BDI scenario:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\01_successful_delivery_bdi.ps1
powershell -ExecutionPolicy Bypass -File .\experiments\02_telemetry_production_failure_bdi.ps1
powershell -ExecutionPolicy Bypass -File .\experiments\03_high_latency_bdi.ps1
powershell -ExecutionPolicy Bypass -File .\experiments\04_observability_failure_bdi.ps1
powershell -ExecutionPolicy Bypass -File .\experiments\05_transient_health_retry_bdi.ps1
powershell -ExecutionPolicy Bypass -File .\experiments\06_gate_failures_bdi.ps1 -Gate build
powershell -ExecutionPolicy Bypass -File .\experiments\07_rollback_unavailable_bdi.ps1
```

Run one traditional comparison scenario:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\01_successful_delivery_traditional.ps1
powershell -ExecutionPolicy Bypass -File .\experiments\02_telemetry_production_failure_traditional.ps1
powershell -ExecutionPolicy Bypass -File .\experiments\03_high_latency_traditional.ps1
powershell -ExecutionPolicy Bypass -File .\experiments\04_observability_failure_traditional.ps1
powershell -ExecutionPolicy Bypass -File .\experiments\05_transient_health_retry_traditional.ps1
powershell -ExecutionPolicy Bypass -File .\experiments\06_gate_failures_traditional.ps1 -Gate build
powershell -ExecutionPolicy Bypass -File .\experiments\07_rollback_unavailable_traditional.ps1
```

Run everything and store logs/results:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\run_all_numbered_experiments.ps1
```

## Fast Evidence Checklist

| Scenario | Evidence in log or agent mind |
| --- | --- |
| `01` success | `delivery_succeeded(candidate)`, `decision(release_complete)`, production version `candidate`. |
| `02` error rate | `metric(production,error_rate,high)`, `decision(rollback_production)`, `delivery_failed(candidate,telemetry_unstable)`, production version `stable`. |
| `03` latency | `metric(production,latency,high)`, `decision(pause_reobserve)`. |
| `04` observability | `telemetry(production,unavailable)`, `network(production,suspected)`, `decision(manual_intervention_required)`. |
| `05` retry | `decision(rollback_then_retry_production)`, `decision(continue_deploy_candidate)`, `delivery_succeeded(candidate)`. |
| `06` gate fail | `status(build,failed)` or `status(test,failed)` or `status(security_scan,failed)`, then `delivery_failed(candidate,...)`. |
| `07` rollback unavailable | `decision(rollback_production)`, `status(rollback(production),failed)`, `decision(manual_intervention_required)`. |
