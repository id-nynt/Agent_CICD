import os
import random
import time
from typing import Any

from flask import Flask, jsonify, request
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import ConsoleSpanExporter, SimpleSpanProcessor
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, generate_latest


SERVICE_VERSION = os.getenv("SERVICE_VERSION", "stable").strip().lower()
FAILURE_MODE = os.getenv("FAILURE_MODE", "none").strip().lower()
FORCE_ERROR_RATE = float(os.getenv("FORCE_ERROR_RATE", "0") or 0)
EXTRA_LATENCY_MS = int(os.getenv("EXTRA_LATENCY_MS", "0") or 0)
ENABLE_OTEL = os.getenv("ENABLE_OTEL", "false").strip().lower() == "true"

if SERVICE_VERSION not in {"stable", "candidate"}:
    SERVICE_VERSION = "stable"

FORCE_ERROR_RATE = min(max(FORCE_ERROR_RATE, 0.0), 1.0)
EXTRA_LATENCY_SECONDS = max(EXTRA_LATENCY_MS, 0) / 1000

app = Flask(__name__)

if ENABLE_OTEL:
    trace.set_tracer_provider(
        TracerProvider(
            resource=Resource.create(
                {
                    "service.name": "payment-service",
                    "service.version": SERVICE_VERSION,
                }
            )
        )
    )
    trace.get_tracer_provider().add_span_processor(SimpleSpanProcessor(ConsoleSpanExporter()))

TRACER = trace.get_tracer("payment-service")

REQUEST_COUNT = Counter(
    "payment_service_requests_total",
    "Total HTTP requests handled by the payment service.",
    ["version", "method", "endpoint", "status"],
)
ERROR_COUNT = Counter(
    "payment_service_errors_total",
    "Total failed payment service requests.",
    ["version", "endpoint"],
)
REQUEST_LATENCY = Histogram(
    "payment_service_request_latency_seconds",
    "Payment service request latency in seconds.",
    ["version", "endpoint"],
)
HEALTH_GAUGE = Gauge(
    "payment_service_health",
    "Payment service health, where 1 is healthy and 0 is unhealthy.",
    ["version"],
)


def is_healthy() -> bool:
    return FAILURE_MODE not in {"unhealthy", "down"}


def should_fail(operation: str) -> bool:
    if FAILURE_MODE in {"always_error", "error", "fail"}:
        return True
    if FAILURE_MODE == f"{operation}_error":
        return True
    return random.random() < FORCE_ERROR_RATE


def apply_latency() -> None:
    if EXTRA_LATENCY_SECONDS:
        time.sleep(EXTRA_LATENCY_SECONDS)


def record(endpoint: str, status: int, started_at: float) -> None:
    REQUEST_COUNT.labels(SERVICE_VERSION, request.method, endpoint, str(status)).inc()
    REQUEST_LATENCY.labels(SERVICE_VERSION, endpoint).observe(time.time() - started_at)
    if status >= 500:
        ERROR_COUNT.labels(SERVICE_VERSION, endpoint).inc()


def payment_response(operation: str, payload: dict[str, Any] | None) -> tuple[Any, int]:
    started_at = time.time()
    endpoint = f"/{operation}"
    with TRACER.start_as_current_span(f"payment.{operation}") as span:
        span.set_attribute("payment.operation", operation)
        span.set_attribute("payment.version", SERVICE_VERSION)
        span.set_attribute("payment.failure_mode", FAILURE_MODE)
        if payload and payload.get("amount") is not None:
            span.set_attribute("payment.amount", payload["amount"])

        apply_latency()

        if should_fail(operation):
            status = 500
            span.set_attribute("http.status_code", status)
            span.set_attribute("payment.outcome", "error")
            record(endpoint, status, started_at)
            return (
                jsonify(
                    {
                        "status": "error",
                        "operation": operation,
                        "version": SERVICE_VERSION,
                        "message": "failure injected for prototype telemetry",
                    }
                ),
                status,
            )

        status = 200
        span.set_attribute("http.status_code", status)
        span.set_attribute("payment.outcome", "success")
        record(endpoint, status, started_at)
        return (
            jsonify(
                {
                    "status": "success",
                    "operation": operation,
                    "version": SERVICE_VERSION,
                    "amount": (payload or {}).get("amount"),
                }
            ),
            status,
        )


@app.get("/health")
def health() -> tuple[Any, int]:
    started_at = time.time()
    apply_latency()
    healthy = is_healthy()
    HEALTH_GAUGE.labels(SERVICE_VERSION).set(1 if healthy else 0)
    status = 200 if healthy else 503
    record("/health", status, started_at)
    if healthy:
        return "OK\n", status
    return "UNHEALTHY\n", status


@app.post("/pay")
def pay() -> tuple[Any, int]:
    return payment_response("pay", request.get_json(silent=True))


@app.post("/refund")
def refund() -> tuple[Any, int]:
    return payment_response("refund", request.get_json(silent=True))


@app.get("/metrics")
def metrics() -> tuple[bytes, int, dict[str, str]]:
    HEALTH_GAUGE.labels(SERVICE_VERSION).set(1 if is_healthy() else 0)
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8000"))
    app.run(host="0.0.0.0", port=port)
