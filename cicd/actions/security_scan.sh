#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_VERSION_DIR="$ROOT_DIR/app/versions/$VERSION"
STATE_DIR="$ROOT_DIR/runtime/state"

if [ -z "$VERSION" ]; then
  echo "[security_scan] FAIL: version required"
  exit 1
fi

if [ ! -d "$APP_VERSION_DIR" ]; then
  echo "[security_scan] FAIL: app/versions/$VERSION does not exist"
  exit 1
fi

if grep -RniE '(password|api[_-]?key|secret|AKIA[0-9A-Z]{16})' "$APP_VERSION_DIR"; then
  echo "[security_scan] FAIL: potential secret detected"
  exit 1
fi

mkdir -p "$STATE_DIR"
printf '%s\n' "$VERSION" > "$STATE_DIR/security_scan_version.txt"

echo "[security_scan] PASS: no simple secret patterns found for $VERSION"
