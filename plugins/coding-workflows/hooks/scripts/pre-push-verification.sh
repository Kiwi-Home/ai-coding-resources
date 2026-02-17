#!/usr/bin/env bash
# PreToolUse hook: pre-push test/lint/typecheck verification.
#
# Intercepts `git push` commands and verifies fresh passing test/lint/typecheck
# evidence exists before allowing the push. Reads the JSONL evidence file
# written by test-evidence-logger.sh -- never re-runs tests.
#
# Three-layer gate model:
#   Layer 1 (advisory): test-evidence-logger.sh (PostToolUse) -- records results
#   Layer 2 (blocking): THIS HOOK (PreToolUse) -- blocks push without evidence
#   Layer 3 (blocking): execute-issue-completion-gate.sh (Stop) -- blocks exit if CI failing
#
# Evidence staleness: git-dirty check (primary) + timestamp floor (secondary, 30min default).
#
# Default: block mode (denies push without evidence)
# Config: hooks.pre_push_verification.mode = "warn" for advisory only
#
# Timeout: 5000ms (in hooks.json). Higher than 3000ms PreToolUse precedent because
# this hook reads evidence files + runs git status. Fast-path exit for non-push
# commands is <5ms.
#
# Disable: export CODING_WORKFLOWS_DISABLE_HOOK_PRE_PUSH_VERIFICATION=1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_workflow-config.sh
source "${SCRIPT_DIR}/_workflow-config.sh"

# --- Guard: per-hook disable ---
if check_disabled "PRE_PUSH_VERIFICATION"; then
  exit $HOOK_ALLOW
fi

# --- Read stdin JSON ---
INPUT=$(cat)
COMMAND=$(parse_json_field "$INPUT" ".tool_input.command")
[ -z "$COMMAND" ] && exit $HOOK_ALLOW

# === FAST PATH: regex match before any config reading ===

# Match git push commands.
# Anchors: start of string, whitespace, or shell operator (&&, ||, ;)
PUSH_PATTERN='(^|[[:space:]]|&&|\|\||;)git[[:space:]]+push\b'
if ! echo "$COMMAND" | grep -qE "$PUSH_PATTERN"; then
  exit $HOOK_ALLOW
fi

# Exclude --dry-run (not a real push)
if echo "$COMMAND" | grep -qE -- '--dry-run'; then
  exit $HOOK_ALLOW
fi

# Exclude --delete (branch deletion, not code push)
if echo "$COMMAND" | grep -qE -- '--delete'; then
  exit $HOOK_ALLOW
fi

# === PUSH DETECTED: load config and check evidence ===

# Determine mode (block or warn)
MODE=$(get_pre_push_mode)

# Helper: emit deny or advisory based on mode
emit_gate_message() {
  local msg="$1"
  if [ "$MODE" = "warn" ]; then
    pretool_advisory "$msg"
  else
    pretool_deny "$msg"
  fi
}

# Determine git root for evidence filtering
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$GIT_ROOT" ]; then
  # Not in a git repo -- fail-open
  pretool_advisory "Pre-push verification: not in a git repository. Skipping."
fi

# Extract individual command prefixes from workflow.yaml
TEST_CMD=$(get_test_command)
LINT_CMD=$(get_lint_command)
TYPECHECK_CMD=$(get_typecheck_command)

# If no commands configured: advisory warning and allow
if [ -z "$TEST_CMD" ] && [ -z "$LINT_CMD" ] && [ -z "$TYPECHECK_CMD" ]; then
  pretool_advisory "No test/lint/typecheck commands configured in workflow.yaml. Skipping pre-push verification."
fi

# Build list of required commands with labels
declare -a REQUIRED_CMDS=()
declare -a REQUIRED_LABELS=()
if [ -n "$TEST_CMD" ]; then
  REQUIRED_CMDS+=("$TEST_CMD")
  REQUIRED_LABELS+=("test")
fi
if [ -n "$LINT_CMD" ]; then
  REQUIRED_CMDS+=("$LINT_CMD")
  REQUIRED_LABELS+=("lint")
fi
if [ -n "$TYPECHECK_CMD" ]; then
  REQUIRED_CMDS+=("$TYPECHECK_CMD")
  REQUIRED_LABELS+=("typecheck")
fi

# === Scan evidence files ===

# Find all evidence files (handles parallel sessions)
EVIDENCE_FILES=$(ls "${TMPDIR:-/tmp}"/coding-workflows-evidence-*.jsonl 2>/dev/null || true)

if [ -z "$EVIDENCE_FILES" ]; then
  # Build actionable deny message
  required_cmds_msg=""
  for i in "${!REQUIRED_CMDS[@]}"; do
    required_cmds_msg="${required_cmds_msg}  ${REQUIRED_LABELS[$i]}: ${REQUIRED_CMDS[$i]}\n"
  done
  emit_gate_message "Pre-push verification failed: No test evidence found. Run the following before pushing:\n${required_cmds_msg}Override: export CODING_WORKFLOWS_DISABLE_HOOK_PRE_PUSH_VERIFICATION=1"
fi

# Check for passing evidence for each required command, filtered by git_root.
# Track the oldest passing timestamp for staleness check.
OLDEST_PASS_TS=""
MISSING_CATEGORIES=""

for i in "${!REQUIRED_CMDS[@]}"; do
  cmd_prefix="${REQUIRED_CMDS[$i]}"
  cmd_label="${REQUIRED_LABELS[$i]}"
  found_passing="false"

  # Scan all evidence files, read last 50 lines of each
  while IFS= read -r efile; do
    [ -f "$efile" ] || continue

    # Parse entries: filter by git_root match and command prefix match and exit_code 0
    if command -v jq &>/dev/null; then
      # Use jq to find the most recent passing entry matching git_root and command prefix
      match_ts=$(tail -50 "$efile" 2>/dev/null | jq -r \
        --arg gr "$GIT_ROOT" --arg prefix "$cmd_prefix" \
        'select(.git_root == $gr and (.cmd | startswith($prefix)) and .exit_code == 0) | .ts' \
        2>/dev/null | tail -1 || true)
    elif command -v python3 &>/dev/null; then
      match_ts=$(tail -50 "$efile" 2>/dev/null | python3 -c "
import json, sys
best_ts = ''
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        d = json.loads(line)
        if d.get('git_root') == '$GIT_ROOT' and d.get('cmd','').startswith('$cmd_prefix') and d.get('exit_code') == 0:
            best_ts = d.get('ts', '')
    except: pass
print(best_ts)
" 2>/dev/null || true)
    else
      # No JSON parser available -- fail-open
      pretool_advisory "Pre-push verification: no JSON parser available (jq or python3 required). Push allowed."
    fi

    if [ -n "$match_ts" ]; then
      found_passing="true"
      # Track oldest passing timestamp across all categories
      if [ -z "$OLDEST_PASS_TS" ] || [[ "$match_ts" < "$OLDEST_PASS_TS" ]]; then
        OLDEST_PASS_TS="$match_ts"
      fi
      break
    fi
  done <<< "$EVIDENCE_FILES"

  if [ "$found_passing" = "false" ]; then
    MISSING_CATEGORIES="${MISSING_CATEGORIES}${MISSING_CATEGORIES:+, }${cmd_label} (${cmd_prefix})"
  fi
done

# If any required category is missing passing evidence, deny
if [ -n "$MISSING_CATEGORIES" ]; then
  emit_gate_message "Pre-push verification failed: No passing evidence for: ${MISSING_CATEGORIES}. Run the required commands before pushing. Override: export CODING_WORKFLOWS_DISABLE_HOOK_PRE_PUSH_VERIFICATION=1"
fi

# === Staleness check: git-dirty ===

GIT_STATUS_OUTPUT=$(timeout 2 git status --porcelain 2>/dev/null) || {
  # timeout or git status failed -- fail-open with advisory
  pretool_advisory "Pre-push verification: git status timed out or failed. Push allowed."
}

if [ -n "$GIT_STATUS_OUTPUT" ]; then
  emit_gate_message "Pre-push verification failed: Working tree has uncommitted changes since last test run. Run tests and linter before pushing. Override: export CODING_WORKFLOWS_DISABLE_HOOK_PRE_PUSH_VERIFICATION=1"
fi

# === Staleness check: timestamp floor ===

THRESHOLD_MINUTES=$(get_pre_push_staleness_threshold)
THRESHOLD_MINUTES="${THRESHOLD_MINUTES:-30}"

if [ -n "$OLDEST_PASS_TS" ] && command -v python3 &>/dev/null; then
  IS_STALE=$(python3 -c "
from datetime import datetime, timezone, timedelta
import sys
try:
    ts_str = '$OLDEST_PASS_TS'.replace('Z', '+00:00')
    ts = datetime.fromisoformat(ts_str)
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=timezone.utc)
    now = datetime.now(timezone.utc)
    threshold = timedelta(minutes=$THRESHOLD_MINUTES)
    print('stale' if (now - ts) > threshold else 'fresh')
except:
    print('fresh')
" 2>/dev/null || echo "fresh")

  if [ "$IS_STALE" = "stale" ]; then
    emit_gate_message "Pre-push verification failed: Test evidence is stale (>${THRESHOLD_MINUTES}min old). Re-run tests before pushing. Override: export CODING_WORKFLOWS_DISABLE_HOOK_PRE_PUSH_VERIFICATION=1"
  fi
fi

# === All checks passed ===
exit $HOOK_ALLOW
