# BDI Goal Model

The active BDI controller is:

```text
bdi/deployment_agent.asl
```

It runs in:

```text
bdi/project.mas2j
```

with:

```text
bdi/src/env/CicdEnvironment.java
```

## Beliefs

Static startup beliefs:

```prolog
controller_mode(persistent).
candidate(candidate).
```

Action-result percepts from `CicdEnvironment`:

```prolog
status(build, passed).
status(test, passed).
status(security_scan, passed).
status(deploy(staging), passed).
status(health_check(production), passed).
status(rollback(production), passed).
```

Telemetry percepts from Prometheus polling:

```prolog
metric(production, error_rate, high).
metric(production, latency, high).
metric(production, availability, low).
environment(production, unstable).
telemetry(production, unavailable).
network(production, suspected).
```

Decision beliefs asserted by the agent:

```prolog
decision(release_complete).
decision(stop_pipeline).
decision(rollback_production).
decision(pause_reobserve).
decision(reobserve_recovered).
decision(manual_intervention_required).
```

## Desire / Root Goal

The root goal is:

```prolog
!deliver_release(candidate)
```

Goal decomposition:

```text
!deliver_release
  -> !prepare_candidate
  -> !validate_candidate
  -> !deploy_to_staging
  -> !verify_staging
  -> !deploy_to_production
  -> !verify_production
  -> !maintain_reliability
```

## Intentions / Plans

The normal release path calls external actions:

```prolog
build(Candidate)
test(Candidate)
security_scan(Candidate)
deploy(Candidate, staging)
health_check(staging)
deploy(Candidate, production)
health_check(production)
```

Stop-release plans apply when build/test/security/staging gates fail:

```prolog
!stop_release(build_failed)
!stop_release(test_failed)
!stop_release(security_failed)
!stop_release(staging_unstable)
```

Production recovery plans apply when production deployment, health, or telemetry becomes unstable:

```prolog
!recover_production(deploy_failed)
!recover_production(health_failed)
!recover_production(telemetry_unstable)
```

Ambiguous situations use:

```prolog
!pause_reobserve(high_latency)
!pause_reobserve(network_suspected)
```

## Why This Is BDI Evidence

The evidence is not just a script printing a decision. In the persistent path:

1. Jason adopts goals from `deployment_agent.asl`.
2. Jason calls external actions such as `deploy(candidate, production)`.
3. `CicdEnvironment` executes the public shell action.
4. `CicdEnvironment` adds percepts from action results and telemetry.
5. AgentSpeak context conditions select different plans.
6. Jason invokes follow-up actions such as `rollback(production)`.

The scenario runner can configure stimuli and collect logs, but it does not choose `rollback_production`, `pause_reobserve`, `stop_pipeline`, or `manual_intervention_required`.

## Limitations

The current agent is single-agent and local. It has simple deterministic plans, no plan ranking by utility, no learning, no persistent event store, and no CArtAgO/JaCaMo artifacts.
