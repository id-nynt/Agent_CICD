#!/usr/bin/env python3
"""Unit tests for the Prometheus telemetry adapter query and parsing logic."""

from __future__ import annotations

import unittest
from unittest.mock import patch

import prometheus_adapter


def prometheus_payload(value: float) -> dict:
    return {
        "resultType": "vector",
        "result": [
            {
                "metric": {},
                "value": [1787380000.0, str(value)],
            }
        ],
    }


class PrometheusAdapterTests(unittest.TestCase):
    def test_queries_use_environment_label_and_expected_metrics(self) -> None:
        queries = prometheus_adapter.queries_for("production", "5m")

        self.assertIn('environment="production"', queries["error_rate"])
        self.assertIn("payment_service_errors_total", queries["error_rate"])
        self.assertIn("payment_service_requests_total", queries["error_rate"])
        self.assertIn("payment_service_request_latency_seconds_bucket", queries["latency_p95_ms"])
        self.assertIn("payment_service_health", queries["availability"])

    def test_collect_telemetry_returns_mapper_field_names(self) -> None:
        values = [
            prometheus_payload(0.125),
            prometheus_payload(750.0),
            prometheus_payload(0.9),
        ]

        with patch("prometheus_adapter.prometheus_query", side_effect=values):
            result = prometheus_adapter.collect_telemetry("http://prometheus:9090", "production", "1m")

        self.assertEqual(result["environment"], "production")
        self.assertEqual(result["telemetry"]["error_rate"], 0.125)
        self.assertEqual(result["telemetry"]["latency_p95_ms"], 750.0)
        self.assertEqual(result["telemetry"]["availability"], 0.9)

    def test_empty_prometheus_result_defaults_to_zero(self) -> None:
        self.assertEqual(
            prometheus_adapter.first_value({"resultType": "vector", "result": []}, default=0.0),
            0.0,
        )

    def test_nan_prometheus_result_defaults_to_zero(self) -> None:
        self.assertEqual(prometheus_adapter.first_value(prometheus_payload(float("nan"))), 0.0)

    def test_invalid_environment_fails_fast(self) -> None:
        with self.assertRaises(ValueError):
            prometheus_adapter.collect_telemetry("http://localhost:9090", "qa", "1m")


if __name__ == "__main__":
    unittest.main()
