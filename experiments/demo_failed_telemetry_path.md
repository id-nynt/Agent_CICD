# Manual Demo: Failed Telemetry-Driven BDI Path

This guide demonstrates the important failed path manually:

```text
Jason starts
-> candidate reaches production
-> production /health passes
-> Jason opens a production canary observation window
-> you send bad /pay traffic during the window
-> payment service metrics change
-> Prometheus scrapes the changed metrics
-> CicdEnvironment converts telemetry into Jason percepts
-> Jason sees production unstable
-> Jason chooses rollback(production)
```

This is the strongest research demo because it is not a `BDI_FORCE_*` scenario.

## What Is Forced And What Is Not

This demo sets:

```powershell
$env:PAYMENT_PRODUCTION_FAILURE_MODE="pay_error"
```

That configures the candidate production service so `/pay` can fail after deployment.

This does not force Jason's decision. The BDI decision still depends on this chain:

```text
POST /pay traffic
-> payment_service_errors_total increases
-> Prometheus scrape
-> CicdEnvironment poll
-> metric(production,error_rate,high)
-> environment(production,unstable)
-> AgentSpeak recovery plan
-> rollback(production)
```

Do not set these variables for this demo:

```text
BDI_FORCE_BUILD_FAIL
BDI_FORCE_TEST_FAIL
BDI_FORCE_SECURITY_SCAN_FAIL
BDI_FORCE_HEALTH_CHECK_PRODUCTION_FAIL
BDI_FORCE_ROLLBACK_PRODUCTION_FAIL
```

Those are action-result fault injection variables, not telemetry perception evidence.

## Terminals

Use three PowerShell terminals.

### Terminal A: Clean Start

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
docker compose down --remove-orphans
if (Test-Path .\bdi\logs\cicd_environment.log) { Clear-Content .\bdi\logs\cicd_environment.log }
```

### Terminal B: Watch The Environment Log

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
Get-Content .\bdi\logs\cicd_environment.log -Tail 180 -Wait
```

### Terminal C: Start Jason

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD\bdi

$env:BDI_TELEMETRY_ENABLED="true"
$env:BDI_TELEMETRY_INTERVAL_SECONDS="3"
$env:BDI_TELEMETRY_GRACE_SECONDS="5"
$env:BDI_OBSERVE_PRODUCTION_CANARY_MS="25000"

$env:PAYMENT_STAGING_FAILURE_MODE="none"
$env:PAYMENT_PRODUCTION_FAILURE_MODE="pay_error"
$env:PAYMENT_PRODUCTION_FORCE_ERROR_RATE="0"
$env:PAYMENT_PRODUCTION_EXTRA_LATENCY_MS="0"

jason project.mas2j
```

## Wait For The Midway Timing Window

Do not send traffic immediately.

Wait until the log shows:

```text
[CicdEnvironment] percept status(health_check(production), passed)
[CicdEnvironment][decision] observe_production_canary
[CicdEnvironment][observe] start environment=production phase=canary duration_ms=25000
```

This is the important moment. The candidate is deployed, health has passed, but Jason has not yet accepted the release.

## Trigger The Environment Change

In Terminal A, send bad `/pay` traffic while the canary window is still open:

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD

1..12 | ForEach-Object {
  try {
    Invoke-RestMethod -Method POST -Uri http://localhost:8002/pay -ContentType "application/json" -Body "{`"amount`": $_}"
  } catch {
    "pay request failed as expected"
  }
}
```

The browser may show `Method Not Allowed` for `/pay` because browser navigation uses GET. This demo uses POST.

## What To Watch

The telemetry should change from normal to high:

```text
[CicdEnvironment][telemetry] production error_rate=1.0000(high) ... environment=unstable
```

The Java environment should convert that to percepts:

```text
metric(production,error_rate,high)
environment(production,unstable)
observation(production, canary, unstable)
```

Jason should then choose recovery:

```text
[CicdEnvironment][decision] recovery_reason reason=telemetry_unstable
[CicdEnvironment] action ... rollback.sh production
[CicdEnvironment] percept status(rollback(production), passed)
[CicdEnvironment][decision] rollback_production
```

After rollback, production should return to stable:

```text
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) ... environment=stable
```

## Inspect Jason Beliefs

In another terminal while Jason is still running:

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD\bdi
jason agent mind deployment_agent
```

Expected beliefs include:

```text
status(deploy(production),passed)[source(percept)]
status(health_check(production),passed)[source(percept)]
metric(production,error_rate,high)[source(percept)]
observation(production,canary,unstable)[source(percept)]
recovery_reason(telemetry_unstable)[source(self)]
status(rollback(production),passed)[source(percept)]
decision(rollback_production)[source(self)]
```

## Automated Version

The automation script with the same basename is:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\demo_failed_telemetry_path.ps1
```

The script automates the same manual story:

```text
start Jason
wait for observe(production, canary)
send POST /pay traffic
wait for telemetry_unstable rollback evidence
print the log tail
```

It does not use `BDI_FORCE_*` variables and does not choose rollback.

## Cleanup

After the demo:

```powershell
Remove-Item Env:\BDI_TELEMETRY_ENABLED -ErrorAction SilentlyContinue
Remove-Item Env:\BDI_TELEMETRY_INTERVAL_SECONDS -ErrorAction SilentlyContinue
Remove-Item Env:\BDI_TELEMETRY_GRACE_SECONDS -ErrorAction SilentlyContinue
Remove-Item Env:\BDI_OBSERVE_PRODUCTION_CANARY_MS -ErrorAction SilentlyContinue
Remove-Item Env:\PAYMENT_STAGING_FAILURE_MODE -ErrorAction SilentlyContinue
Remove-Item Env:\PAYMENT_PRODUCTION_FAILURE_MODE -ErrorAction SilentlyContinue
Remove-Item Env:\PAYMENT_PRODUCTION_FORCE_ERROR_RATE -ErrorAction SilentlyContinue
Remove-Item Env:\PAYMENT_PRODUCTION_EXTRA_LATENCY_MS -ErrorAction SilentlyContinue
```

