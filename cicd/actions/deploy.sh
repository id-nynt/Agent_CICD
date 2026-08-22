#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-}"
VERSION="${2:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_DIR="$ROOT_DIR/runtime/state"

if [ -z "$ENVIRONMENT" ] || [ -z "$VERSION" ]; then
  echo "[deploy] FAIL: environment and version required"
  exit 1
fi

if [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "production" ]; then
  echo "[deploy] FAIL: environment must be staging or production"
  exit 1
fi

if [ "$VERSION" != "stable" ] && [ "$VERSION" != "candidate" ]; then
  echo "[deploy] FAIL: version must be stable or candidate"
  exit 1
fi

if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  echo "[deploy] FAIL: Docker Compose is required to deploy the real local service"
  exit 1
fi

mkdir -p "$STATE_DIR"

if [ "$ENVIRONMENT" = "production" ] && [ -f "$STATE_DIR/production_version.txt" ]; then
  cp "$STATE_DIR/production_version.txt" "$STATE_DIR/previous_production_version.txt"
fi

if [ "$ENVIRONMENT" = "staging" ]; then
  SERVICE_NAME="payment-staging"
  export PAYMENT_STAGING_VERSION="$VERSION"
  export PAYMENT_STAGING_FAILURE_MODE="${PAYMENT_STAGING_FAILURE_MODE:-none}"
  export PAYMENT_STAGING_FORCE_ERROR_RATE="${PAYMENT_STAGING_FORCE_ERROR_RATE:-0}"
  export PAYMENT_STAGING_EXTRA_LATENCY_MS="${PAYMENT_STAGING_EXTRA_LATENCY_MS:-0}"
else
  SERVICE_NAME="payment-production"
  export PAYMENT_PRODUCTION_VERSION="$VERSION"
  export PAYMENT_PRODUCTION_FAILURE_MODE="${PAYMENT_PRODUCTION_FAILURE_MODE:-none}"
  export PAYMENT_PRODUCTION_FORCE_ERROR_RATE="${PAYMENT_PRODUCTION_FORCE_ERROR_RATE:-0}"
  export PAYMENT_PRODUCTION_EXTRA_LATENCY_MS="${PAYMENT_PRODUCTION_EXTRA_LATENCY_MS:-0}"
fi

docker compose -f "$ROOT_DIR/docker-compose.yml" up -d --no-deps --build "$SERVICE_NAME"
docker compose -f "$ROOT_DIR/docker-compose.yml" up -d --no-deps prometheus

printf '%s\n' "$VERSION" > "$STATE_DIR/${ENVIRONMENT}_version.txt"
printf '%s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$STATE_DIR/${ENVIRONMENT}_deployed_at.txt"

echo "[deploy] PASS: deployed $VERSION to $ENVIRONMENT using $SERVICE_NAME"
