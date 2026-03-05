#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REGISTRY_PATH="${OPENCLAW_GATEWAY_REGISTRY:-$REPO_ROOT/ops/gateway-registry.yaml}"
REGISTRY_TOOL="$SCRIPT_DIR/registry_tool.py"

usage() {
  cat <<USAGE
Usage: workspace-sync.sh --name <gateway_name> [--reason <text>]
USAGE
}

registry_get() {
  local name="$1"
  local field="$2"
  python3 "$REGISTRY_TOOL" --registry "$REGISTRY_PATH" get --name "$name" --field "$field" --expand
}

main() {
  local name=""
  local reason="event-sync"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)
        name="$2"; shift 2 ;;
      --reason)
        reason="$2"; shift 2 ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        echo "Unknown argument: $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  [[ -n "$name" ]] || { echo "--name is required" >&2; exit 1; }

  local repo_dir branch
  repo_dir="$(registry_get "$name" workspace_dir)"
  branch="$(registry_get "$name" workspace_branch)"

  if [[ ! -d "$repo_dir/.git" ]]; then
    echo "No workspace git repo found at: $repo_dir"
    exit 0
  fi

  git -C "$repo_dir" checkout -B "$branch" >/dev/null

  if [[ -z "$(git -C "$repo_dir" status --porcelain)" ]]; then
    echo "Workspace clean for $name; skip commit."
  else
    git -C "$repo_dir" add -A
    git -C "$repo_dir" commit -m "workspace($name): $reason"
  fi

  if git -C "$repo_dir" remote get-url origin >/dev/null 2>&1; then
    git -C "$repo_dir" push -u origin "$branch"
  else
    echo "No origin remote for workspace $name; skip push."
  fi

  echo "Workspace sync done for $name"
}

main "$@"
