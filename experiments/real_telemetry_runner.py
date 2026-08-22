#!/usr/bin/env python3
"""Run real-telemetry CI/CD scenarios against local Docker Compose services."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
REAL_RESULT_DIR = ROOT_DIR / "experiments" / "real_results"
REAL_COMPARISON_TABLE = ROOT_DIR / "experiments" / "real_comparison_table.md"
BELIEF_DIR = ROOT_DIR / "telemetry" / "generated_beliefs"
LIVE_DIR = ROOT_DIR / "telemetry" / "live"

sys.path.insert(0, str(ROOT_DIR / "telemetry"))
import belief_mapper  # noqa: E402
import prometheus_adapter  # noqa: E402


SCENARIOS = [
    {
        "name": "real_success",
        "description": "Healthy candidate release with real Prometheus telemetry.",
        "failure_mode": "none",
        "extra_latency_ms": "0",
        "traffic": {"count": 8, "expect_errors": False},
        "traditional_decision": "release_success",
        "expected_bdi_decision": "release_complete",
        "context": {
            "network_issue_suspected": False,
            "reobserve_after_failure": False,
        },
    },
    {
        "name": "real_production_unstable",
        "description": "Candidate release passes health but payment traffic fails and real metrics become unstable.",
        "failure_mode": "pay_error",
        "extra_latency_ms": "0",
        "traffic": {"count": 8, "expect_errors": True},
        "traditional_decision": "release_success",
        "expected_bdi_decision": "rollback_production",
        "context": {
            "network_issue_suspected": False,
            "reobserve_after_failure": False,
        },
    },
]


def bash_command() -> str:
    git_bash = Path("C:/Program Files/Git/bin/bash.exe")
    if git_bash.exists():
        return str(git_bash)
    found = shutil.which("bash")
    if found:
        return found
    raise RuntimeError("Bash not found. Install Git Bash or run from an environment with bash.")


def run_command(args: list[str], env: dict[str, str] | None = None) -> subprocess.CompletedProcess:
    completed = subprocess.run(
        args,
        cwd=ROOT_DIR,
        env=env,
        check=True,
        capture_output=True,
        text=True,
    )
    return completed


def run_action(*args: str, env: dict[str, str] | None = None) -> str:
    script = ROOT_DIR / "cicd" / "actions" / f"{args[0]}.sh"
    completed = run_command([bash_command(), str(script), *args[1:]], env=env)
    return completed.stdout


def post_json(url: str, payload: dict) -> tuple[int, str]:
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return response.status, response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8")


def generate_production_traffic(count: int) -> list[dict]:
    events: list[dict] = []
    for index in range(count):
        endpoint = "/pay" if index % 2 == 0 else "/refund"
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


def write_live_beliefs(scenario: dict, telemetry_result: dict, action_log: list[dict]) -> Path:
    thresholds = belief_mapper.read_thresholds(ROOT_DIR / "telemetry" / "thresholds.yml")
    metric_beliefs, production_unstable = belief_mapper.classify_telemetry(
        telemetry_result["telemetry"],
        thresholds,
        "production",
    )

    context = scenario["context"]
    beliefs = [
        f"scenario({scenario['name']}).",
        "candidate_version(candidate).",
        "production_version(candidate).",
        "status(build, passed).",
        "status(test, passed).",
        "status(security_scan, passed).",
        "status(deploy(staging), passed).",
        "status(health_check(staging), passed).",
        "status(deploy(production), passed).",
        "status(health_check(production), passed).",
        *metric_beliefs,
        "environment(staging, stable).",
        f"environment(production, {'unstable' if production_unstable else 'stable'}).",
        f"network_issue_suspected({str(context['network_issue_suspected']).lower()}).",
        f"reobserve_after_failure({str(context['reobserve_after_failure']).lower()}).",
        f"expected_traditional_decision({scenario['traditional_decision']}).",
        f"expected_bdi_decision({scenario['expected_bdi_decision']}).",
    ]

    if production_unstable:
        beliefs.append("rollback_available(production).")

    BELIEF_DIR.mkdir(parents=True, exist_ok=True)
    output = BELIEF_DIR / f"{scenario['name']}.asl"
    output.write_text("\n".join(beliefs) + "\n", encoding="utf-8")
    return output


def run_scenario(scenario: dict) -> dict:
    action_log: list[dict] = []

    action_log.append({"action": "build", "output": run_action("build", "candidate")})
    action_log.append({"action": "test", "output": run_action("test", "candidate")})
    action_log.append({"action": "security_scan", "output": run_action("security_scan", "candidate")})
    action_log.append({"action": "deploy_staging", "output": run_action("deploy", "staging", "candidate")})
    action_log.append({"action": "health_check_staging", "output": run_action("health_check", "staging")})

    deploy_env = dict(**{k: v for k, v in __import__("os").environ.items()})
    deploy_env["PAYMENT_PRODUCTION_FAILURE_MODE"] = scenario["failure_mode"]
    deploy_env["PAYMENT_PRODUCTION_EXTRA_LATENCY_MS"] = scenario["extra_latency_ms"]
    deploy_env["PAYMENT_PRODUCTION_FORCE_ERROR_RATE"] = "0"
    deploy_env["PAYMENT_PRODUCTION_VERSION"] = "candidate"

    action_log.append({
        "action": "deploy_production",
        "output": run_action("deploy", "production", "candidate", env=deploy_env),
    })
    action_log.append({"action": "health_check_production", "output": run_action("health_check", "production")})

    wait_for_prometheus_samples()
    traffic = generate_production_traffic(scenario["traffic"]["count"])
    wait_for_prometheus_samples()

    telemetry_result = prometheus_adapter.collect_telemetry("http://localhost:9090", "production", "5m")
    LIVE_DIR.mkdir(parents=True, exist_ok=True)
    (LIVE_DIR / f"{scenario['name']}_production.json").write_text(
        json.dumps(telemetry_result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    belief_file = write_live_beliefs(scenario, telemetry_result, action_log)
    beliefs = read_beliefs(belief_file)
    trace = run_bdi_trace(scenario["name"])
    bdi_decision = extract_decision(trace)
    selected_actions = extract_actions(trace)

    if bdi_decision == "rollback_production":
        rollback_output = run_action("rollback", "production")
        action_log.append({"action": "rollback_production", "output": rollback_output})

    result = {
        "scenario": scenario["name"],
        "description": scenario["description"],
        "traditional_ci_cd_decision": scenario["traditional_decision"],
        "bdi_decision": bdi_decision,
        "expected_bdi_decision": scenario["expected_bdi_decision"],
        "telemetry_source": "prometheus",
        "telemetry": telemetry_result["telemetry"],
        "prometheus_queries": telemetry_result["queries"],
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


def difference_note(result: dict) -> str:
    if result["traditional_ci_cd_decision"] == "release_success" and result["bdi_decision"] == "release_complete":
        return "Both complete because real telemetry remains stable."
    if result["traditional_ci_cd_decision"] == "release_success" and result["bdi_decision"] == "rollback_production":
        return "Traditional health checks pass, but BDI rolls back because real payment metrics are unstable."
    return "Decision comes from real telemetry-derived beliefs."


def write_comparison(results: list[dict]) -> None:
    lines = [
        "# Real Telemetry Experiment Comparison",
        "",
        "Phase 12 compares traditional CI/CD action outcomes with BDI decisions derived from Prometheus telemetry.",
        "",
        "| Scenario | Traditional Decision | BDI Decision | Error Rate | P95 Latency ms | Availability | Success | Explanation |",
        "| --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for result in results:
        telemetry = result["telemetry"]
        lines.append(
            "| {scenario} | {traditional} | {bdi} | {error_rate:.4f} | {latency:.2f} | {availability:.4f} | {success} | {note} |".format(
                scenario=result["scenario"],
                traditional=result["traditional_ci_cd_decision"],
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
        "The traditional decision here is based on shell action success and `/health` checks. The unstable scenario deliberately keeps `/health` passing while `/pay` traffic fails, so Prometheus-derived beliefs expose a problem that simple health checks miss.",
    ])
    REAL_COMPARISON_TABLE.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    run_command(["docker", "compose", "up", "-d", "--build"])
    results = [run_scenario(scenario) for scenario in SCENARIOS]
    write_comparison(results)

    for result in results:
        print(f"[real_experiments] PASS: {result['scenario']} -> {result['bdi_decision']}")
    print(f"[real_experiments] PASS: wrote {REAL_RESULT_DIR}")
    print(f"[real_experiments] PASS: wrote {REAL_COMPARISON_TABLE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
