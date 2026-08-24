# Manual Demo: Successful BDI CI/CD Path

This guide demonstrates the happy path manually:

```text
Jason starts
-> build/test/security/deploy actions run through CicdEnvironment
-> production /health passes
-> Jason opens a production canary observation window
-> Prometheus telemetry remains stable
-> Jason records release_complete
```

This demo does not use `BDI_FORCE_*` failure injection.

## What This Proves

The BDI agent can control the release flow end-to-end using real shell actions and telemetry-derived beliefs.

The important evidence is:

```text
status(build, passed)
status(test, passed)
status(security_scan, passed)
status(deploy(staging), passed)
status(health_check(staging), passed)
status(deploy(production), passed)
status(health_check(production), passed)
observation(production, canary, stable)
decision(release_complete)
```

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
Get-Content .\bdi\logs\cicd_environment.log -Tail 160 -Wait
```

This log is the clearest evidence because it shows:

```text
Jason external actions
shell scripts executed by CicdEnvironment
telemetry polling
percepts added to Jason
record_decision(...) calls made from AgentSpeak plans
```

### Terminal C: Start Jason

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

## What To Watch

First, Jason should execute the CI/CD action chain:

```text
[CicdEnvironment] action ... build.sh candidate
[CicdEnvironment] percept status(build, passed)
[CicdEnvironment] action ... test.sh candidate
[CicdEnvironment] percept status(test, passed)
[CicdEnvironment] action ... security_scan.sh candidate
[CicdEnvironment] percept status(security_scan, passed)
[CicdEnvironment] action ... deploy.sh staging candidate
[CicdEnvironment] percept status(deploy(staging), passed)
[CicdEnvironment] action ... health_check.sh staging
[CicdEnvironment] percept status(health_check(staging), passed)
[CicdEnvironment] action ... deploy.sh production candidate
[CicdEnvironment] percept status(deploy(production), passed)
[CicdEnvironment] action ... health_check.sh production
[CicdEnvironment] percept status(health_check(production), passed)
```

Then Jason should open the timing window:

```text
[CicdEnvironment][decision] observe_production_canary
[CicdEnvironment][observe] start environment=production phase=canary duration_ms=15000
```

During that window, telemetry should remain stable:

```text
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) ... environment=stable
```

At the end of the window:

```text
[CicdEnvironment][observe] complete environment=production phase=canary state=stable
[CicdEnvironment] percept observation(production, canary, stable)
[CicdEnvironment][decision] release_complete
```

## Inspect Jason Beliefs

In another terminal while Jason is still running:

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD\bdi
jason agent mind deployment_agent
```

Expected beliefs include:

```text
status(build,passed)[source(percept)]
status(test,passed)[source(percept)]
status(security_scan,passed)[source(percept)]
status(deploy(production),passed)[source(percept)]
status(health_check(production),passed)[source(percept)]
metric(production,error_rate,normal)[source(percept)]
environment(production,stable)[source(percept)]
observation(production,canary,stable)[source(percept)]
decision(release_complete)[source(self)]
```

## Automated Version

The automation script with the same basename is:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\demo_successful_path.ps1
```

The script automates startup and evidence collection only. It does not choose the BDI decision.

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

