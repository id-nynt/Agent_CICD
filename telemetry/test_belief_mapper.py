#!/usr/bin/env python3
"""Focused threshold tests for telemetry-to-belief mapping."""

from pathlib import Path

from belief_mapper import classify_telemetry, is_adapter_json, map_adapter_to_beliefs, read_simple_yaml, scenario_to_log


THRESHOLDS = {
    "error_rate_high_gt": 0.05,
    "latency_p95_ms_high_gt": 500,
    "availability_low_lt": 0.99,
}


def assert_contains(beliefs: list[str], expected: str) -> None:
    if expected not in beliefs:
        raise AssertionError(f"missing belief: {expected}\nactual: {beliefs}")


def test_normal_metrics() -> None:
    beliefs, unstable = classify_telemetry(
        {"error_rate": 0.01, "latency_p95_ms": 120, "availability": 0.999},
        THRESHOLDS,
    )
    assert_contains(beliefs, "metric(production, error_rate, normal).")
    assert_contains(beliefs, "metric(production, latency, normal).")
    assert_contains(beliefs, "metric(production, availability, high).")
    assert unstable is False


def test_bad_metrics_make_production_unstable() -> None:
    beliefs, unstable = classify_telemetry(
        {"error_rate": 0.12, "latency_p95_ms": 900, "availability": 0.91},
        THRESHOLDS,
    )
    assert_contains(beliefs, "metric(production, error_rate, high).")
    assert_contains(beliefs, "metric(production, latency, high).")
    assert_contains(beliefs, "metric(production, availability, low).")
    assert unstable is True


def test_threshold_boundaries_are_strict() -> None:
    beliefs, unstable = classify_telemetry(
        {"error_rate": 0.05, "latency_p95_ms": 500, "availability": 0.99},
        THRESHOLDS,
    )
    assert_contains(beliefs, "metric(production, error_rate, normal).")
    assert_contains(beliefs, "metric(production, latency, normal).")
    assert_contains(beliefs, "metric(production, availability, high).")
    assert unstable is False


def test_scenario_yaml_can_be_mapped_directly() -> None:
    scenario_path = Path(__file__).resolve().parents[1] / "simulation" / "scenarios" / "production_unstable.yml"
    log = scenario_to_log(read_simple_yaml(scenario_path))
    assert log["scenario"] == "production_unstable"
    assert log["final_decision"] == "rollback_expected"
    assert log["actions"][-1]["name"] == "rollback_production"


def test_adapter_json_can_be_mapped_to_live_production_beliefs() -> None:
    adapter_json = {
        "environment": "production",
        "source": "prometheus",
        "telemetry": {
            "error_rate": 0.12,
            "latency_p95_ms": 900,
            "availability": 0.91,
        },
    }

    assert is_adapter_json(adapter_json) is True
    beliefs = map_adapter_to_beliefs(adapter_json, THRESHOLDS)

    assert_contains(beliefs, "telemetry_source(prometheus).")
    assert_contains(beliefs, "telemetry_environment(production).")
    assert_contains(beliefs, "metric(production, error_rate, high).")
    assert_contains(beliefs, "metric(production, latency, high).")
    assert_contains(beliefs, "metric(production, availability, low).")
    assert_contains(beliefs, "environment(production, unstable).")


def test_adapter_json_can_be_mapped_to_live_staging_beliefs() -> None:
    adapter_json = {
        "environment": "staging",
        "source": "prometheus",
        "telemetry": {
            "error_rate": 0.0,
            "latency_p95_ms": 25,
            "availability": 1.0,
        },
    }

    beliefs = map_adapter_to_beliefs(adapter_json, THRESHOLDS)

    assert_contains(beliefs, "metric(staging, error_rate, normal).")
    assert_contains(beliefs, "metric(staging, latency, normal).")
    assert_contains(beliefs, "metric(staging, availability, high).")
    assert_contains(beliefs, "environment(staging, stable).")


def run() -> None:
    test_normal_metrics()
    test_bad_metrics_make_production_unstable()
    test_threshold_boundaries_are_strict()
    test_scenario_yaml_can_be_mapped_directly()
    test_adapter_json_can_be_mapped_to_live_production_beliefs()
    test_adapter_json_can_be_mapped_to_live_staging_beliefs()
    print("[test_belief_mapper] PASS: threshold mapping tests passed")


if __name__ == "__main__":
    run()
