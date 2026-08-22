#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOY_DIR="$ROOT_DIR/runtime/deployments/$ENVIRONMENT"

if [ -z "$ENVIRONMENT" ]; then
  echo "[health_check] FAIL: environment required"
  exit 1
fi

if [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "production" ]; then
  echo "[health_check] FAIL: environment must be staging or production"
  exit 1
fi

if [ ! -f "$DEPLOY_DIR/health.txt" ]; then
  echo "[health_check] FAIL: $ENVIRONMENT has no deployed health.txt"
  exit 1
fi

if [ "$(tr -d '\r\n' < "$DEPLOY_DIR/health.txt")" != "OK" ]; then
  echo "[health_check] FAIL: $ENVIRONMENT health is not OK"
  exit 1
fi

echo "[health_check] PASS: $ENVIRONMENT is healthy"
