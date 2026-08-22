#!/usr/bin/env python3
"""Stub for future Prometheus/OpenTelemetry telemetry adapters."""

from __future__ import annotations

import json


def main() -> int:
    sample = {
        "source": "prometheus_or_opentelemetry_stub",
        "environment": "production",
        "telemetry": {
            "error_rate": 0.02,
            "latency_p95_ms": 240,
            "availability": 0.995,
        },
        "notes": "Future adapter should replace simulated scenario telemetry with real monitoring data.",
    }
    print(json.dumps(sample, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
