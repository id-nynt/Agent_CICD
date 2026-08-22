scenario(rollback_midway_recovery).
candidate_version(candidate).
production_version(candidate).
status(build, passed).
status(test, passed).
status(security_scan, passed).
status(deploy(staging), passed).
status(health_check(staging), passed).
status(deploy(production), passed).
status(health_check(production), failed).
metric(production, error_rate, high).
metric(production, latency, high).
metric(production, availability, low).
environment(staging, stable).
environment(production, unstable).
network_issue_suspected(false).
reobserve_after_failure(true).
decision(rollback_expected).
expected_traditional_decision(rollback).
expected_bdi_decision(pause_or_reobserve_before_rollback).
rollback_available(production).
