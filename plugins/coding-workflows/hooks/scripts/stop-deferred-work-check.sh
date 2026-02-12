#!/usr/bin/env bash
# Stop hook: advisory check for deferred work when Claude finishes responding.
#
# Searches the session transcript for deferred-work language ("deferred",
# "follow-up", "future work", "out of scope") that is NOT accompanied by a
# follow-up issue reference. Outputs a warning to stderr if found.
#
# This hook is ADVISORY ONLY -- it always exits 0 and never blocks stopping.
# Blocking a Stop hook forces Claude to continue, which risks infinite loops
# or wasted context.
#
# Disable: export CODING_WORKFLOWS_DISABLE_HOOK_STOP_DEFERRED_WORK=1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_workflow-config.sh
source "${SCRIPT_DIR}/_workflow-config.sh"

# --- Guard: prevent infinite loop ---
INPUT=$(cat)
STOP_ACTIVE=$(parse_json_field "$INPUT" ".stop_hook_active")
if [ "$STOP_ACTIVE" = "true" ]; then
  exit $HOOK_ALLOW
fi

# --- Guard: per-hook disable ---
if check_disabled "STOP_DEFERRED_WORK"; then
  exit $HOOK_ALLOW
fi

# --- Read transcript ---
TRANSCRIPT_PATH=$(parse_json_field "$INPUT" ".transcript_path")
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  # No transcript available -- nothing to check.
  exit $HOOK_ALLOW
fi

# Search the last 200 lines of the transcript for deferred-work patterns.
# Using case-insensitive grep for natural language matching.
TAIL_LINES=$(tail -200 "$TRANSCRIPT_PATH" 2>/dev/null || true)

if [ -z "$TAIL_LINES" ]; then
  exit $HOOK_ALLOW
fi

# Check for deferred-work language
DEFERRED_PATTERN='deferred|follow.up|future work|out of scope|TODO.*later|will address later'
DEFERRED_MATCHES=$(echo "$TAIL_LINES" | grep -Eic "$DEFERRED_PATTERN" 2>/dev/null || true)

if [ "${DEFERRED_MATCHES:-0}" -eq 0 ]; then
  exit $HOOK_ALLOW
fi

# Check if there's also a follow-up issue reference (suggests work IS tracked)
ISSUE_REF_PATTERN='#[0-9]+|github\.com/.*/issues/[0-9]+|follow-up issue|tracking issue'
ISSUE_REFS=$(echo "$TAIL_LINES" | grep -Eic "$ISSUE_REF_PATTERN" 2>/dev/null || true)

if [ "${ISSUE_REFS:-0}" -gt 0 ]; then
  # Deferred work found but issue references also present -- likely tracked.
  exit $HOOK_ALLOW
fi

# Advisory warning: deferred work detected without tracking references.
advisory_warn "Detected ${DEFERRED_MATCHES} mention(s) of deferred work in recent transcript without follow-up issue references. Check that all deferred work is either completed inline or tracked in a follow-up issue per the issue-workflow skill."

exit $HOOK_ALLOW
