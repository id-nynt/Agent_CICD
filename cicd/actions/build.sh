#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVICE_DIR="$ROOT_DIR/app/payment_service"
STATE_DIR="$ROOT_DIR/runtime/state"

if [ -z "$VERSION" ]; then
  echo "[build] FAIL: version required"
  exit 1
fi

if [ "$VERSION" != "stable" ] && [ "$VERSION" != "candidate" ]; then
  echo "[build] FAIL: version must be stable or candidate"
  exit 1
fi

for file in service.py requirements.txt Dockerfile; do
  if [ ! -f "$SERVICE_DIR/$file" ]; then
    echo "[build] FAIL: missing app/payment_service/$file"
    exit 1
  fi
done

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  docker compose -f "$ROOT_DIR/docker-compose.yml" build payment-staging payment-production
  BUILD_MODE="docker"
else
  echo "[build] WARN: Docker Compose unavailable; validating service files only"
  BUILD_MODE="local-fallback"
fi

if command -v python >/dev/null 2>&1; then
  python -m py_compile "$SERVICE_DIR/service.py"
elif command -v py >/dev/null 2>&1; then
  py -m py_compile "$SERVICE_DIR/service.py"
else
  echo "[build] WARN: Python unavailable; skipped local syntax check"
fi

if ! grep -q "Flask" "$SERVICE_DIR/requirements.txt"; then
  echo "[build] FAIL: requirements.txt must include Flask"
  exit 1
fi

if ! grep -q "prometheus-client" "$SERVICE_DIR/requirements.txt"; then
  echo "[build] FAIL: requirements.txt must include prometheus-client"
  exit 1
fi

mkdir -p "$STATE_DIR"
printf '%s\n' "$VERSION" > "$STATE_DIR/build_version.txt"
printf '%s\n' "$BUILD_MODE" > "$STATE_DIR/build_mode.txt"

echo "[build] PASS: built payment service image for $VERSION ($BUILD_MODE)"
