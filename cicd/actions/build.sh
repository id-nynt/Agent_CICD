#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_VERSION_DIR="$ROOT_DIR/app/versions/$VERSION"
STATE_DIR="$ROOT_DIR/runtime/state"

if [ -z "$VERSION" ]; then
  echo "[build] FAIL: version required"
  exit 1
fi

if [ ! -d "$APP_VERSION_DIR" ]; then
  echo "[build] FAIL: app/versions/$VERSION does not exist"
  exit 1
fi

for file in config.json health.txt index.html; do
  if [ ! -f "$APP_VERSION_DIR/$file" ]; then
    echo "[build] FAIL: missing $file for $VERSION"
    exit 1
  fi
done

if ! grep -q '"version"' "$APP_VERSION_DIR/config.json"; then
  echo "[build] FAIL: config.json has no version field"
  exit 1
fi

mkdir -p "$STATE_DIR"
printf '%s\n' "$VERSION" > "$STATE_DIR/build_version.txt"

echo "[build] PASS: built $VERSION"
