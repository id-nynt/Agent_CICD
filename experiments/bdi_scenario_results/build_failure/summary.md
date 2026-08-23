# build_failure

Capability: Stop the release at the build gate before any deployment action.

Result: PASS

Success criteria: Jason perceives build failure and stops before staging or production deploy.

## Expected Beliefs

```text
status(build,failed): True
decision(stop_pipeline): True
stop_reason(build_failed): True
```

## Agent Mind

```text
Agent mind capture skipped by suite automation. Use 'jason agent mind deployment_agent' while the MAS is running for live belief inspection.
```

## Environment Log Tail

```text
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment][telemetry] thresholds error_rate_high_gt=0.05 latency_p95_ms_high_gt=500.0 availability_low_lt=0.99
[CicdEnvironment] root=C:\NHI\2026_IT-Project\260023_BDI_CICD
[CicdEnvironment] bash=C:\Program Files\Git\bin\bash.exe
[CicdEnvironment] prometheus_url=http://localhost:9090
[CicdEnvironment][telemetry] disabled by BDI_TELEMETRY_ENABLED
[CicdEnvironment] forced_failure stage=build env=BDI_FORCE_BUILD_FAIL
[CicdEnvironment] percept status(build, failed)
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment][decision] stop_pipeline reason=build_failed
```
