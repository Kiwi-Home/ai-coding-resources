#!/usr/bin/env bash
# PostToolUse hook: session checkpoint staleness watchdog.
#
# Tracks Bash tool call volume during execute-issue sessions and prompts
# the agent to post a Session Checkpoint when extended work periods pass
# without one. Uses an event-count heuristic (not wall-clock time) since
# Claude Code hooks are reactive -- there is no timer/interval mechanism.
#
# Two session-scoped counters:
#   - total: all Bash calls in the session (min_floor gate)
#   - interval: Bash calls since last checkpoint (staleness detection)
#
# Scope guard: only activates on feature branches matching the configured
# branch_pattern. This filters out design sessions, plan reviews, and
# manual work on main/develop branches.
#
# This hook is ADVISORY ONLY -- it always exits 0.
#
# Disable: export CODING_WORKFLOWS_DISABLE_HOOK_CHECKPOINT_STALENESS=1
# Threshold override: export CODING_WORKFLOWS_CHECKPOINT_STALENESS_THRESHOLD=15
# Min floor override: export CODING_WORKFLOWS_CHECKPOINT_STALENESS_MIN_FLOOR=8

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_workflow-config.sh
source "${SCRIPT_DIR}/_workflow-config.sh"

# --- 1. Per-hook disable ---
if check_disabled "CHECKPOINT_STALENESS"; then
  exit 0
fi

# --- 2. Read stdin JSON ---
INPUT=$(cat)

# --- 3. Extract fields ---
SESSION_ID=$(parse_json_field "$INPUT" ".session_id")
COMMAND=$(parse_json_field "$INPUT" ".tool_input.command")

# Fail-open: if we can't parse essential fields, exit silently
if [ -z "$COMMAND" ] || [ -z "$SESSION_ID" ]; then
  exit 0
fi

# --- 4. Scope guard: feature branch detection ---
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
BRANCH_PATTERN=$(get_branch_pattern)
BRANCH_PATTERN="${BRANCH_PATTERN:-feature/*}"

# Convert workflow.yaml pattern (feature/{issue_num}-{description}) to a
# shell glob by replacing {placeholder} tokens with * wildcards.
BRANCH_GLOB=$(echo "$BRANCH_PATTERN" | sed 's/{[^}]*}/*/g')

# Shell glob match against configured pattern
# shellcheck disable=SC2053
if [[ -z "$CURRENT_BRANCH" ]] || [[ "$CURRENT_BRANCH" != $BRANCH_GLOB ]]; then
  exit 0  # Not on a feature branch -- not in execute-issue context
fi

# --- 5. Checkpoint detection (BEFORE counter increment) ---
# Narrow match: gh issue comment AND "Session Checkpoint" in the command string.
# This avoids false resets from non-checkpoint comments while accepting that
# --body-file usage may not be detected (false negative is less harmful than
# false reset).
if echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)gh\s+issue\s+comment\b'; then
  if echo "$COMMAND" | grep -q "Session Checkpoint"; then
    # Reset interval counter, do NOT increment either counter
    local_interval_file=$(_counter_file "checkpoint-staleness-interval" "$SESSION_ID")
    echo 0 > "$local_interval_file" || true
    exit 0
  fi
  # Non-checkpoint issue comment: fall through to increment (does not reset)
fi

# --- 6. Increment both counters (fail-open on write errors) ---
local_total_file=$(_counter_file "checkpoint-staleness-total" "$SESSION_ID")
local_interval_file=$(_counter_file "checkpoint-staleness-interval" "$SESSION_ID")

TOTAL=$(cat "$local_total_file" 2>/dev/null || echo 0)
INTERVAL=$(cat "$local_interval_file" 2>/dev/null || echo 0)

TOTAL=$((TOTAL + 1))
INTERVAL=$((INTERVAL + 1))

echo "$TOTAL" > "$local_total_file" || true
echo "$INTERVAL" > "$local_interval_file" || true

# --- 7. Min floor check ---
CONFIG_MIN_FLOOR=$(get_staleness_min_floor)
MIN_FLOOR=${CODING_WORKFLOWS_CHECKPOINT_STALENESS_MIN_FLOOR:-${CONFIG_MIN_FLOOR:-8}}

if [ "$TOTAL" -lt "$MIN_FLOOR" ]; then
  exit 0
fi

# --- 8. Threshold check and advisory ---
CONFIG_THRESHOLD=$(get_staleness_threshold)
THRESHOLD=${CODING_WORKFLOWS_CHECKPOINT_STALENESS_THRESHOLD:-${CONFIG_THRESHOLD:-15}}

if [ "$INTERVAL" -ge "$THRESHOLD" ]; then
  # Reset interval counter after emitting advisory
  echo 0 > "$local_interval_file" || true

  cat <<HOOKJSON
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "SESSION CHECKPOINT OVERDUE: You have made ${INTERVAL} Bash tool calls since your last Session Checkpoint. Post a progress update to the issue NOW using the Session Checkpoint format (execute-issue command, Session Checkpoint section). Include: (1) completed components with test status, (2) remaining work from the plan, (3) any deviations from the implementation plan. This is advisory -- not blocking."
  }
}
HOOKJSON
fi

exit 0
