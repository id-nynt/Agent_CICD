#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVICE_DIR="$ROOT_DIR/app/payment_service"
STATE_DIR="$ROOT_DIR/runtime/state"

if [ -z "$VERSION" ]; then
  echo "[test] FAIL: version required"
  exit 1
fi

if [ "$VERSION" != "stable" ] && [ "$VERSION" != "candidate" ]; then
  echo "[test] FAIL: version must be stable or candidate"
  exit 1
fi

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  docker compose -f "$ROOT_DIR/docker-compose.yml" config >/dev/null
else
  echo "[test] WARN: Docker Compose unavailable; skipped compose config validation"
fi

if command -v python >/dev/null 2>&1; then
  python -m py_compile "$SERVICE_DIR/service.py"
elif command -v py >/dev/null 2>&1; then
  py -m py_compile "$SERVICE_DIR/service.py"
else
  echo "[test] FAIL: Python is required for local service syntax test"
  exit 1
fi

for route in "/health" "/pay" "/refund" "/metrics"; do
  if ! grep -q "\"$route\"" "$SERVICE_DIR/service.py"; then
    echo "[test] FAIL: service.py does not define $route"
    exit 1
  fi
done

if ! grep -q "payment_service_requests_total" "$SERVICE_DIR/service.py"; then
  echo "[test] FAIL: request counter metric is missing"
  exit 1
fi

if ! grep -q "payment_service_health" "$SERVICE_DIR/service.py"; then
  echo "[test] FAIL: health gauge metric is missing"
  exit 1
fi

mkdir -p "$STATE_DIR"
printf '%s\n' "$VERSION" > "$STATE_DIR/test_version.txt"

echo "[test] PASS: service tests passed for $VERSION"
