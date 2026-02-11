#!/usr/bin/env bash
# PostToolUse / PostToolUseFailure hook: test/lint evidence logging.
#
# Complements the Verification Gate in issue-workflow skill (Step 4.5).
# Matches test/lint/typecheck commands from workflow.yaml and maintains a
# session-scoped evidence trail. On test failure, injects advisory context
# reminding Claude that fresh passing evidence is required before any
# completion claim.
#
# This hook is ADVISORY ONLY -- it always exits 0.
#
# Disable: export CODING_WORKFLOWS_DISABLE_HOOK_TEST_EVIDENCE_LOGGER=1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_workflow-config.sh
source "${SCRIPT_DIR}/_workflow-config.sh"

# --- Guard: per-hook disable ---
if check_disabled "TEST_EVIDENCE_LOGGER"; then
  exit 0
fi

# --- Read stdin JSON ---
INPUT=$(cat)

# --- Extract fields ---
HOOK_EVENT=$(parse_json_field "$INPUT" ".hook_event_name")
COMMAND=$(parse_json_field "$INPUT" ".tool_input.command")
SESSION_ID=$(parse_json_field "$INPUT" ".session_id")

# Fail-open: if we can't parse essential fields, exit silently
if [ -z "$COMMAND" ] || [ -z "$SESSION_ID" ]; then
  exit 0
fi

# --- Get cached test/lint commands ---
CACHE_FILE=$(get_test_lint_commands "$SESSION_ID")

# Fail-open: if no test/lint commands configured, exit silently
if ! is_test_or_lint_command "$COMMAND" "$CACHE_FILE"; then
  exit 0
fi

# --- Extract exit code based on hook event type ---
EXIT_CODE=""
IS_FAILURE="false"

if [ "$HOOK_EVENT" = "PostToolUseFailure" ]; then
  IS_FAILURE="true"
  # Parse exit code from .error string (e.g., "Command exited with non-zero status code 1")
  ERROR_MSG=$(parse_json_field "$INPUT" ".error")
  EXIT_CODE=$(echo "$ERROR_MSG" | grep -oE 'status code [0-9]+' | grep -oE '[0-9]+$' || true)
  if [ -z "$EXIT_CODE" ]; then
    EXIT_CODE="1"  # Assume failure
  fi
else
  # PostToolUse: try multiple field names for exit code
  EXIT_CODE=$(parse_json_field "$INPUT" ".tool_response.exit_code")
  if [ -z "$EXIT_CODE" ]; then
    EXIT_CODE=$(parse_json_field "$INPUT" ".tool_response.exitCode")
  fi
  if [ -z "$EXIT_CODE" ]; then
    # Try parsing from stdout (some versions include "exit code: N")
    local_stdout=$(parse_json_field "$INPUT" ".tool_response.stdout")
    EXIT_CODE=$(echo "$local_stdout" | grep -oE 'exit code:?\s*[0-9]+' | tail -1 | grep -oE '[0-9]+$' || true)
  fi
  if [ -z "$EXIT_CODE" ]; then
    EXIT_CODE="0"  # Assume success if we can't determine
  fi
fi

# --- Log evidence ---
EVIDENCE_LOG="${TMPDIR:-/tmp}/coding-workflows-evidence-${SESSION_ID}.jsonl"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")

# Count output lines from tool_response
LINE_COUNT=$(parse_json_field "$INPUT" ".tool_response.stdout" | wc -l 2>/dev/null | tr -d ' ' || echo "0")

# Extract failure context on non-zero exit (last 3 lines of stdout, truncated to 500 chars)
FAILURE_CONTEXT=""
if [ "$EXIT_CODE" != "0" ] || [ "$IS_FAILURE" = "true" ]; then
  FAILURE_CONTEXT=$(parse_json_field "$INPUT" ".tool_response.stdout" | tail -3 2>/dev/null | tr -cd '[:print:][:space:]' | head -c 500 || true)
fi

# Append JSONL entry
if command -v jq &>/dev/null; then
  if [ -n "$FAILURE_CONTEXT" ]; then
    jq -n --arg ts "$TIMESTAMP" --arg cmd "$COMMAND" --argjson ec "$EXIT_CODE" --argjson lines "$LINE_COUNT" \
      --arg fc "$FAILURE_CONTEXT" \
      '{ts: $ts, cmd: $cmd, exit_code: $ec, lines: $lines, failure_context: $fc}' >> "$EVIDENCE_LOG" 2>/dev/null
  else
    jq -n --arg ts "$TIMESTAMP" --arg cmd "$COMMAND" --argjson ec "$EXIT_CODE" --argjson lines "$LINE_COUNT" \
      '{ts: $ts, cmd: $cmd, exit_code: $ec, lines: $lines}' >> "$EVIDENCE_LOG" 2>/dev/null
  fi
else
  if [ -n "$FAILURE_CONTEXT" ]; then
    FC_SAFE=$(printf '%s' "$FAILURE_CONTEXT" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g' | head -c 500)
    echo "{\"ts\":\"${TIMESTAMP}\",\"cmd\":\"$(echo "$COMMAND" | head -c 200)\",\"exit_code\":${EXIT_CODE},\"lines\":${LINE_COUNT},\"failure_context\":\"${FC_SAFE}\"}" >> "$EVIDENCE_LOG" 2>/dev/null
  else
    echo "{\"ts\":\"${TIMESTAMP}\",\"cmd\":\"$(echo "$COMMAND" | head -c 200)\",\"exit_code\":${EXIT_CODE},\"lines\":${LINE_COUNT}}" >> "$EVIDENCE_LOG" 2>/dev/null
  fi
fi

# --- Inject advisory context on failure ---
if [ "$EXIT_CODE" != "0" ] || [ "$IS_FAILURE" = "true" ]; then
  HOOK_NAME="${HOOK_EVENT:-PostToolUse}"
  cat <<HOOKJSON
{
  "hookSpecificOutput": {
    "hookEventName": "${HOOK_NAME}",
    "additionalContext": "WARNING: The most recent test/lint command failed (exit code ${EXIT_CODE}). The Verification Gate (issue-workflow skill, Step 4.5) requires fresh passing evidence before any completion claim. Do not claim tests pass or proceed to PR creation until you re-run and see passing output. Red flag: Do not trust memory of a previous passing run. Evidence log: ${EVIDENCE_LOG}"
  }
}
HOOKJSON
fi

exit 0
