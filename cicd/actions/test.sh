#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_VERSION_DIR="$ROOT_DIR/app/versions/$VERSION"
STATE_DIR="$ROOT_DIR/runtime/state"

if [ -z "$VERSION" ]; then
  echo "[test] FAIL: version required"
  exit 1
fi

if [ ! -d "$APP_VERSION_DIR" ]; then
  echo "[test] FAIL: app/versions/$VERSION does not exist"
  exit 1
fi

if ! grep -q '"service": "payment-service"' "$APP_VERSION_DIR/config.json"; then
  echo "[test] FAIL: unexpected service name"
  exit 1
fi

if [ "$(tr -d '\r\n' < "$APP_VERSION_DIR/health.txt")" != "OK" ]; then
  echo "[test] FAIL: health.txt must contain OK"
  exit 1
fi

mkdir -p "$STATE_DIR"
printf '%s\n' "$VERSION" > "$STATE_DIR/test_version.txt"

echo "[test] PASS: tests passed for $VERSION"
