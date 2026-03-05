#!/usr/bin/env bash
set -euo pipefail
export GIT_TERMINAL_PROMPT=0
GIT_TIMEOUT="${GIT_TIMEOUT:-90}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REGISTRY_PATH="${OPENCLAW_GATEWAY_REGISTRY:-$REPO_ROOT/ops/gateway-registry.yaml}"
REGISTRY_TOOL="$SCRIPT_DIR/registry_tool.py"

usage() {
  cat <<USAGE
Usage: sync-team-repo.sh --name <gateway_name>
USAGE
}

registry_get() {
  local name="$1"
  local field="$2"
  python3 "$REGISTRY_TOOL" --registry "$REGISTRY_PATH" get --name "$name" --field "$field" --expand
}

main() {
  local name=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)
        name="$2"; shift 2 ;;
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
  repo_dir="$(registry_get "$name" team_work_dir)"
  branch="$(registry_get "$name" team_repo_branch)"

  if [[ ! -d "$repo_dir/.git" ]]; then
    echo "No git repo found at: $repo_dir"
    exit 0
  fi

  git -C "$repo_dir" remote get-url origin >/dev/null 2>&1 || {
    echo "No origin remote configured for $repo_dir. Skip sync."
    exit 0
  }

  timeout "$GIT_TIMEOUT" git -C "$repo_dir" fetch origin --prune

  if git -C "$repo_dir" show-ref --quiet "refs/remotes/origin/$branch"; then
    timeout "$GIT_TIMEOUT" git -C "$repo_dir" checkout -B "$branch" "origin/$branch"
  else
    timeout "$GIT_TIMEOUT" git -C "$repo_dir" checkout -B "$branch"
  fi

  if git -C "$repo_dir" show-ref --quiet "refs/remotes/origin/main"; then
    timeout "$GIT_TIMEOUT" git -C "$repo_dir" rebase "origin/main" || {
      timeout "$GIT_TIMEOUT" git -C "$repo_dir" rebase --abort || true
      echo "Rebase against origin/main failed for $name" >&2
      exit 1
    }
  fi

  if git -C "$repo_dir" show-ref --quiet "refs/remotes/origin/$branch"; then
    timeout "$GIT_TIMEOUT" git -C "$repo_dir" pull --rebase origin "$branch"
  fi

  echo "Synced team-work repo for $name on branch $branch"
}

main "$@"
