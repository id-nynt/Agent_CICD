#!/usr/bin/env python3
"""Map scenario, event-log, or Prometheus adapter telemetry into BDI beliefs."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_LOG_DIR = ROOT_DIR / "simulation" / "event_log"
DEFAULT_OUTPUT_DIR = ROOT_DIR / "telemetry" / "generated_beliefs"
DEFAULT_THRESHOLDS = ROOT_DIR / "telemetry" / "thresholds.yml"


def read_thresholds(path: Path) -> dict[str, float]:
    thresholds: dict[str, float] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        key, value = line.split(":", 1)
        thresholds[key.strip()] = float(value.strip())
    return thresholds


def read_simple_yaml(path: Path) -> dict[str, object]:
    """Read the small key/value YAML subset used by this prototype."""
    data: dict[str, object] = {}
    current_section: str | None = None

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.rstrip()
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        if not line.startswith(" ") and stripped.endswith(":"):
            current_section = stripped[:-1]
            data[current_section] = {}
            continue

        if not line.startswith(" ") and ":" in stripped:
            key, value = stripped.split(":", 1)
            data[key.strip()] = parse_scalar(value.strip())
            current_section = None
            continue

        if current_section and ":" in stripped:
            key, value = stripped.split(":", 1)
            section = data[current_section]
            assert isinstance(section, dict)
            section[key.strip()] = parse_scalar(value.strip())

    return data


def parse_scalar(value: str) -> object:
    if value == "true":
        return True
    if value == "false":
        return False
    try:
        if "." in value:
            return float(value)
        return int(value)
    except ValueError:
        return value


def status_name(action_name: str) -> str:
    mapping = {
        "security_scan": "security_scan",
        "deploy_staging": "deploy(staging)",
        "health_check_staging": "health_check(staging)",
        "deploy_production": "deploy(production)",
        "health_check_production": "health_check(production)",
    }
    return mapping.get(action_name, action_name)


def classify_telemetry(
    telemetry: dict[str, float],
    thresholds: dict[str, float],
    environment: str = "production",
) -> tuple[list[str], bool]:
    beliefs: list[str] = []

    error_rate = float(telemetry["error_rate"])
    latency = float(telemetry["latency_p95_ms"])
    availability = float(telemetry["availability"])

    error_state = "high" if error_rate > thresholds["error_rate_high_gt"] else "normal"
    latency_state = "high" if latency > thresholds["latency_p95_ms_high_gt"] else "normal"
    availability_state = "low" if availability < thresholds["availability_low_lt"] else "high"

    beliefs.append(f"metric({environment}, error_rate, {error_state}).")
    beliefs.append(f"metric({environment}, latency, {latency_state}).")
    beliefs.append(f"metric({environment}, availability, {availability_state}).")

    production_unstable = (
        error_state == "high"
        or latency_state == "high"
        or availability_state == "low"
    )
    return beliefs, production_unstable


def map_log_to_beliefs(log: dict, thresholds: dict[str, float]) -> list[str]:
    beliefs: list[str] = []

    scenario = log["scenario"]
    candidate = log["candidate_version"]
    final_production = log["final_production_version"]
    context = log["context"]

    beliefs.append(f"scenario({scenario}).")
    beliefs.append(f"candidate_version({candidate}).")
    beliefs.append(f"production_version({final_production}).")

    for action in log["actions"]:
        name = action["name"]
        if name in {"reset", "rollback_production", "reobserve_production"}:
            continue
        actual = action["actual"]
        if actual in {"passed", "failed", "not_run"}:
            beliefs.append(f"status({status_name(name)}, {actual}).")

    metric_beliefs, production_unstable = classify_telemetry(log["telemetry"], thresholds)
    beliefs.extend(metric_beliefs)

    staging_health = find_action_status(log, "health_check_staging")
    production_health = find_action_status(log, "health_check_production")

    beliefs.append(f"environment(staging, {'stable' if staging_health == 'passed' else 'unstable'}).")
    beliefs.append(f"environment(production, {'unstable' if production_unstable or production_health == 'failed' else 'stable'}).")
    beliefs.append(f"network_issue_suspected({str(context['network_issue_suspected']).lower()}).")
    beliefs.append(f"reobserve_after_failure({str(context['reobserve_after_failure']).lower()}).")
    beliefs.append(f"decision({log['final_decision']}).")
    beliefs.append(f"expected_traditional_decision({log['expected']['traditional_decision']}).")
    beliefs.append(f"expected_bdi_decision({log['expected']['bdi_decision']}).")

    if any(action["name"] == "rollback_production" for action in log["actions"]):
        beliefs.append("rollback_available(production).")

    return beliefs


def is_adapter_json(data: dict) -> bool:
    telemetry = data.get("telemetry")
    return (
        isinstance(telemetry, dict)
        and "environment" in data
        and "scenario" not in data
        and {"error_rate", "latency_p95_ms", "availability"}.issubset(telemetry)
    )


def map_adapter_to_beliefs(data: dict, thresholds: dict[str, float]) -> list[str]:
    environment = str(data["environment"])
    if environment not in {"staging", "production"}:
        raise ValueError("adapter environment must be staging or production")

    metric_beliefs, unstable = classify_telemetry(data["telemetry"], thresholds, environment)
    environment_state = "unstable" if unstable else "stable"

    beliefs = [
        f"telemetry_source({data.get('source', 'prometheus')}).",
        f"telemetry_environment({environment}).",
    ]
    beliefs.extend(metric_beliefs)
    beliefs.append(f"environment({environment}, {environment_state}).")
    return beliefs


def scenario_to_log(scenario: dict[str, object]) -> dict:
    stages = scenario["stages"]
    release = scenario["release"]
    initial_state = scenario["initial_state"]
    assert isinstance(stages, dict)
    assert isinstance(release, dict)
    assert isinstance(initial_state, dict)

    candidate = str(release["candidate_version"])
    stable = str(initial_state["stable_version"])
    final_decision = "release_success"
    final_production = candidate
    actions: list[dict[str, str]] = []

    def add_action(name: str, expected: str, actual: str, mode: str, detail: str) -> None:
        actions.append({
            "name": name,
            "expected": expected,
            "actual": actual,
            "mode": mode,
            "detail": detail,
        })

    add_action("reset", "passed", "passed", "scenario_model", f"Runtime starts with {stable} in production.")

    stage_order = [
        ("build", "build"),
        ("test", "test"),
        ("security_scan", "security_scan"),
        ("staging_deploy", "deploy_staging"),
        ("staging_health", "health_check_staging"),
        ("production_deploy", "deploy_production"),
        ("production_health", "health_check_production"),
    ]

    for stage_key, action_name in stage_order:
        expected = str(stages[stage_key])
        if expected == "not_run":
            add_action(action_name, expected, "not_run", "scenario_control", "Stage not reached.")
            continue
        if expected == "failed":
            add_action(action_name, expected, "failed", "scenario_control", "Scenario marks this stage as failed.")
            if stage_key in {"production_deploy", "production_health"}:
                final_decision = "rollback_expected"
                final_production = candidate if stage_key == "production_health" else stable
                add_action("rollback_production", "expected_by_traditional_decision", "not_executed", "expectation_only", "Rollback expected from scenario data.")
            else:
                final_decision = "stop_pipeline"
                final_production = stable
            break

        add_action(action_name, expected, "passed", "scenario_control", "Scenario marks this stage as passed.")

    context = scenario["context"]
    if isinstance(context, dict) and context.get("reobserve_after_failure") is True:
        add_action("reobserve_production", "expected_by_bdi_decision", "recorded", "simulated_context", "Scenario includes updated telemetry.")

    return {
        "scenario": scenario["name"],
        "candidate_version": candidate,
        "actions": actions,
        "telemetry": scenario["telemetry"],
        "context": context,
        "expected": {
            "traditional_decision": scenario["expected"]["traditional_decision"],
            "bdi_decision": scenario["expected"]["bdi_decision"],
        },
        "final_decision": final_decision,
        "final_production_version": final_production,
        "success": True,
    }


def find_action_status(log: dict, action_name: str) -> str:
    for action in log["actions"]:
        if action["name"] == action_name:
            return action["actual"]
    return "not_run"


def read_json_file(path: Path) -> dict:
    raw = path.read_bytes()
    for encoding in ("utf-8", "utf-8-sig", "utf-16"):
        try:
            return json.loads(raw.decode(encoding))
        except (UnicodeDecodeError, json.JSONDecodeError):
            continue
    raise ValueError(f"could not read JSON from {path}")


def write_belief_file(input_file: Path, output_dir: Path, thresholds: dict[str, float]) -> Path:
    if input_file.suffix.lower() in {".yml", ".yaml"}:
        log = scenario_to_log(read_simple_yaml(input_file))
        beliefs = map_log_to_beliefs(log, thresholds)
        output_name = log["scenario"]
    else:
        data = read_json_file(input_file)
        if is_adapter_json(data):
            beliefs = map_adapter_to_beliefs(data, thresholds)
            output_name = f"{data['environment']}_live"
        else:
            log = data
            beliefs = map_log_to_beliefs(log, thresholds)
            output_name = log["scenario"]
    output_dir.mkdir(parents=True, exist_ok=True)
    output_file = output_dir / f"{output_name}.asl"
    output_file.write_text("\n".join(beliefs) + "\n", encoding="utf-8")
    return output_file


def input_files(path: Path) -> list[Path]:
    if path.is_dir():
        return sorted([*path.glob("*.json"), *path.glob("*.yml"), *path.glob("*.yaml")])
    return [path]


def main() -> int:
    parser = argparse.ArgumentParser(description="Map scenario YAML, event log JSON, or Prometheus adapter JSON into BDI belief files.")
    parser.add_argument("input", nargs="?", default=str(DEFAULT_LOG_DIR), help="Scenario YAML, event log JSON, Prometheus adapter JSON, or directory.")
    parser.add_argument("--thresholds", default=str(DEFAULT_THRESHOLDS), help="Threshold configuration file.")
    parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT_DIR), help="Directory for generated .asl beliefs.")
    args = parser.parse_args()

    thresholds = read_thresholds(Path(args.thresholds))
    outputs = [
        write_belief_file(path, Path(args.output_dir), thresholds)
        for path in input_files(Path(args.input))
    ]

    for output in outputs:
        print(f"[belief_mapper] PASS: wrote {output}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
