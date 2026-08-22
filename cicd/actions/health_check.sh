#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_DIR="$ROOT_DIR/runtime/state"

if [ -z "$ENVIRONMENT" ]; then
  echo "[health_check] FAIL: environment required"
  exit 1
fi

if [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "production" ]; then
  echo "[health_check] FAIL: environment must be staging or production"
  exit 1
fi

if [ "$ENVIRONMENT" = "staging" ]; then
  URL="http://localhost:8001/health"
else
  URL="http://localhost:8002/health"
fi

if command -v curl >/dev/null 2>&1; then
  CURL_BIN="curl"
elif command -v curl.exe >/dev/null 2>&1; then
  CURL_BIN="curl.exe"
else
  echo "[health_check] FAIL: curl is required to call $URL"
  exit 1
fi

RESPONSE=""
for attempt in 1 2 3 4 5 6; do
  if RESPONSE="$("$CURL_BIN" -fsS "$URL" 2>/dev/null)"; then
    break
  fi
  sleep 2
done

if [ "$(printf '%s' "$RESPONSE" | tr -d '\r\n')" != "OK" ]; then
  echo "[health_check] FAIL: $ENVIRONMENT health endpoint did not return OK"
  exit 1
fi

mkdir -p "$STATE_DIR"
printf '%s\n' "$URL" > "$STATE_DIR/${ENVIRONMENT}_health_url.txt"
printf '%s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$STATE_DIR/${ENVIRONMENT}_health_checked_at.txt"

echo "[health_check] PASS: $ENVIRONMENT is healthy at $URL"
