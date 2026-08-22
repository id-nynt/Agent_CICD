#!/usr/bin/env python3
"""Query Prometheus and emit telemetry values for the BDI belief mapper.

The adapter intentionally returns the same raw telemetry field names used by
the simulated scenarios: error_rate, latency_p95_ms, and availability.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
import urllib.parse
import urllib.request
from typing import Any


DEFAULT_PROMETHEUS_URL = "http://localhost:9090"
DEFAULT_WINDOW = "1m"
ENVIRONMENTS = {"staging", "production"}


def prometheus_query(base_url: str, query: str) -> dict[str, Any]:
    encoded = urllib.parse.urlencode({"query": query})
    url = f"{base_url.rstrip('/')}/api/v1/query?{encoded}"

    with urllib.request.urlopen(url, timeout=10) as response:
        payload = json.loads(response.read().decode("utf-8"))

    if payload.get("status") != "success":
        raise RuntimeError(f"Prometheus query failed: {payload}")
    return payload["data"]


def first_value(data: dict[str, Any], default: float = 0.0) -> float:
    result = data.get("result", [])
    if not result:
        return default
    value = float(result[0]["value"][1])
    if not math.isfinite(value):
        return default
    return value


def query_value(base_url: str, query: str, default: float = 0.0) -> float:
    return first_value(prometheus_query(base_url, query), default)


def queries_for(environment: str, window: str) -> dict[str, str]:
    selector = f'environment="{environment}"'
    request_selector = f'{selector},endpoint=~"/pay|/refund"'

    return {
        "error_rate": (
            "sum(payment_service_errors_total"
            f"{{{request_selector}}}) "
            "/ "
            "clamp_min(sum(payment_service_requests_total"
            f"{{{request_selector}}}), 1)"
        ),
        "latency_p95_ms": (
            "histogram_quantile(0.95, sum by (le) "
            "(payment_service_request_latency_seconds_bucket"
            f"{{{request_selector}}})) * 1000"
        ),
        "availability": f'avg(payment_service_health{{{selector}}})',
    }


def collect_telemetry(base_url: str, environment: str, window: str) -> dict[str, Any]:
    if environment not in ENVIRONMENTS:
        raise ValueError("environment must be staging or production")

    queries = queries_for(environment, window)
    telemetry = {
        "error_rate": query_value(base_url, queries["error_rate"], 0.0),
        "latency_p95_ms": query_value(base_url, queries["latency_p95_ms"], 0.0),
        "availability": query_value(base_url, queries["availability"], 0.0),
    }

    return {
        "environment": environment,
        "source": "prometheus",
        "prometheus_url": base_url.rstrip("/"),
        "window": window,
        "telemetry": telemetry,
        "queries": queries,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Query Prometheus for payment service telemetry.")
    parser.add_argument("environment", choices=sorted(ENVIRONMENTS), help="Environment to query.")
    parser.add_argument("--prometheus-url", default=DEFAULT_PROMETHEUS_URL, help="Prometheus base URL.")
    parser.add_argument("--window", default=DEFAULT_WINDOW, help="Prometheus rate window, such as 1m or 5m.")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON output.")
    args = parser.parse_args()

    try:
        result = collect_telemetry(args.prometheus_url, args.environment, args.window)
    except Exception as exc:
        print(f"[prometheus_adapter] FAIL: {exc}", file=sys.stderr)
        return 1

    indent = 2 if args.pretty else None
    print(json.dumps(result, indent=indent, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
