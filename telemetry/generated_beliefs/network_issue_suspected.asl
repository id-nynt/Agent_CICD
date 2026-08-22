scenario(network_issue_suspected).
candidate_version(candidate).
production_version(candidate).
status(build, passed).
status(test, passed).
status(security_scan, passed).
status(deploy(staging), passed).
status(health_check(staging), passed).
status(deploy(production), passed).
status(health_check(production), failed).
metric(production, error_rate, normal).
metric(production, latency, high).
metric(production, availability, low).
environment(staging, stable).
environment(production, unstable).
network_issue_suspected(true).
reobserve_after_failure(true).
decision(rollback_expected).
expected_traditional_decision(rollback).
expected_bdi_decision(pause_reobserve_then_decide).
rollback_available(production).
