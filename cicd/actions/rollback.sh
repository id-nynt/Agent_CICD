#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_DIR="$ROOT_DIR/runtime/state"

if [ -z "$ENVIRONMENT" ]; then
  echo "[rollback] FAIL: environment required"
  exit 1
fi

if [ "$ENVIRONMENT" != "production" ]; then
  echo "[rollback] FAIL: only production rollback is supported"
  exit 1
fi

if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  echo "[rollback] FAIL: Docker Compose is required to rollback the real local service"
  exit 1
fi

ROLLBACK_VERSION="stable"

mkdir -p "$STATE_DIR"

if [ -f "$STATE_DIR/production_version.txt" ]; then
  cp "$STATE_DIR/production_version.txt" "$STATE_DIR/previous_production_version.txt"
fi

export PAYMENT_PRODUCTION_VERSION="$ROLLBACK_VERSION"
export PAYMENT_PRODUCTION_FAILURE_MODE="${PAYMENT_PRODUCTION_FAILURE_MODE:-none}"
export PAYMENT_PRODUCTION_FORCE_ERROR_RATE="${PAYMENT_PRODUCTION_FORCE_ERROR_RATE:-0}"
export PAYMENT_PRODUCTION_EXTRA_LATENCY_MS="${PAYMENT_PRODUCTION_EXTRA_LATENCY_MS:-0}"

docker compose -f "$ROOT_DIR/docker-compose.yml" up -d --no-deps --build payment-production
docker compose -f "$ROOT_DIR/docker-compose.yml" up -d --no-deps prometheus

printf '%s\n' "$ROLLBACK_VERSION" > "$STATE_DIR/production_version.txt"
printf '%s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$STATE_DIR/production_rolled_back_at.txt"

echo "[rollback] PASS: restored production to $ROLLBACK_VERSION"
