// First BDI CI/CD release agent.
// Scenario beliefs are prepended by run_agent_for_scenario.sh.

!deliver_release.

// Root goal: deliver the release while preserving reliability.
+!deliver_release
  <- .print("Goal: deliver_release");
     !prepare_candidate;
     !validate_candidate;
     !deploy_to_staging;
     !verify_staging;
     !deploy_to_production;
     !verify_production;
     !maintain_reliability;
     !record_experiment_result.

// Build is modeled from the current symbolic belief state.
+!prepare_candidate : status(build, passed)
  <- .print("Action: build(candidate)");
     .print("Result: build passed").

+!prepare_candidate : status(build, failed)
  <- .print("Action: build(candidate)");
     .print("Result: build failed");
     !stop_release(build_failed).

// Candidate validation includes tests and security scan.
+!validate_candidate : status(test, passed) & status(security_scan, passed)
  <- .print("Action: test(candidate)");
     .print("Result: tests passed");
     .print("Action: security_scan(candidate)");
     .print("Result: security scan passed").

+!validate_candidate : status(test, failed)
  <- .print("Action: test(candidate)");
     .print("Result: tests failed");
     !stop_release(test_failed).

+!validate_candidate : status(security_scan, failed)
  <- .print("Action: security_scan(candidate)");
     .print("Result: security scan failed");
     !stop_release(security_failed).

// Staging deployment and verification gate production.
+!deploy_to_staging : status(deploy(staging), passed)
  <- .print("Action: deploy(staging, candidate)");
     .print("Result: staging deploy passed").

+!deploy_to_staging : status(deploy(staging), failed)
  <- .print("Action: deploy(staging, candidate)");
     .print("Result: staging deploy failed");
     !stop_release(staging_deploy_failed).

+!verify_staging : status(health_check(staging), passed) & environment(staging, stable)
  <- .print("Action: health_check(staging)");
     .print("Result: staging stable").

+!verify_staging : status(health_check(staging), failed)
  <- .print("Action: health_check(staging)");
     .print("Result: staging health failed");
     !stop_release(staging_health_failed).

// Production deployment is allowed only after earlier gates are satisfied.
+!deploy_to_production : status(deploy(production), passed)
  <- .print("Action: deploy(production, candidate)");
     .print("Result: production deploy passed").

+!deploy_to_production : status(deploy(production), failed)
  <- .print("Action: deploy(production, candidate)");
     .print("Result: production deploy failed");
     !recover_if_failed.

+!verify_production : status(health_check(production), passed)
  <- .print("Action: health_check(production)");
     .print("Result: production health passed").

+!verify_production : status(health_check(production), failed)
  <- .print("Action: health_check(production)");
     .print("Result: production health failed").

// Reliability goal: decide whether production is acceptable after deployment.
+!maintain_reliability : environment(production, stable)
  <- .print("Goal: maintain_reliability");
     .print("Decision: release_complete").

+!maintain_reliability : environment(production, unstable)
  <- .print("Goal: maintain_reliability");
     !recover_if_failed.

// Recovery goal: pause/reobserve when the context suggests uncertainty.
+!recover_if_failed : network_issue_suspected(true)
  <- .print("Goal: recover_if_failed");
     .print("Context: network_issue_suspected(true)");
     .print("Action: pause(network_issue_suspected)");
     .print("Action: reobserve(production)");
     .print("Decision: pause_reobserve").

+!recover_if_failed : reobserve_after_failure(true)
  <- .print("Goal: recover_if_failed");
     .print("Context: reobserve_after_failure(true)");
     .print("Action: pause(reobserve_before_rollback)");
     .print("Action: reobserve(production)");
     .print("Decision: pause_reobserve").

+!recover_if_failed : environment(production, unstable) & rollback_available(production)
  <- .print("Goal: recover_if_failed");
     .print("Action: rollback(production)");
     .print("Decision: rollback_production").

+!recover_if_failed : environment(production, unstable)
  <- .print("Goal: recover_if_failed");
     .print("Decision: manual_intervention_required").

// Pre-production failures preserve production and stop delivery.
+!stop_release(Reason)
  <- .print("Decision: stop_pipeline");
     .print("Reason: ", Reason).

// Experiment-result recording is currently symbolic and local to the agent trace.
+!record_experiment_result
  <- .print("Goal: record_experiment_result");
     .print("Result: reasoning trace complete");
     .stopMAS.
