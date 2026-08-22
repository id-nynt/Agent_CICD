#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCENARIO="${1:-}"
RUN_JASON="${2:-}"
BELIEF_DIR="$ROOT_DIR/telemetry/generated_beliefs"
AGENT_TEMPLATE="$ROOT_DIR/bdi/cicd_agent.asl"
GENERATED_DIR="$ROOT_DIR/bdi/generated"

if [ -z "$SCENARIO" ]; then
  echo "Usage: ./bdi/run_agent_for_scenario.sh <scenario_name> [--jason]"
  echo "Example: ./bdi/run_agent_for_scenario.sh success_stable"
  exit 1
fi

BELIEF_FILE="$BELIEF_DIR/$SCENARIO.asl"
if [ ! -f "$BELIEF_FILE" ]; then
  echo "[bdi_runner] missing beliefs: $BELIEF_FILE"
  echo "[bdi_runner] generate them with: ./telemetry/belief_mapper.sh simulation/scenarios/$SCENARIO.yml"
  exit 1
fi

mkdir -p "$GENERATED_DIR"
GENERATED_AGENT="$GENERATED_DIR/${SCENARIO}_agent.asl"
GENERATED_PROJECT="$GENERATED_DIR/${SCENARIO}.mas2j"

{
  echo "// Generated for scenario: $SCENARIO"
  echo "// Source beliefs: $BELIEF_FILE"
  cat "$BELIEF_FILE"
  echo
  cat "$AGENT_TEMPLATE"
} > "$GENERATED_AGENT"

cat > "$GENERATED_PROJECT" <<MAS
MAS ${SCENARIO}_bdi {
  infrastructure: Centralised

  agents:
    ${SCENARIO}_agent;
}
MAS

echo "[bdi_runner] generated agent: $GENERATED_AGENT"
echo "[bdi_runner] generated project: $GENERATED_PROJECT"

has_belief() {
  grep -Fqx "$1" "$BELIEF_FILE"
}

print_modeled_trace() {
  echo
  echo "BDI trace for scenario: $SCENARIO"
  echo "Goal: deliver_release"
  echo "Action: build(candidate)"

  if has_belief "status(build, failed)."; then
    echo "Result: build failed"
    echo "Decision: stop_pipeline"
    return
  fi

  echo "Result: build passed"
  echo "Action: test(candidate)"

  if has_belief "status(test, failed)."; then
    echo "Result: tests failed"
    echo "Decision: stop_pipeline"
    return
  fi

  echo "Result: tests passed"
  echo "Action: security_scan(candidate)"

  if has_belief "status(security_scan, failed)."; then
    echo "Result: security scan failed"
    echo "Decision: stop_pipeline"
    return
  fi

  echo "Result: security scan passed"
  echo "Action: deploy(staging, candidate)"

  if has_belief "status(deploy(staging), failed)."; then
    echo "Result: staging deploy failed"
    echo "Decision: stop_pipeline"
    return
  fi

  echo "Result: staging deploy passed"
  echo "Action: health_check(staging)"

  if has_belief "status(health_check(staging), failed)."; then
    echo "Result: staging health failed"
    echo "Decision: stop_pipeline"
    return
  fi

  echo "Result: staging stable"
  echo "Action: deploy(production, candidate)"

  if has_belief "status(deploy(production), failed)."; then
    echo "Result: production deploy failed"
    echo "Goal: recover_if_failed"
  else
    echo "Result: production deploy passed"
    echo "Action: health_check(production)"
  fi

  if has_belief "status(health_check(production), failed)."; then
    echo "Result: production health failed"
  elif has_belief "status(health_check(production), passed)."; then
    echo "Result: production health passed"
  fi

  echo "Goal: maintain_reliability"

  if has_belief "environment(production, stable)."; then
    echo "Decision: release_complete"
  elif has_belief "network_issue_suspected(true)."; then
    echo "Goal: recover_if_failed"
    echo "Context: network_issue_suspected(true)"
    echo "Action: pause(network_issue_suspected)"
    echo "Action: reobserve(production)"
    echo "Decision: pause_reobserve"
  elif has_belief "reobserve_after_failure(true)."; then
    echo "Goal: recover_if_failed"
    echo "Context: reobserve_after_failure(true)"
    echo "Action: pause(reobserve_before_rollback)"
    echo "Action: reobserve(production)"
    echo "Decision: pause_reobserve"
  elif has_belief "environment(production, unstable)." && has_belief "rollback_available(production)."; then
    echo "Goal: recover_if_failed"
    echo "Action: rollback(production)"
    echo "Decision: rollback_production"
  else
    echo "Goal: recover_if_failed"
    echo "Decision: manual_intervention_required"
  fi

  echo "Goal: record_experiment_result"
  echo "Result: reasoning trace complete"
}

if [ "$RUN_JASON" != "--jason" ]; then
  print_modeled_trace
  exit 0
fi

WINDOWS_JASON_JAR="/c/Program Files/jason-bin-3.3.0/bin/jason"

if [ -f "$WINDOWS_JASON_JAR" ] && command -v java >/dev/null 2>&1; then
  echo "[bdi_runner] running Jason via java -jar"
  export JASON_HOME="${JASON_HOME:-C:\\Program Files\\jason-bin-3.3.0}"
  (cd "$GENERATED_DIR" && java -jar "$WINDOWS_JASON_JAR" "${SCENARIO}.mas2j")
elif command -v jason >/dev/null 2>&1; then
  echo "[bdi_runner] running Jason"
  (cd "$GENERATED_DIR" && jason "${SCENARIO}.mas2j")
else
  echo "[bdi_runner] Jason executable not found; generated files are ready for Jason."
  echo "[bdi_runner] Install Jason or run manually: jason $GENERATED_PROJECT"
fi
