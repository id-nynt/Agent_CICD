// Persistent BDI CI/CD deployment controller.
//
// This agent is the plain Jason controller for the local CI/CD prototype.
// It invokes real shell actions through CicdEnvironment and reacts to the
// resulting percepts. Prometheus telemetry is also perceived periodically by
// CicdEnvironment and can trigger reliability recovery plans while the agent
// remains alive.

controller_mode(persistent).
candidate(candidate).

!start_controller.

+environment(production, unstable)
  : status(deploy(production), passed) & not recovery_attempted(production)
  <- .print("[deployment_agent][event] +environment(production, unstable)");
     !recover_production(telemetry_unstable).

+!start_controller
  <- .print("[deployment_agent] started");
     .print("[deployment_agent] adopting !deliver_release(candidate)");
     !deliver_release(candidate).

// Root goal: deliver a candidate release while preserving production reliability.
+!deliver_release(Candidate)
  <- .print("[deployment_agent][goal] !deliver_release(", Candidate, ")");
     !prepare_candidate(Candidate);
     !validate_candidate(Candidate);
     !deploy_to_staging(Candidate);
     !verify_staging;
     !deploy_to_production(Candidate);
     !verify_production;
     !maintain_reliability.

// Build preparation.
+!prepare_candidate(Candidate)
  <- .print("[deployment_agent][subgoal] !prepare_candidate(", Candidate, ")");
     !run_build(Candidate).

+!run_build(Candidate)
  <- .print("[deployment_agent][plan] build candidate");
     build(Candidate);
     .wait(250);
     !handle_build_result.

+!handle_build_result
  : status(build, passed)
  <- .print("[deployment_agent][belief] status(build, passed)").

+!handle_build_result
  : status(build, failed)
  <- .print("[deployment_agent][belief] status(build, failed)");
     !stop_release(build_failed).

// Candidate validation.
+!validate_candidate(Candidate)
  <- .print("[deployment_agent][subgoal] !validate_candidate(", Candidate, ")");
     !run_tests(Candidate);
     !run_security_scan(Candidate).

+!run_tests(Candidate)
  <- .print("[deployment_agent][plan] test candidate");
     test(Candidate);
     .wait(250);
     !handle_test_result.

+!handle_test_result
  : status(test, passed)
  <- .print("[deployment_agent][belief] status(test, passed)").

+!handle_test_result
  : status(test, failed)
  <- .print("[deployment_agent][belief] status(test, failed)");
     !stop_release(test_failed).

+!run_security_scan(Candidate)
  <- .print("[deployment_agent][plan] security scan candidate");
     security_scan(Candidate);
     .wait(250);
     !handle_security_scan_result.

+!handle_security_scan_result
  : status(security_scan, passed)
  <- .print("[deployment_agent][belief] status(security_scan, passed)").

+!handle_security_scan_result
  : status(security_scan, failed)
  <- .print("[deployment_agent][belief] status(security_scan, failed)");
     !stop_release(security_failed).

// Staging deployment gate.
+!deploy_to_staging(Candidate)
  <- .print("[deployment_agent][subgoal] !deploy_to_staging(", Candidate, ")");
     deploy(Candidate, staging);
     .wait(250);
     !handle_staging_deploy_result.

+!handle_staging_deploy_result
  : status(deploy(staging), passed)
  <- .print("[deployment_agent][belief] status(deploy(staging), passed)").

+!handle_staging_deploy_result
  : status(deploy(staging), failed)
  <- .print("[deployment_agent][belief] status(deploy(staging), failed)");
     !stop_release(staging_deploy_failed).

+!verify_staging
  <- .print("[deployment_agent][subgoal] !verify_staging");
     health_check(staging);
     .wait(250);
     !handle_staging_health_result.

+!handle_staging_health_result
  : status(health_check(staging), passed) & environment(staging, stable)
  <- .print("[deployment_agent][belief] staging stable").

+!handle_staging_health_result
  <- .print("[deployment_agent][belief] staging unstable");
     !stop_release(staging_unstable).

// Production deployment gate.
+!deploy_to_production(Candidate)
  <- .print("[deployment_agent][subgoal] !deploy_to_production(", Candidate, ")");
     deploy(Candidate, production);
     .wait(250);
     !handle_production_deploy_result.

+!handle_production_deploy_result
  : status(deploy(production), passed)
  <- .print("[deployment_agent][belief] status(deploy(production), passed)").

+!handle_production_deploy_result
  : status(deploy(production), failed)
  <- .print("[deployment_agent][belief] status(deploy(production), failed)");
     !recover_production(deploy_failed);
     !keep_alive.

+!verify_production
  <- .print("[deployment_agent][subgoal] !verify_production");
     health_check(production);
     .wait(250);
     !handle_production_health_result.

+!handle_production_health_result
  : status(health_check(production), passed)
  <- .print("[deployment_agent][belief] status(health_check(production), passed)").

+!handle_production_health_result
  : status(health_check(production), failed)
  <- .print("[deployment_agent][belief] status(health_check(production), failed)");
     !recover_production(health_failed).

// Reliability goal.
+!maintain_reliability
  : environment(production, stable)
  <- .print("[deployment_agent][goal] !maintain_reliability");
     .print("[deployment_agent][decision] release_complete");
     .print("[deployment_agent] release complete");
     !keep_alive.

+!maintain_reliability
  : environment(production, unstable)
  <- .print("[deployment_agent][goal] !maintain_reliability");
     !recover_production(production_unstable);
     !keep_alive.

+!maintain_reliability
  <- .print("[deployment_agent][goal] !maintain_reliability");
     .print("[deployment_agent][decision] reliability_unknown");
     !keep_alive.

+!recover_production(Reason)
  <- .print("[deployment_agent][goal] !recover_production(", Reason, ")");
     +recovery_attempted(production);
     rollback(production);
     .wait(250);
     !handle_rollback_result.

+!handle_rollback_result
  : status(rollback(production), passed)
  <- .print("[deployment_agent][belief] status(rollback(production), passed)");
     .print("[deployment_agent][decision] rollback_production");
     !keep_alive.

+!handle_rollback_result
  : status(rollback(production), failed)
  <- .print("[deployment_agent][belief] status(rollback(production), failed)");
     .print("[deployment_agent][decision] manual_intervention_required");
     !keep_alive.

+!stop_release(Reason)
  <- .print("[deployment_agent][decision] stop_pipeline");
     .print("[deployment_agent][reason] ", Reason);
     !keep_alive.

// Keep the MAS alive for future dynamic perception phases.
+!keep_alive
  <- .wait(5000);
     .print("[deployment_agent] alive: waiting for real perceptions/actions");
     !keep_alive.
