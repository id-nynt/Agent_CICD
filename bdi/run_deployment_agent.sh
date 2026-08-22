#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

WINDOWS_JASON_BAT="C:\\Program Files\\jason-bin-3.3.0\\bin\\jason.bat"
WINDOWS_JASON_BASH="/c/Program Files/jason-bin-3.3.0/bin/jason.bat"

if [ -f "$WINDOWS_JASON_BASH" ] && command -v powershell.exe >/dev/null 2>&1; then
  export JASON_HOME="${JASON_HOME:-C:\\Program Files\\jason-bin-3.3.0}"
  (cd "$ROOT_DIR" && powershell.exe -NoProfile -Command "& '$WINDOWS_JASON_BAT' 'bdi\\project.mas2j'")
  exit 0
fi

if command -v jason >/dev/null 2>&1; then
  (cd "$ROOT_DIR" && jason bdi/project.mas2j)
  exit 0
fi

echo "[deployment_agent_runner] FAIL: Jason executable not found"
exit 1
