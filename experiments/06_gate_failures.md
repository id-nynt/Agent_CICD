# 06 Build/Test/Security Gate Failures

## Purpose

Prove that Jason stops candidate delivery when an early gate fails. This category covers build, test, and security scan.

## BDI Workflow

```text
Jason calls a gate action
-> CicdEnvironment returns a failed status percept
-> deployment_agent.asl sees the failed belief
-> Jason records delivery_failed(candidate, Reason)
-> later deploy stages are not treated as successful delivery
```

## Manual BDI Experiment

Choose one gate:

```powershell
$env:BDI_FORCE_BUILD_FAIL="true"
# or
$env:BDI_FORCE_TEST_FAIL="true"
# or
$env:BDI_FORCE_SECURITY_SCAN_FAIL="true"
```

Then start Jason:

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
docker compose down --remove-orphans
if (Test-Path .\bdi\logs\cicd_environment.log) { Clear-Content .\bdi\logs\cicd_environment.log }

cd .\bdi
$env:BDI_TELEMETRY_ENABLED="false"
$env:BDI_FORCE_BUILD_FAIL="true"
jason project.mas2j
```

Why these settings:

| Setting | Why it is set | What it makes the system do |
| --- | --- | --- |
| `BDI_TELEMETRY_ENABLED=false` | Keeps the test focused on early gate control flow. | Prometheus telemetry does not distract from the gate failure. |
| `BDI_FORCE_BUILD_FAIL=true` | Forces the selected gate to fail in Java. | `CicdEnvironment.java` returns `status(build, failed)` without running the shell script successfully. |
| `BDI_FORCE_TEST_FAIL=true` | Alternative test gate. | Jason receives `status(test, failed)` and should fail delivery. |
| `BDI_FORCE_SECURITY_SCAN_FAIL=true` | Alternative security gate. | Jason receives `status(security_scan, failed)` and should fail delivery. |

Use only one `BDI_FORCE_*` gate variable at a time so the reason is easy to explain.

## Expected BDI Evidence

Build failure:

```text
forced_failure stage=build
percept status(build, failed)
[CicdEnvironment][decision] delivery_failed reason=build_failed
```

Test failure:

```text
forced_failure stage=test
percept status(test, failed)
[CicdEnvironment][decision] delivery_failed reason=test_failed
```

Security failure:

```text
forced_failure stage=security_scan
percept status(security_scan, failed)
[CicdEnvironment][decision] delivery_failed reason=security_failed
```

## Quick BDI Automation

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
powershell -ExecutionPolicy Bypass -File .\experiments\06_gate_failures_bdi.ps1 -Gate build
powershell -ExecutionPolicy Bypass -File .\experiments\06_gate_failures_bdi.ps1 -Gate test
powershell -ExecutionPolicy Bypass -File .\experiments\06_gate_failures_bdi.ps1 -Gate security
```

## Traditional CI/CD Execution

The `BDI_FORCE_*` variables are Java environment test hooks. The shell scripts do not read them. So the traditional script demonstrates that this is specifically a BDI-control-flow test, not a real app telemetry failure.

```powershell
cd C:\NHI\2026_IT-Project\260023_BDI_CICD
powershell -ExecutionPolicy Bypass -File .\experiments\06_gate_failures_traditional.ps1 -Gate build
```

Expected traditional result if the actual shell actions pass:

```text
final_decision=release_complete_fixed_pipeline_if_shell_actions_pass
production_version=candidate
```
