#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_DIR="$ROOT_DIR/runtime/state"
DEPLOY_DIR="$ROOT_DIR/runtime/deployments/production"

if [ -z "$ENVIRONMENT" ]; then
  echo "[rollback] FAIL: environment required"
  exit 1
fi

if [ "$ENVIRONMENT" != "production" ]; then
  echo "[rollback] FAIL: only production rollback is supported"
  exit 1
fi

if [ ! -f "$STATE_DIR/previous_production_version.txt" ]; then
  echo "[rollback] FAIL: previous production version is unknown"
  exit 1
fi

PREVIOUS_VERSION="$(tr -d '\r\n' < "$STATE_DIR/previous_production_version.txt")"
APP_VERSION_DIR="$ROOT_DIR/app/versions/$PREVIOUS_VERSION"

if [ ! -d "$APP_VERSION_DIR" ]; then
  echo "[rollback] FAIL: app/versions/$PREVIOUS_VERSION does not exist"
  exit 1
fi

mkdir -p "$DEPLOY_DIR" "$STATE_DIR"
rm -rf "$DEPLOY_DIR"/*
cp "$APP_VERSION_DIR/config.json" "$DEPLOY_DIR/"
cp "$APP_VERSION_DIR/health.txt" "$DEPLOY_DIR/"
cp "$APP_VERSION_DIR/index.html" "$DEPLOY_DIR/"

printf '%s\n' "$PREVIOUS_VERSION" > "$STATE_DIR/production_version.txt"

echo "[rollback] PASS: restored production to $PREVIOUS_VERSION"
