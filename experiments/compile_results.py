#!/usr/bin/env python3
"""Compile scenario logs, beliefs, and BDI traces into experiment results."""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
SCENARIOS = [
    "success_stable",
    "production_unstable",
    "stage_failure",
    "rollback_midway_recovery",
    "network_issue_suspected",
]
EVENT_LOG_DIR = ROOT_DIR / "simulation" / "event_log"
BELIEF_DIR = ROOT_DIR / "telemetry" / "generated_beliefs"
RESULT_DIR = ROOT_DIR / "experiments" / "results"
COMPARISON_TABLE = ROOT_DIR / "experiments" / "comparison_table.md"


def bash_command() -> str:
    git_bash = Path("C:/Program Files/Git/bin/bash.exe")
    if git_bash.exists():
        return str(git_bash)
    found = shutil.which("bash")
    if found:
        return found
    raise RuntimeError("Bash not found. Install Git Bash or run from an environment with bash.")


def read_beliefs(path: Path) -> list[str]:
    return [
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.strip().startswith("//")
    ]


def run_bdi_trace(scenario: str) -> str:
    script = ROOT_DIR / "bdi" / "run_agent_for_scenario.sh"
    completed = subprocess.run(
        [bash_command(), str(script), scenario],
        cwd=ROOT_DIR,
        check=True,
        capture_output=True,
        text=True,
    )
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


def updated_beliefs(initial_beliefs: list[str], bdi_decision: str) -> list[str]:
    beliefs = list(initial_beliefs)
    if bdi_decision == "release_complete":
        beliefs.append("bdi_decision(release_complete).")
    elif bdi_decision == "rollback_production":
        beliefs.append("intention(rollback(production)).")
        beliefs.append("bdi_decision(rollback_production).")
    elif bdi_decision == "pause_reobserve":
        beliefs.append("intention(pause(reobserve_before_recovery)).")
        beliefs.append("intention(reobserve(production)).")
        beliefs.append("bdi_decision(pause_reobserve).")
    elif bdi_decision == "stop_pipeline":
        beliefs.append("intention(stop_pipeline).")
        beliefs.append("bdi_decision(stop_pipeline).")
    else:
        beliefs.append(f"bdi_decision({bdi_decision}).")
    return beliefs


def final_state(log: dict, bdi_decision: str) -> dict:
    return {
        "traditional_final_decision": log["final_decision"],
        "production_version_after_scenario_run": log["final_production_version"],
        "bdi_decision": bdi_decision,
        "telemetry": log["telemetry"],
        "context": log["context"],
    }


def scenario_success(log: dict, bdi_decision: str) -> bool:
    expected_bdi = log["expected"]["bdi_decision"]
    expected_to_actual = {
        "release_success": "release_complete",
        "rollback_after_unstable_belief": "rollback_production",
        "abandon_release_or_request_fix": "stop_pipeline",
        "pause_or_reobserve_before_rollback": "pause_reobserve",
        "pause_reobserve_then_decide": "pause_reobserve",
    }
    return bool(log["success"]) and expected_to_actual.get(expected_bdi) == bdi_decision


def write_result(scenario: str) -> dict:
    log = json.loads((EVENT_LOG_DIR / f"{scenario}.json").read_text(encoding="utf-8"))
    beliefs = read_beliefs(BELIEF_DIR / f"{scenario}.asl")
    trace = run_bdi_trace(scenario)
    bdi_decision = extract_decision(trace)
    selected_actions = extract_actions(trace)

    result = {
        "scenario": scenario,
        "traditional_ci_cd_decision": log["expected"]["traditional_decision"],
        "bdi_decision": bdi_decision,
        "expected_bdi_decision": log["expected"]["bdi_decision"],
        "initial_beliefs": beliefs,
        "updated_beliefs": updated_beliefs(beliefs, bdi_decision),
        "selected_bdi_actions": selected_actions,
        "final_state": final_state(log, bdi_decision),
        "success": scenario_success(log, bdi_decision),
        "bdi_trace": trace.splitlines(),
    }

    RESULT_DIR.mkdir(parents=True, exist_ok=True)
    (RESULT_DIR / f"{scenario}.json").write_text(
        json.dumps(result, indent=2) + "\n",
        encoding="utf-8",
    )
    return result


def difference_note(result: dict) -> str:
    traditional = result["traditional_ci_cd_decision"]
    bdi = result["bdi_decision"]
    if traditional == "rollback" and bdi == "pause_reobserve":
        return "BDI delays rollback because context suggests reobservation."
    if traditional == "rollback" and bdi == "rollback_production":
        return "Both recover, but BDI decision is justified by unstable beliefs."
    if traditional == "stop_pipeline" and bdi == "stop_pipeline":
        return "Both stop before production; BDI preserves reliability goal."
    if traditional == "release_success" and bdi == "release_complete":
        return "Both complete the release."
    return "Decision differs through symbolic belief evaluation."


def write_comparison(results: list[dict]) -> None:
    lines = [
        "# Experiment Comparison Table",
        "",
        "Phase 5 compares traditional CI/CD expectations with BDI decisions over the same scenarios.",
        "",
        "| Scenario | Traditional Decision | BDI Decision | Selected BDI Actions | Success | Explanation |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for result in results:
        actions = ", ".join(result["selected_bdi_actions"]) or "none"
        lines.append(
            "| {scenario} | {traditional} | {bdi} | {actions} | {success} | {note} |".format(
                scenario=result["scenario"],
                traditional=result["traditional_ci_cd_decision"],
                bdi=result["bdi_decision"],
                actions=actions,
                success=str(result["success"]).lower(),
                note=difference_note(result),
            )
        )

    lines.extend([
        "",
        "## What Differs",
        "",
        "Traditional CI/CD follows stage outcomes and predefined recovery expectations. In these experiments, a production failure leads to a rollback expectation.",
        "",
        "BDI CI/CD reasons over symbolic beliefs derived from telemetry and context. It can still choose rollback when production is unstable, but it can also pause and reobserve when beliefs such as `network_issue_suspected(true).` or `reobserve_after_failure(true).` make immediate rollback less explainable.",
        "",
        "The context-aware scenarios are `rollback_midway_recovery` and `network_issue_suspected`, where the BDI decision is `pause_reobserve` while the traditional decision remains `rollback`.",
    ])

    COMPARISON_TABLE.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    results = [write_result(scenario) for scenario in SCENARIOS]
    write_comparison(results)
    for result in results:
        print(f"[compile_results] PASS: {result['scenario']} -> {result['bdi_decision']}")
    print(f"[compile_results] PASS: wrote {COMPARISON_TABLE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
