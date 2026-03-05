#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REGISTRY_PATH="${OPENCLAW_GATEWAY_REGISTRY:-$REPO_ROOT/ops/gateway-registry.yaml}"
REGISTRY_TOOL="$SCRIPT_DIR/registry_tool.py"
WORKSPACE_SYNC="$SCRIPT_DIR/workspace-sync.sh"

usage() {
  cat <<USAGE
Usage:
  mailbox-send.sh --from <gateway> --to <gateway|all> --subject <text> --body-file <path>
USAGE
}

registry_get() {
  local name="$1"
  local field="$2"
  python3 "$REGISTRY_TOOL" --registry "$REGISTRY_PATH" get --name "$name" --field "$field" --expand
}

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//' | cut -c1-64
}

main() {
  local from=""
  local to=""
  local subject=""
  local body_file=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from)
        from="$2"; shift 2 ;;
      --to)
        to="$2"; shift 2 ;;
      --subject)
        subject="$2"; shift 2 ;;
      --body-file)
        body_file="$2"; shift 2 ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        echo "Unknown argument: $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  [[ -n "$from" && -n "$to" && -n "$subject" && -n "$body_file" ]] || {
    echo "Missing required argument" >&2
    usage
    exit 1
  }

  [[ -f "$body_file" ]] || { echo "Body file not found: $body_file" >&2; exit 1; }

  local repo_dir branch ts day slug out_dir out_file trace_id
  repo_dir="$(registry_get "$from" team_work_dir)"
  branch="$(registry_get "$from" team_repo_branch)"

  [[ -d "$repo_dir/.git" ]] || { echo "team-work repo is not initialized: $repo_dir" >&2; exit 1; }

  if [[ -z "$(git -C "$repo_dir" config --get user.name || true)" ]]; then
    git -C "$repo_dir" config user.name "openclaw-gateway-bot"
  fi
  if [[ -z "$(git -C "$repo_dir" config --get user.email || true)" ]]; then
    git -C "$repo_dir" config user.email "openclaw-gateway-bot@local"
  fi

  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  day="$(date -u +%Y/%m/%d)"
  slug="$(slugify "$subject")"
  trace_id="$(python3 - <<'PY'
import uuid
print(uuid.uuid4().hex)
PY
)"

  out_dir="$repo_dir/mailbox/outbox/$from/$day"
  mkdir -p "$out_dir"
  out_file="$out_dir/${ts}-${to}-${slug}.md"

  cat > "$out_file" <<MSG
from: $from
to: $to
subject: $subject
ts: $ts
trace_id: $trace_id

$(cat "$body_file")
MSG

  git -C "$repo_dir" checkout -B "$branch" >/dev/null
  git -C "$repo_dir" add "$out_file"
  git -C "$repo_dir" commit -m "mailbox($from->$to): $subject" >/dev/null || true

  if git -C "$repo_dir" remote get-url origin >/dev/null 2>&1; then
    git -C "$repo_dir" push -u origin "$branch"
  else
    echo "No origin remote. Message committed locally only."
  fi

  # Event-triggered workspace sync for sender gateway.
  "$WORKSPACE_SYNC" --name "$from" --reason "mailbox:$subject" || {
    echo "Workspace sync hook failed for $from" >&2
  }

  echo "Mailbox message created: $out_file"
}

main "$@"
