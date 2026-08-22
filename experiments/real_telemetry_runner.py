#!/usr/bin/env python3
"""Run scenario-driven real-telemetry CI/CD experiments."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


ROOT_DIR = Path(__file__).resolve().parents[1]
SCENARIO_FILE = ROOT_DIR / "experiments" / "real_scenarios.yml"
REAL_RESULT_DIR = ROOT_DIR / "experiments" / "real_results"
REAL_COMPARISON_TABLE = ROOT_DIR / "experiments" / "real_comparison_table.md"
BELIEF_DIR = ROOT_DIR / "telemetry" / "generated_beliefs"
LIVE_DIR = ROOT_DIR / "telemetry" / "live"

PROMETHEUS_URL = "http://localhost:9090"
DEFAULT_TRAFFIC_COUNT = 8
ZERO_TELEMETRY = {"error_rate": 0.0, "latency_p95_ms": 0.0, "availability": 1.0}

sys.path.insert(0, str(ROOT_DIR / "telemetry"))
import belief_mapper  # noqa: E402
import prometheus_adapter  # noqa: E402


class ScenarioError(ValueError):
    """Raised when real_scenarios.yml is missing required experiment data."""


def bash_command() -> str:
    git_bash = Path("C:/Program Files/Git/bin/bash.exe")
    if git_bash.exists():
        return str(git_bash)
    found = shutil.which("bash")
    if found:
        return found
    raise RuntimeError("Bash not found. Install Git Bash or run from an environment with bash.")


def run_command(args: list[str], env: dict[str, str] | None = None, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        args,
        cwd=ROOT_DIR,
        env=env,
        check=check,
        capture_output=True,
        text=True,
    )


def run_action(*args: str, env: dict[str, str] | None = None, check: bool = True) -> subprocess.CompletedProcess:
    script = ROOT_DIR / "cicd" / "actions" / f"{args[0]}.sh"
    return run_command([bash_command(), str(script), *args[1:]], env=env, check=check)


def action_record(action: str, completed: subprocess.CompletedProcess, expected: str = "passed") -> dict[str, Any]:
    output = (completed.stdout + completed.stderr).strip()
    return {
        "action": action,
        "expected": expected,
        "actual": "passed" if completed.returncode == 0 else "failed",
        "returncode": completed.returncode,
        "output": output,
    }


def scenario_control_record(action: str, actual: str, detail: str, expected: str = "failed") -> dict[str, Any]:
    return {
        "action": action,
        "expected": expected,
        "actual": actual,
        "returncode": None,
        "output": detail,
        "mode": "scenario_control",
    }


def post_json(url: str, payload: dict) -> tuple[int, str]:
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            return response.status, response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8")
    except urllib.error.URLError as exc:
        return 0, str(exc)


def generate_production_traffic(count: int, pay_only: bool = False) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    for index in range(count):
        endpoint = "/pay" if pay_only or index % 2 == 0 else "/refund"
        status, body = post_json(
            f"http://localhost:8002{endpoint}",
            {"amount": 10 + index},
        )
        events.append({"endpoint": endpoint, "status": status, "body": body})
    return events


def wait_for_prometheus_samples() -> None:
    time.sleep(7)


def read_beliefs(path: Path) -> list[str]:
    return [
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.strip().startswith("//")
    ]


def run_bdi_trace(scenario: str) -> str:
    script = ROOT_DIR / "bdi" / "run_agent_for_scenario.sh"
    completed = run_command([bash_command(), str(script), scenario])
    return completed.stdout


def extract_decision(trace: str) -> str:
    decisions = [
        line.split("Decision:", 1)[1].strip()
        for line in trace.splitlines()
        if line.startswith("Decision:")
    ]
    return decisions[-1] if decisions else "unknown"


def extract_actions(trace: str) -> list[str]:
    return [
        line.split("Action:", 1)[1].strip()
        for line in trace.splitlines()
        if line.startswith("Action:")
    ]


def load_yaml(path: Path) -> dict[str, Any]:
    try:
        import yaml
    except ImportError as exc:
        raise ScenarioError(
            "PyYAML is required to read experiments/real_scenarios.yml. Install it with: py -m pip install PyYAML"
        ) from exc

    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except Exception as exc:  # pragma: no cover - parser-specific details vary
        raise ScenarioError(f"Failed to parse {path}: {exc}") from exc

    if not isinstance(data, dict):
        raise ScenarioError(f"{path} must contain a YAML mapping at the top level.")
    return data


def require_mapping(parent: dict[str, Any], key: str, scenario_name: str) -> dict[str, Any]:
    value = parent.get(key)
    if not isinstance(value, dict):
        raise ScenarioError(f"Scenario '{scenario_name}' must define mapping field '{key}'.")
    return value


def require_scalar(parent: dict[str, Any], key: str, scenario_name: str) -> Any:
    if key not in parent or isinstance(parent[key], (dict, list)):
        raise ScenarioError(f"Scenario '{scenario_name}' must define scalar field '{key}'.")
    return parent[key]


def normalize_environment(raw: dict[str, Any], scenario_name: str, name: str) -> dict[str, str]:
    required = ["version", "failure_mode", "force_error_rate", "extra_latency_ms"]
    missing = [field for field in required if field not in raw]
    if missing:
        raise ScenarioError(
            f"Scenario '{scenario_name}' environment '{name}' is missing fields: {', '.join(missing)}."
        )
    return {
        "version": str(raw["version"]),
        "failure_mode": str(raw["failure_mode"]),
        "force_error_rate": str(raw["force_error_rate"]),
        "extra_latency_ms": str(raw["extra_latency_ms"]),
    }


def normalize_scenario(name: str, raw: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(raw, dict):
        raise ScenarioError(f"Scenario '{name}' must be a YAML mapping.")

    environment = require_mapping(raw, "environment", name)
    staging = normalize_environment(require_mapping(environment, "staging", name), name, "staging")
    production = normalize_environment(require_mapping(environment, "production", name), name, "production")

    observation_count = int(require_scalar(raw, "observation_count", name))
    if observation_count < 0:
        raise ScenarioError(f"Scenario '{name}' observation_count must be zero or greater.")

    reobserve_expected = bool(require_scalar(raw, "reobserve_expected", name))
    context = {
        "network_issue_suspected": name == "real_network_suspected",
        "reobserve_after_failure": reobserve_expected,
    }

    scenario = {
        "name": name,
        "description": str(require_scalar(raw, "description", name)),
        "environment": {"staging": staging, "production": production},
        "traffic_pattern": str(require_scalar(raw, "traffic_pattern", name)),
        "traffic": {"count": DEFAULT_TRAFFIC_COUNT, "pay_only": name == "real_high_error_rate"},
        "observation_count": observation_count,
        "reobserve_expected": reobserve_expected,
        "traditional_decision": str(require_scalar(raw, "traditional_expected_decision", name)),
        "expected_bdi_decision": str(require_scalar(raw, "bdi_expected_decision", name)),
        "proves": str(require_scalar(raw, "proves", name)),
        "context": context,
    }
    return scenario


def compatibility_scenario() -> dict[str, Any]:
    return {
        "name": "real_production_unstable",
        "description": "Candidate release passes health but payment traffic fails and real metrics become unstable.",
        "environment": {
            "staging": {"version": "candidate", "failure_mode": "none", "force_error_rate": "0", "extra_latency_ms": "0"},
            "production": {"version": "candidate", "failure_mode": "pay_error", "force_error_rate": "0", "extra_latency_ms": "0"},
        },
        "traffic_pattern": "Send repeated /pay requests mixed with /refund requests; expect /pay failures while /health still passes.",
        "traffic": {"count": DEFAULT_TRAFFIC_COUNT, "pay_only": True},
        "observation_count": 1,
        "reobserve_expected": False,
        "traditional_decision": "release_success",
        "expected_bdi_decision": "rollback_production",
        "proves": "Backward-compatible scenario proving BDI rollback from real payment errors missed by /health.",
        "context": {"network_issue_suspected": False, "reobserve_after_failure": False},
    }


def load_scenarios(path: Path = SCENARIO_FILE) -> dict[str, dict[str, Any]]:
    data = load_yaml(path)
    raw_scenarios = data.get("scenarios")
    if not isinstance(raw_scenarios, dict) or not raw_scenarios:
        raise ScenarioError(f"{path} must define a non-empty 'scenarios' mapping.")

    scenarios = {
        str(name): normalize_scenario(str(name), raw)
        for name, raw in raw_scenarios.items()
    }
    scenarios.setdefault("real_production_unstable", compatibility_scenario())
    return scenarios


def env_for_deploy(scenario: dict[str, Any], environment_name: str) -> dict[str, str]:
    env = dict(os.environ)
    settings = scenario["environment"][environment_name]
    prefix = f"PAYMENT_{environment_name.upper()}"
    env[f"{prefix}_VERSION"] = settings["version"]
    env[f"{prefix}_FAILURE_MODE"] = settings["failure_mode"]
    env[f"{prefix}_FORCE_ERROR_RATE"] = settings["force_error_rate"]
    env[f"{prefix}_EXTRA_LATENCY_MS"] = settings["extra_latency_ms"]
    return env


def deploy_environment(scenario: dict[str, Any], environment_name: str, action_log: list[dict[str, Any]]) -> bool:
    version = scenario["environment"][environment_name]["version"]
    completed = run_action(
        "deploy",
        environment_name,
        version,
        env=env_for_deploy(scenario, environment_name),
        check=False,
    )
    action_log.append(action_record(f"deploy_{environment_name}", completed))
    return completed.returncode == 0


def health_check(environment_name: str, action_log: list[dict[str, Any]], expected: str = "passed") -> bool:
    completed = run_action("health_check", environment_name, check=False)
    action_log.append(action_record(f"health_check_{environment_name}", completed, expected=expected))
    return completed.returncode == 0


def collect_observation(scenario: dict[str, Any], index: int) -> dict[str, Any]:
    if scenario["observation_count"] <= 0:
        telemetry_result = {
            "source": "prometheus",
            "environment": "production",
            "telemetry": dict(ZERO_TELEMETRY),
            "queries": {},
        }
        traffic: list[dict[str, Any]] = []
    else:
        wait_for_prometheus_samples()
        traffic = generate_production_traffic(
            scenario["traffic"]["count"],
            pay_only=bool(scenario["traffic"].get("pay_only")),
        )
        wait_for_prometheus_samples()
        telemetry_result = prometheus_adapter.collect_telemetry(PROMETHEUS_URL, "production", "5m")

    LIVE_DIR.mkdir(parents=True, exist_ok=True)
    live_file = LIVE_DIR / f"{scenario['name']}_production_observation_{index}.json"
    live_file.write_text(json.dumps(telemetry_result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if index == scenario["observation_count"] or scenario["observation_count"] <= 1:
        (LIVE_DIR / f"{scenario['name']}_production.json").write_text(
            json.dumps(telemetry_result, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

    return {"index": index, "traffic": traffic, "telemetry_result": telemetry_result}


def write_live_beliefs(scenario: dict[str, Any], telemetry_result: dict[str, Any], statuses: dict[str, str]) -> Path:
    thresholds = belief_mapper.read_thresholds(ROOT_DIR / "telemetry" / "thresholds.yml")
    metric_beliefs, production_unstable = belief_mapper.classify_telemetry(
        telemetry_result["telemetry"],
        thresholds,
        "production",
    )

    production_health_failed = statuses["health_check_production"] == "failed"
    production_state = "unstable" if production_unstable or production_health_failed else "stable"
    staging_state = "stable" if statuses["health_check_staging"] == "passed" else "unstable"
    context = scenario["context"]

    beliefs = [
        f"scenario({scenario['name']}).",
        "candidate_version(candidate).",
        f"production_version({scenario['environment']['production']['version']}).",
        f"status(build, {statuses['build']}).",
        f"status(test, {statuses['test']}).",
        f"status(security_scan, {statuses['security_scan']}).",
        f"status(deploy(staging), {statuses['deploy_staging']}).",
        f"status(health_check(staging), {statuses['health_check_staging']}).",
        f"status(deploy(production), {statuses['deploy_production']}).",
        f"status(health_check(production), {statuses['health_check_production']}).",
        *metric_beliefs,
        f"environment(staging, {staging_state}).",
        f"environment(production, {production_state}).",
        f"network_issue_suspected({str(context['network_issue_suspected']).lower()}).",
        f"reobserve_after_failure({str(context['reobserve_after_failure']).lower()}).",
        f"expected_traditional_decision({scenario['traditional_decision']}).",
        f"expected_bdi_decision({scenario['expected_bdi_decision']}).",
    ]

    if production_state == "unstable":
        beliefs.append("rollback_available(production).")

    BELIEF_DIR.mkdir(parents=True, exist_ok=True)
    output = BELIEF_DIR / f"{scenario['name']}.asl"
    output.write_text("\n".join(beliefs) + "\n", encoding="utf-8")
    return output


def run_standard_gates(scenario: dict[str, Any], action_log: list[dict[str, Any]]) -> dict[str, str]:
    statuses = {
        "build": "not_run",
        "test": "not_run",
        "security_scan": "not_run",
        "deploy_staging": "not_run",
        "health_check_staging": "not_run",
        "deploy_production": "not_run",
        "health_check_production": "not_run",
    }

    for action in ["build", "test"]:
        completed = run_action(action, "candidate", check=False)
        action_log.append(action_record(action, completed))
        statuses[action] = "passed" if completed.returncode == 0 else "failed"
        if completed.returncode != 0:
            return statuses

    if scenario["name"] == "real_security_scan_failure":
        action_log.append(
            scenario_control_record(
                "security_scan",
                "failed",
                "Scenario defines a candidate security finding; deployment is intentionally blocked before staging.",
            )
        )
        statuses["security_scan"] = "failed"
        return statuses

    completed = run_action("security_scan", "candidate", check=False)
    action_log.append(action_record("security_scan", completed))
    statuses["security_scan"] = "passed" if completed.returncode == 0 else "failed"
    if completed.returncode != 0:
        return statuses

    if deploy_environment(scenario, "staging", action_log):
        statuses["deploy_staging"] = "passed"
    else:
        statuses["deploy_staging"] = "failed"
        return statuses

    expected_staging_health = "failed" if scenario["environment"]["staging"]["failure_mode"] in {"unhealthy", "down"} else "passed"
    if health_check("staging", action_log, expected=expected_staging_health):
        statuses["health_check_staging"] = "passed"
    else:
        statuses["health_check_staging"] = "failed"
        return statuses

    if deploy_environment(scenario, "production", action_log):
        statuses["deploy_production"] = "passed"
    else:
        statuses["deploy_production"] = "failed"
        return statuses

    expected_production_health = "failed" if scenario["environment"]["production"]["failure_mode"] in {"unhealthy", "down"} else "passed"
    statuses["health_check_production"] = "passed" if health_check(
        "production",
        action_log,
        expected=expected_production_health,
    ) else "failed"
    return statuses


def run_scenario(scenario: dict[str, Any]) -> dict[str, Any]:
    action_log: list[dict[str, Any]] = []
    statuses = run_standard_gates(scenario, action_log)

    observations: list[dict[str, Any]] = []
    observation_total = max(1, scenario["observation_count"])

    if statuses["deploy_production"] == "passed":
        for index in range(1, observation_total + 1):
            observations.append(collect_observation(scenario, index))
    else:
        observations.append(collect_observation({**scenario, "observation_count": 0}, 1))

    final_observation = observations[-1]
    belief_file = write_live_beliefs(scenario, final_observation["telemetry_result"], statuses)
    beliefs = read_beliefs(belief_file)
    trace = run_bdi_trace(scenario["name"])
    bdi_decision = extract_decision(trace)
    selected_actions = extract_actions(trace)

    if bdi_decision == "rollback_production":
        rollback = run_action("rollback", "production", check=False)
        action_log.append(action_record("rollback_production", rollback))

    traffic = [event for observation in observations for event in observation["traffic"]]
    telemetry_result = final_observation["telemetry_result"]
    result = {
        "scenario": scenario["name"],
        "description": scenario["description"],
        "scenario_definition": {
            "environment": scenario["environment"],
            "traffic_pattern": scenario["traffic_pattern"],
            "observation_count": scenario["observation_count"],
            "reobserve_expected": scenario["reobserve_expected"],
            "proves": scenario["proves"],
        },
        "traditional_ci_cd_decision": scenario["traditional_decision"],
        "bdi_decision": bdi_decision,
        "final_decision": bdi_decision,
        "expected_bdi_decision": scenario["expected_bdi_decision"],
        "telemetry_source": "prometheus",
        "telemetry": telemetry_result["telemetry"],
        "prometheus_queries": telemetry_result["queries"],
        "observations": [
            {
                "index": observation["index"],
                "telemetry": observation["telemetry_result"]["telemetry"],
                "traffic": observation["traffic"],
            }
            for observation in observations
        ],
        "traffic": traffic,
        "initial_beliefs": beliefs,
        "selected_bdi_actions": selected_actions,
        "action_log": action_log,
        "success": bdi_decision == scenario["expected_bdi_decision"],
        "bdi_trace": trace.splitlines(),
    }

    REAL_RESULT_DIR.mkdir(parents=True, exist_ok=True)
    (REAL_RESULT_DIR / f"{scenario['name']}.json").write_text(
        json.dumps(result, indent=2) + "\n",
        encoding="utf-8",
    )
    return result


def difference_note(result: dict[str, Any]) -> str:
    if result["success"]:
        return result["scenario_definition"]["proves"]
    if result["traditional_ci_cd_decision"] == "release_success" and result["bdi_decision"] == "rollback_production":
        return "Traditional health checks pass, but BDI rolls back because real payment metrics are unstable."
    return "Decision differs from the current expected BDI decision; inspect result JSON for beliefs and trace."


def write_comparison(results: list[dict[str, Any]]) -> None:
    lines = [
        "# Real Telemetry Experiment Comparison",
        "",
        "Phase 16 runs real telemetry scenarios from `experiments/real_scenarios.yml` and compares traditional CI/CD expectations with BDI decisions derived from Prometheus telemetry.",
        "",
        "| Scenario | Traditional Decision | Expected BDI | Actual BDI | Error Rate | P95 Latency ms | Availability | Success | Explanation |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for result in results:
        telemetry = result["telemetry"]
        lines.append(
            "| {scenario} | {traditional} | {expected_bdi} | {bdi} | {error_rate:.4f} | {latency:.2f} | {availability:.4f} | {success} | {note} |".format(
                scenario=result["scenario"],
                traditional=result["traditional_ci_cd_decision"],
                expected_bdi=result["expected_bdi_decision"],
                bdi=result["bdi_decision"],
                error_rate=float(telemetry["error_rate"]),
                latency=float(telemetry["latency_p95_ms"]),
                availability=float(telemetry["availability"]),
                success=str(result["success"]).lower(),
                note=difference_note(result),
            )
        )

    lines.extend([
        "",
        "## Notes",
        "",
        "The traditional decision is based on shell action success and `/health` checks. The BDI decision is produced from generated symbolic beliefs, including Prometheus-derived error rate, latency, availability, environment stability, and context beliefs such as reobserve or suspected network issues.",
    ])
    REAL_COMPARISON_TABLE.write_text("\n".join(lines) + "\n", encoding="utf-8")


def select_scenarios(all_scenarios: dict[str, dict[str, Any]], requested: str | None) -> list[dict[str, Any]]:
    if not requested:
        return [scenario for name, scenario in all_scenarios.items() if name != "real_production_unstable"]
    if requested not in all_scenarios:
        available = ", ".join(sorted(all_scenarios))
        raise ScenarioError(f"Unknown real telemetry scenario '{requested}'. Available scenarios: {available}")
    return [all_scenarios[requested]]


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run real telemetry scenarios from experiments/real_scenarios.yml.")
    parser.add_argument("scenario", nargs="?", help="Optional scenario name. Omit to run all configured scenarios.")
    parser.add_argument("--list", action="store_true", help="List available real telemetry scenarios and exit.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    try:
        scenarios = load_scenarios()
        if args.list:
            for name in sorted(scenarios):
                print(name)
            return 0

        selected = select_scenarios(scenarios, args.scenario)
        run_command(["docker", "compose", "up", "-d", "--build"])
        results = [run_scenario(scenario) for scenario in selected]
        write_comparison(results)

        for result in results:
            print(f"[real_experiments] PASS: {result['scenario']} -> {result['bdi_decision']}")
        print(f"[real_experiments] PASS: wrote {REAL_RESULT_DIR}")
        print(f"[real_experiments] PASS: wrote {REAL_COMPARISON_TABLE}")
        return 0
    except ScenarioError as exc:
        print(f"[real_experiments] FAIL: {exc}", file=sys.stderr)
        return 2
    except subprocess.CalledProcessError as exc:
        print(f"[real_experiments] FAIL: command failed: {' '.join(exc.cmd)}", file=sys.stderr)
        if exc.stdout:
            print(exc.stdout, file=sys.stderr)
        if exc.stderr:
            print(exc.stderr, file=sys.stderr)
        return exc.returncode or 1


if __name__ == "__main__":
    raise SystemExit(main())
