#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIR="$ROOT_DIR/app/versions"
RUNTIME_DIR="$ROOT_DIR/runtime"

mkdir -p "$RUNTIME_DIR/deployments/staging" "$RUNTIME_DIR/deployments/production" "$RUNTIME_DIR/state"

rm -rf "$RUNTIME_DIR/deployments/staging"/*
rm -rf "$RUNTIME_DIR/deployments/production"/*

cp "$APP_DIR/stable/config.json" "$RUNTIME_DIR/deployments/production/"
cp "$APP_DIR/stable/health.txt" "$RUNTIME_DIR/deployments/production/"
cp "$APP_DIR/stable/index.html" "$RUNTIME_DIR/deployments/production/"

printf '%s\n' "stable" > "$RUNTIME_DIR/state/production_version.txt"
printf '%s\n' "stable" > "$RUNTIME_DIR/state/previous_production_version.txt"
rm -f "$RUNTIME_DIR/state/staging_version.txt"

echo "[reset] PASS: runtime reset with stable in production"
