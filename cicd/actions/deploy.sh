#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-}"
VERSION="${2:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_VERSION_DIR="$ROOT_DIR/app/versions/$VERSION"
DEPLOY_DIR="$ROOT_DIR/runtime/deployments/$ENVIRONMENT"
STATE_DIR="$ROOT_DIR/runtime/state"

if [ -z "$ENVIRONMENT" ] || [ -z "$VERSION" ]; then
  echo "[deploy] FAIL: environment and version required"
  exit 1
fi

if [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "production" ]; then
  echo "[deploy] FAIL: environment must be staging or production"
  exit 1
fi

if [ ! -d "$APP_VERSION_DIR" ]; then
  echo "[deploy] FAIL: app/versions/$VERSION does not exist"
  exit 1
fi

mkdir -p "$DEPLOY_DIR" "$STATE_DIR"

if [ "$ENVIRONMENT" = "production" ] && [ -f "$STATE_DIR/production_version.txt" ]; then
  cp "$STATE_DIR/production_version.txt" "$STATE_DIR/previous_production_version.txt"
fi

rm -rf "$DEPLOY_DIR"/*
cp "$APP_VERSION_DIR/config.json" "$DEPLOY_DIR/"
cp "$APP_VERSION_DIR/health.txt" "$DEPLOY_DIR/"
cp "$APP_VERSION_DIR/index.html" "$DEPLOY_DIR/"

printf '%s\n' "$VERSION" > "$STATE_DIR/${ENVIRONMENT}_version.txt"

echo "[deploy] PASS: deployed $VERSION to $ENVIRONMENT"
