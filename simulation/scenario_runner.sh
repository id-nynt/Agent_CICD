#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCENARIO_DIR="$ROOT_DIR/simulation/scenarios"
LOG_DIR="$ROOT_DIR/simulation/event_log"
mkdir -p "$LOG_DIR"

usage() {
  cat <<'USAGE'
Usage:
  ./simulation/scenario_runner.sh simulation/scenarios/success_stable.yml
  ./simulation/scenario_runner.sh --all
USAGE
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

yaml_get() {
  local file="$1"
  local section="$2"
  local key="$3"
  awk -v section="$section" -v key="$key" '
    /^[[:space:]]*#/ { next }
    /^[^[:space:]][^:]*:/ {
      current=$1
      sub(":", "", current)
    }
    current == section && $1 == key ":" {
      $1=""
      sub(/^[[:space:]]*/, "")
      print
      exit
    }
  ' "$file" | tr -d '\r'
}

yaml_root_get() {
  local file="$1"
  local key="$2"
  awk -v key="$key" '
    /^[[:space:]]*#/ { next }
    $1 == key ":" {
      $1=""
      sub(/^[[:space:]]*/, "")
      print
      exit
    }
  ' "$file" | tr -d '\r'
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '%s' "$value"
}

print_step() {
  local name="$1"
  local status="$2"
  local detail="$3"
  printf '  - %-24s %s' "$name" "$status"
  if [ -n "$detail" ]; then
    printf ' | %s' "$detail"
  fi
  printf '\n'
}

print_next() {
  local detail="$1"
  printf '    next: %s\n' "$detail"
}

write_log() {
  local log_file="$1"
  local scenario="$2"
  local candidate="$3"
  local traditional="$4"
  local bdi="$5"
  local final_decision="$6"
  local success="$7"
  local final_production="$8"
  local actions_json="$9"
  local telemetry_json="${10}"
  local context_json="${11}"

  cat > "$log_file" <<JSON
{
  "scenario": "$(json_escape "$scenario")",
  "candidate_version": "$(json_escape "$candidate")",
  "actions": $actions_json,
  "telemetry": $telemetry_json,
  "context": $context_json,
  "expected": {
    "traditional_decision": "$(json_escape "$traditional")",
    "bdi_decision": "$(json_escape "$bdi")"
  },
  "final_decision": "$(json_escape "$final_decision")",
  "final_production_version": "$(json_escape "$final_production")",
  "success": $success
}
JSON
}

append_action() {
  local name="$1"
  local expected="$2"
  local actual="$3"
  local mode="$4"
  local detail="$5"
  local entry
  entry="{\"name\":\"$(json_escape "$name")\",\"expected\":\"$(json_escape "$expected")\",\"actual\":\"$(json_escape "$actual")\",\"mode\":\"$(json_escape "$mode")\",\"detail\":\"$(json_escape "$detail")\"}"
  if [ "$ACTIONS_JSON" = "[]" ]; then
    ACTIONS_JSON="[$entry]"
  else
    ACTIONS_JSON="${ACTIONS_JSON%]},""$entry""]"
  fi
}

run_action_if_passed() {
  local action_name="$1"
  local expected="$2"
  local success_next="$3"
  local fail_next="$4"
  shift 2
  shift 2

  if [ "$expected" = "passed" ]; then
    if output="$("$@" 2>&1)"; then
      append_action "$action_name" "$expected" "passed" "real_action" "$output"
      print_step "$action_name" "PASS" "$output"
      if [ -n "$success_next" ]; then
        print_next "$success_next"
      fi
      return 0
    fi
    append_action "$action_name" "$expected" "failed" "real_action" "$output"
    print_step "$action_name" "FAIL" "$output"
    if [ -n "$fail_next" ]; then
      print_next "$fail_next"
    fi
    return 1
  fi

  if [ "$expected" = "failed" ]; then
    local detail="Scenario marks this stage as failed."
    append_action "$action_name" "$expected" "failed" "simulated_outcome" "$detail"
    print_step "$action_name" "FAIL" "$detail"
    if [ -n "$fail_next" ]; then
      print_next "$fail_next"
    fi
    return 1
  fi

  append_action "$action_name" "$expected" "not_run" "scenario_control" "Stage not reached."
  print_step "$action_name" "SKIP" "Stage not reached."
  return 2
}

run_scenario() {
  local scenario_file="$1"

  if [ ! -f "$scenario_file" ]; then
    echo "[scenario_runner] FAIL: scenario file not found: $scenario_file"
    return 1
  fi

  local name candidate stable_version expected_traditional expected_bdi
  name="$(yaml_root_get "$scenario_file" "name")"
  stable_version="$(yaml_get "$scenario_file" "initial_state" "stable_version")"
  candidate="$(yaml_get "$scenario_file" "release" "candidate_version")"
  expected_traditional="$(yaml_get "$scenario_file" "expected" "traditional_decision")"
  expected_bdi="$(yaml_get "$scenario_file" "expected" "bdi_decision")"

  local build_status test_status security_status staging_deploy staging_health production_deploy production_health
  build_status="$(yaml_get "$scenario_file" "stages" "build")"
  test_status="$(yaml_get "$scenario_file" "stages" "test")"
  security_status="$(yaml_get "$scenario_file" "stages" "security_scan")"
  staging_deploy="$(yaml_get "$scenario_file" "stages" "staging_deploy")"
  staging_health="$(yaml_get "$scenario_file" "stages" "staging_health")"
  production_deploy="$(yaml_get "$scenario_file" "stages" "production_deploy")"
  production_health="$(yaml_get "$scenario_file" "stages" "production_health")"

  local error_rate latency availability network_issue reobserve
  error_rate="$(yaml_get "$scenario_file" "telemetry" "error_rate")"
  latency="$(yaml_get "$scenario_file" "telemetry" "latency_p95_ms")"
  availability="$(yaml_get "$scenario_file" "telemetry" "availability")"
  network_issue="$(yaml_get "$scenario_file" "context" "network_issue_suspected")"
  reobserve="$(yaml_get "$scenario_file" "context" "reobserve_after_failure")"

  ACTIONS_JSON="[]"

  echo
  echo "Scenario: $name"
  echo "  stable version: $stable_version"
  echo "  candidate version: $candidate"
  echo "  expected traditional decision: $expected_traditional"
  echo "  expected BDI decision: $expected_bdi"
  echo "  telemetry: error_rate=$error_rate, latency_p95_ms=$latency, availability=$availability"
  echo "  context: network_issue_suspected=$network_issue, reobserve_after_failure=$reobserve"
  echo "  steps:"

  "$ROOT_DIR/cicd/actions/reset.sh" >/dev/null
  append_action "reset" "passed" "passed" "real_action" "Runtime reset with $stable_version in production."
  print_step "reset" "PASS" "Runtime reset with $stable_version in production."
  print_next "build candidate"

  local final_decision="release_success"

  run_action_if_passed "build" "$build_status" "run tests for $candidate" "stop pipeline before tests" "$ROOT_DIR/cicd/actions/build.sh" "$candidate" || final_decision="stop_pipeline"
  if [ "$final_decision" = "release_success" ]; then
    run_action_if_passed "test" "$test_status" "run security scan for $candidate" "stop pipeline before security scan and production remains $stable_version" "$ROOT_DIR/cicd/actions/test.sh" "$candidate" || final_decision="stop_pipeline"
  fi
  if [ "$final_decision" = "release_success" ]; then
    run_action_if_passed "security_scan" "$security_status" "deploy $candidate to staging" "stop pipeline before staging deploy" "$ROOT_DIR/cicd/actions/security_scan.sh" "$candidate" || final_decision="stop_pipeline"
  fi
  if [ "$final_decision" = "release_success" ]; then
    run_action_if_passed "deploy_staging" "$staging_deploy" "$candidate deployed to staging; run staging health check" "stop pipeline before staging health check" "$ROOT_DIR/cicd/actions/deploy.sh" "staging" "$candidate" || final_decision="stop_pipeline"
  fi
  if [ "$final_decision" = "release_success" ]; then
    run_action_if_passed "health_check_staging" "$staging_health" "deploy $candidate to production" "stop pipeline before production deploy and production remains $stable_version" "$ROOT_DIR/cicd/actions/health_check.sh" "staging" || final_decision="stop_pipeline"
  fi
  if [ "$final_decision" = "release_success" ]; then
    run_action_if_passed "deploy_production" "$production_deploy" "$candidate deployed to production; run production health check" "record rollback expectation to $stable_version" "$ROOT_DIR/cicd/actions/deploy.sh" "production" "$candidate" || final_decision="rollback_expected"
  fi
  if [ "$final_decision" = "release_success" ]; then
    run_action_if_passed "health_check_production" "$production_health" "release successful; production remains $candidate" "record rollback expectation to $stable_version" "$ROOT_DIR/cicd/actions/health_check.sh" "production" || final_decision="rollback_expected"
  fi

  if [ "$final_decision" = "rollback_expected" ]; then
    append_action "rollback_production" "expected_by_traditional_decision" "not_executed" "expectation_only" "Phase 2 records rollback expectation; recovery execution belongs to later decision layers."
    print_step "rollback_production" "NEXT" "Rollback to $stable_version is expected by the traditional decision, but not executed in Phase 2."
  fi

  if [ "$reobserve" = "true" ]; then
    append_action "reobserve_production" "expected_by_bdi_decision" "recorded" "simulated_context" "Scenario includes updated telemetry for a later BDI reasoning phase."
    print_step "reobserve_production" "NEXT" "BDI phase should reobserve production before final recovery decision."
  fi

  local final_production="unknown"
  if [ -f "$ROOT_DIR/runtime/state/production_version.txt" ]; then
    final_production="$(tr -d '\r\n' < "$ROOT_DIR/runtime/state/production_version.txt")"
  fi

  local success="true"
  case "$name" in
    success_stable)
      [ "$final_decision" = "release_success" ] && [ "$final_production" = "$candidate" ] || success="false"
      ;;
    production_unstable|rollback_midway_recovery|network_issue_suspected)
      [ "$final_decision" = "rollback_expected" ] || success="false"
      ;;
    stage_failure)
      [ "$final_decision" = "stop_pipeline" ] && [ "$final_production" = "$stable_version" ] || success="false"
      ;;
    *)
      success="false"
      ;;
  esac

  local telemetry_json context_json log_file
  telemetry_json="{\"error_rate\":$error_rate,\"latency_p95_ms\":$latency,\"availability\":$availability}"
  context_json="{\"network_issue_suspected\":$network_issue,\"reobserve_after_failure\":$reobserve}"
  log_file="$LOG_DIR/${name}.json"

  write_log "$log_file" "$name" "$candidate" "$expected_traditional" "$expected_bdi" "$final_decision" "$success" "$final_production" "$ACTIONS_JSON" "$telemetry_json" "$context_json"

  echo "  final decision: $final_decision"
  echo "  final production version: $final_production"
  echo "  event log: $log_file"
  echo "[scenario_runner] PASS: $name"
  [ "$success" = "true" ]
}

if [ "${1:-}" = "" ]; then
  usage
  exit 1
fi

if [ "$1" = "--all" ]; then
  failed=0
  for scenario in "$SCENARIO_DIR"/*.yml; do
    if ! run_scenario "$scenario"; then
      failed=1
    fi
  done
  exit "$failed"
fi

run_scenario "$1"
