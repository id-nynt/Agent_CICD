scenario(real_security_scan_failure).
candidate_version(candidate).
production_version(stable).
status(build, passed).
status(test, passed).
status(security_scan, failed).
status(deploy(staging), not_run).
status(health_check(staging), not_run).
status(deploy(production), not_run).
status(health_check(production), not_run).
metric(production, error_rate, normal).
metric(production, latency, normal).
metric(production, availability, high).
environment(staging, unstable).
environment(production, stable).
network_issue_suspected(false).
reobserve_after_failure(false).
expected_traditional_decision(stop_pipeline).
expected_bdi_decision(stop_pipeline).
