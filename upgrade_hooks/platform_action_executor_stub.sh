#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}"
TARGET="${2:-}"
VERSION="${3:-}"

if [ -z "$ACTION" ]; then
  echo "Usage: ./upgrade_hooks/platform_action_executor_stub.sh <action> [target] [version]"
  echo "Example: ./upgrade_hooks/platform_action_executor_stub.sh deploy production candidate"
  exit 1
fi

cat <<EOF
{
  "source": "github_actions_or_gitlab_ci_stub",
  "requested_action": "$ACTION",
  "target": "$TARGET",
  "version": "$VERSION",
  "status": "not_executed",
  "notes": "Future executor should translate BDI-selected actions into CI platform jobs."
}
EOF
