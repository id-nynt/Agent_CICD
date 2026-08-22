scenario(stage_failure).
candidate_version(candidate).
production_version(stable).
status(build, passed).
status(test, failed).
metric(production, error_rate, normal).
metric(production, latency, normal).
metric(production, availability, high).
environment(staging, unstable).
environment(production, stable).
network_issue_suspected(false).
reobserve_after_failure(false).
decision(stop_pipeline).
expected_traditional_decision(stop_pipeline).
expected_bdi_decision(abandon_release_or_request_fix).
