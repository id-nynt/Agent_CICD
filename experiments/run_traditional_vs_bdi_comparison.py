#!/usr/bin/env python3
"""Compare a fixed CI/CD pipeline with the Jason BDI controller.

The traditional controller runs the public shell action interface in a fixed
order. The BDI controller is executed through the Phase 6 scenario runner.
This script configures stimuli and collects evidence; it does not choose BDI
decisions.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any
from urllib.error import URLError
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "experiments" / "bdi_scenario_catalog.json"
RESULT_DIR = ROOT / "experiments" / "traditional_vs_bdi_results"
BDI_RESULT_DIR = ROOT / "experiments" / "bdi_scenario_results"
STATE_DIR = ROOT / "runtime" / "state"

DEFAULT_SCENARIOS = [
    "success_stable",
    "production_high_error_rate",
    "high_latency",
    "network_suspected",
    "transient_recovery",
    "rollback_unavailable",
]


def bash_command() -> str:
    git_bash = Path("C:/Program Files/Git/bin/bash.exe")
    if git_bash.exists():
        return str(git_bash)
    found = shutil.which("bash")
    if found:
        return found
    raise RuntimeError("Bash not found. Install Git Bash or run from an environment with bash.")


def run_command(command: list[str], env: dict[str, str] | None = None, check: bool = False) -> dict[str, Any]:
    started = time.time()
    completed = subprocess.run(
        command,
        cwd=ROOT,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )
    if check and completed.returncode != 0:
        raise RuntimeError(completed.stdout + completed.stderr)
    return {
        "command": command,
        "exit_code": completed.returncode,
        "stdout": completed.stdout.splitlines(),
        "stderr": completed.stderr.splitlines(),
        "duration_seconds": round(time.time() - started, 3),
    }


def scenario_env(scenario: dict[str, Any], include_bdi_force: bool = False) -> dict[str, str]:
    env = os.environ.copy()
    env["PAYMENT_STAGING_FAILURE_MODE"] = str(scenario.get("stagingFailureMode", "none"))
    env["PAYMENT_STAGING_FORCE_ERROR_RATE"] = str(scenario.get("stagingForceErrorRate", 0))
    env["PAYMENT_STAGING_EXTRA_LATENCY_MS"] = str(scenario.get("stagingExtraLatencyMs", 0))
    env["PAYMENT_PRODUCTION_FAILURE_MODE"] = str(scenario.get("productionFailureMode", "none"))
    env["PAYMENT_PRODUCTION_FORCE_ERROR_RATE"] = str(scenario.get("productionForceErrorRate", 0))
    env["PAYMENT_PRODUCTION_EXTRA_LATENCY_MS"] = str(scenario.get("productionExtraLatencyMs", 0))
    env["BDI_TELEMETRY_INTERVAL_SECONDS"] = "3"
    env["BDI_TELEMETRY_GRACE_SECONDS"] = "5"
    if include_bdi_force:
        for name in scenario.get("forceFailures", []):
            env[str(name)] = "true"
    return env


def reset_runtime() -> None:
    run_command(["docker", "compose", "down", "--remove-orphans"])


def run_action(name: str, script: str, *args: str, env: dict[str, str]) -> dict[str, Any]:
    result = run_command([bash_command(), str(ROOT / "cicd" / "actions" / script), *args], env=env)
    result["name"] = name
    result["script"] = f"cicd/actions/{script}"
    return result


def post_payment(count: int) -> None:
    for index in range(1, count + 1):
        request = Request(
            "http://localhost:8002/pay",
            data=json.dumps({"amount": index}).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            urlopen(request, timeout=5).read()
        except Exception:
            pass


def collect_telemetry() -> dict[str, Any]:
    completed = run_command(["py", str(ROOT / "telemetry" / "prometheus_adapter.py"), "production", "--pretty"])
    if completed["exit_code"] != 0:
        return {"available": False, "error": "\n".join(completed["stderr"] or completed["stdout"])}
    try:
        return {"available": True, "data": json.loads("\n".join(completed["stdout"]))}
    except json.JSONDecodeError as exc:
        return {"available": False, "error": str(exc), "raw": completed["stdout"]}


def final_production_version() -> str:
    path = STATE_DIR / "production_version.txt"
    if path.exists():
        return path.read_text(encoding="utf-8").strip()
    return "unknown"


def run_traditional(scenario: dict[str, Any]) -> dict[str, Any]:
    env = scenario_env(scenario)
    reset_runtime()
    actions: list[dict[str, Any]] = []
    decision = "release_complete"
    explanation = "Fixed pipeline completed build, test, security, staging, and production health gates."

    sequence = [
        ("build", "build.sh", ("candidate",), "stop_pipeline"),
        ("test", "test.sh", ("candidate",), "stop_pipeline"),
        ("security_scan", "security_scan.sh", ("candidate",), "stop_pipeline"),
        ("deploy_staging", "deploy.sh", ("staging", "candidate"), "stop_pipeline"),
        ("health_check_staging", "health_check.sh", ("staging",), "stop_pipeline"),
        ("deploy_production", "deploy.sh", ("production", "candidate"), "rollback_production"),
        ("health_check_production", "health_check.sh", ("production",), "rollback_production"),
    ]

    for name, script, args, failure_decision in sequence:
        action = run_action(name, script, *args, env=env)
        actions.append(action)
        if action["exit_code"] != 0:
            decision = failure_decision
            explanation = f"Fixed pipeline chose {failure_decision} after {name} failed."
            if failure_decision == "rollback_production":
                rollback = run_action("rollback_production", "rollback.sh", "production", env=env)
                actions.append(rollback)
            break

    if decision == "release_complete":
        traffic_count = int(scenario.get("trafficCount", 0) or 0)
        if scenario.get("trafficMode", "none") != "none":
            post_payment(traffic_count)
            explanation += " Runtime traffic was generated after release, but the fixed pipeline has no post-release reasoning loop."

        if scenario.get("stopPrometheusAfterRelease"):
            run_command(["docker", "compose", "stop", "prometheus"], env=env)
            explanation += " Prometheus was stopped after release; the fixed pipeline does not re-plan from observability loss."

        if scenario.get("healAfterPause"):
            explanation += " A transient fault was configured, but the fixed pipeline has no pause/reobserve intention."

    telemetry = collect_telemetry()
    return {
        "controller": "traditional_fixed_pipeline",
        "actions": actions,
        "final_decision": decision,
        "final_production_version": final_production_version(),
        "telemetry": telemetry,
        "explanation": explanation,
        "uses_public_actions": True,
    }


def run_bdi(scenario: dict[str, Any], timeout_seconds: int) -> dict[str, Any]:
    scenario_id = scenario["id"]
    command = [
        "powershell",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(ROOT / "experiments" / "run_bdi_scenario_suite.ps1"),
        "-Scenario",
        scenario_id,
        "-TelemetryIntervalSeconds",
        "3",
        "-TelemetryGraceSeconds",
        "5",
        "-TimeoutSeconds",
        str(timeout_seconds),
    ]
    completed = run_command(command, env=scenario_env(scenario, include_bdi_force=True))
    result_path = BDI_RESULT_DIR / scenario_id / "result.json"
    if result_path.exists():
        result = json.loads(result_path.read_text(encoding="utf-8-sig"))
    else:
        result = {"passed": False, "expectedBeliefs": [], "notes": ["missing BDI result file"]}

    observed = [
        item["belief"]
        for item in result.get("expectedBeliefs", [])
        if item.get("observed")
    ]
    decision = infer_bdi_decision(observed)
    return {
        "controller": "jason_bdi_controller",
        "runner_command": command,
        "runner_exit_code": completed["exit_code"],
        "runner_stdout": completed["stdout"],
        "runner_stderr": completed["stderr"],
        "scenario_result": result,
        "bdi_percepts_and_beliefs": observed,
        "final_decision": decision,
        "final_production_version": final_production_version(),
        "telemetry": collect_telemetry(),
        "explanation": bdi_explanation(scenario, observed, decision),
        "uses_public_actions": True,
    }


def infer_bdi_decision(observed: list[str]) -> str:
    priority = [
        ("decision(manual_intervention_required)", "manual_intervention_required"),
        ("decision(rollback_production)", "rollback_production"),
        ("decision(reobserve_recovered)", "reobserve_recovered"),
        ("decision(pause_reobserve)", "pause_reobserve"),
        ("decision(stop_pipeline)", "stop_pipeline"),
        ("decision(release_complete)", "release_complete"),
    ]
    for belief, decision in priority:
        if belief in observed:
            return decision
    return "unknown"


def bdi_explanation(scenario: dict[str, Any], observed: list[str], decision: str) -> str:
    if decision == "rollback_production":
        return "BDI perceived production instability and selected the rollback recovery plan."
    if decision == "pause_reobserve":
        return "BDI treated the instability as ambiguous and selected a pause/reobserve plan."
    if decision == "reobserve_recovered":
        return "BDI paused, reobserved stable production, and kept the release."
    if decision == "manual_intervention_required":
        return "BDI escalated because automated recovery or observability was unavailable."
    if decision == "release_complete":
        return "BDI completed the release and recorded reliability as stable."
    if decision == "stop_pipeline":
        return "BDI stopped before production based on a failed gate percept."
    return f"BDI result was not inferable from expected beliefs for {scenario['id']}."


def improvement_note(traditional: dict[str, Any], bdi: dict[str, Any]) -> str:
    t_decision = traditional["final_decision"]
    b_decision = bdi["final_decision"]
    if t_decision == "release_complete" and b_decision == "rollback_production":
        return "BDI improves reliability by reacting to post-release telemetry that the fixed pipeline ignores."
    if t_decision == "release_complete" and b_decision == "pause_reobserve":
        return "BDI improves explainability by distinguishing ambiguous telemetry from definite failure."
    if t_decision == "release_complete" and b_decision == "reobserve_recovered":
        return "BDI avoids unnecessary rollback by pausing and confirming recovery."
    if t_decision == "release_complete" and b_decision == "manual_intervention_required":
        return "BDI improves operational safety by escalating when observability/recovery is not trustworthy."
    if t_decision == b_decision:
        return "Both controllers make the same final decision; BDI adds explicit percepts and reasons."
    return "Controllers differ; inspect scenario evidence for the reason."


def write_markdown(results: list[dict[str, Any]]) -> None:
    lines = [
        "# Traditional vs Jason BDI Comparison",
        "",
        "This report is research evidence for the prototype only. It does not claim production readiness.",
        "",
        "Both controllers use the same public shell action interface under `cicd/actions/*.sh`. The traditional controller runs a fixed stage order. The BDI controller runs Jason `deployment_agent` through `CicdEnvironment` and records decisions selected by AgentSpeak plans.",
        "",
        "| Scenario | Traditional decision | BDI decision | Traditional production | BDI production | BDI evidence | Improvement / explanation |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    for item in results:
        bdi_evidence = ", ".join(item["bdi"]["bdi_percepts_and_beliefs"][:5]) or "none"
        lines.append(
            "| {scenario} | {td} | {bd} | {tp} | {bp} | {evidence} | {note} |".format(
                scenario=item["scenario"],
                td=item["traditional"]["final_decision"],
                bd=item["bdi"]["final_decision"],
                tp=item["traditional"]["final_production_version"],
                bp=item["bdi"]["final_production_version"],
                evidence=bdi_evidence.replace("|", "\\|"),
                note=item["comparison_note"].replace("|", "\\|"),
            )
        )

    lines.extend(
        [
            "",
            "## Interpretation",
            "",
            "- A fixed pipeline can prove the deploy-time gates passed, but it does not keep an intention alive to reason over telemetry after release.",
            "- The BDI controller exposes why it acted through percepts such as `metric(production,error_rate,high)`, `environment(production,unstable)`, `reobserve_reason(high_latency)`, and `manual_reason(network_suspected)`.",
            "- The strongest BDI evidence is in post-release scenarios: high error rate, high latency, network suspected, transient recovery, and rollback unavailable.",
            "- This remains a local research prototype, not production-ready automation.",
        ]
    )
    (RESULT_DIR / "comparison_report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--scenarios",
        nargs="*",
        default=DEFAULT_SCENARIOS,
        help="Scenario ids to compare. Defaults to runtime scenarios with fair shared stimuli.",
    )
    parser.add_argument("--timeout-seconds", type=int, default=210)
    parser.add_argument(
        "--from-existing",
        action="store_true",
        help="Regenerate aggregate JSON/Markdown from existing per-scenario JSON files.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    catalog = {item["id"]: item for item in json.loads(CATALOG.read_text(encoding="utf-8"))}
    RESULT_DIR.mkdir(parents=True, exist_ok=True)

    results: list[dict[str, Any]] = []
    if args.from_existing:
        for scenario_id in args.scenarios:
            path = RESULT_DIR / f"{scenario_id}.json"
            if not path.exists():
                raise SystemExit(f"missing existing result: {path}")
            results.append(json.loads(path.read_text(encoding="utf-8-sig")))
        write_markdown(results)
        (RESULT_DIR / "comparison_results.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
        print(f"[comparison] wrote {RESULT_DIR / 'comparison_report.md'}")
        return 0

    for scenario_id in args.scenarios:
        if scenario_id not in catalog:
            raise SystemExit(f"unknown scenario: {scenario_id}")
        scenario = catalog[scenario_id]
        print(f"[comparison] traditional: {scenario_id}")
        traditional = run_traditional(scenario)
        print(f"[comparison] bdi: {scenario_id}")
        bdi = run_bdi(scenario, args.timeout_seconds)
        item = {
            "scenario": scenario_id,
            "capability": scenario.get("capability"),
            "traditional": traditional,
            "bdi": bdi,
            "comparison_note": improvement_note(traditional, bdi),
        }
        results.append(item)
        (RESULT_DIR / f"{scenario_id}.json").write_text(json.dumps(item, indent=2) + "\n", encoding="utf-8")
        print(f"[comparison] wrote {scenario_id}.json")

    write_markdown(results)
    (RESULT_DIR / "comparison_results.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    print(f"[comparison] wrote {RESULT_DIR / 'comparison_report.md'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
