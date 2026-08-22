#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVICE_DIR="$ROOT_DIR/app/payment_service"
STATE_DIR="$ROOT_DIR/runtime/state"

if [ -z "$VERSION" ]; then
  echo "[security_scan] FAIL: version required"
  exit 1
fi

if [ "$VERSION" != "stable" ] && [ "$VERSION" != "candidate" ]; then
  echo "[security_scan] FAIL: version must be stable or candidate"
  exit 1
fi

if [ ! -d "$SERVICE_DIR" ]; then
  echo "[security_scan] FAIL: app/payment_service does not exist"
  exit 1
fi

SCAN_TARGETS=(
  "$SERVICE_DIR/service.py"
  "$SERVICE_DIR/requirements.txt"
  "$SERVICE_DIR/Dockerfile"
  "$SERVICE_DIR/.dockerignore"
  "$ROOT_DIR/docker-compose.yml"
  "$ROOT_DIR/runtime/prometheus/prometheus.yml"
)

if grep -RniE '(password|api[_-]?key|secret|token|AKIA[0-9A-Z]{16})' "${SCAN_TARGETS[@]}"; then
  echo "[security_scan] FAIL: potential secret detected"
  exit 1
fi

mkdir -p "$STATE_DIR"
printf '%s\n' "$VERSION" > "$STATE_DIR/security_scan_version.txt"

echo "[security_scan] PASS: no simple secret patterns found for payment service $VERSION"
