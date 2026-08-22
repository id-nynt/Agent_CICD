scenario(real_high_error_rate).
candidate_version(candidate).
production_version(candidate).
status(build, passed).
status(test, passed).
status(security_scan, passed).
status(deploy(staging), passed).
status(health_check(staging), passed).
status(deploy(production), passed).
status(health_check(production), passed).
metric(production, error_rate, high).
metric(production, latency, normal).
metric(production, availability, high).
environment(staging, stable).
environment(production, unstable).
network_issue_suspected(false).
reobserve_after_failure(false).
expected_traditional_decision(release_success).
expected_bdi_decision(rollback_production).
rollback_available(production).
