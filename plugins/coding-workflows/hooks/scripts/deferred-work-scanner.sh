#!/usr/bin/env bash
# PostToolUse hook: PR deferral scanning.
#
# Complements stop-deferred-work-check.sh (Stop hook) -- this hook provides
# precision scanning of PR bodies at creation time, while the Stop hook
# provides a broad safety net across the session transcript.
#
# Matches `gh pr create` commands, fetches the PR body via `gh pr view`,
# and scans for untracked deferral language. On finding untracked deferrals,
# injects advisory context referencing the Follow-Up Issue Threshold.
#
# This hook is ADVISORY ONLY -- it always exits 0.
#
# Disable: export CODING_WORKFLOWS_DISABLE_HOOK_DEFERRED_WORK_SCANNER=1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_workflow-config.sh
source "${SCRIPT_DIR}/_workflow-config.sh"

# --- Guard: per-hook disable ---
if check_disabled "DEFERRED_WORK_SCANNER"; then
  exit 0
fi

# --- Read stdin JSON ---
INPUT=$(cat)

# --- Extract command ---
COMMAND=$(parse_json_field "$INPUT" ".tool_input.command")

if [ -z "$COMMAND" ]; then
  exit 0
fi

# --- Match: gh pr create (handles chained commands) ---
if ! echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)gh\s+pr\s+create\b'; then
  exit 0
fi

# --- Extract PR URL from tool_response ---
PR_URL=$(parse_json_field "$INPUT" ".tool_response.stdout")
if [ -z "$PR_URL" ]; then
  PR_URL=$(parse_json_field "$INPUT" ".tool_response")
fi

# Validate it looks like a PR URL
if ! echo "$PR_URL" | grep -qE 'github\.com/.*/pull/[0-9]+'; then
  exit 0
fi

# --- Fetch PR body via gh pr view ---
PR_BODY=$(gh pr view "$PR_URL" --json body -q '.body' 2>/dev/null || true)

if [ -z "$PR_BODY" ]; then
  exit 0
fi

# --- Pre-filter: strip code fences and blockquotes ---
# Remove language-tagged code fences (```python, ```bash, etc.) but preserve
# plain fences (used for requirements lists, structured output).
# Uses GFM info-string heuristic: ^```[a-zA-Z] marks a strippable block.
FILTERED_BODY=$(echo "$PR_BODY" | sed '/^[[:space:]]*```[a-zA-Z]/,/^[[:space:]]*```[[:space:]]*$/d' 2>/dev/null || echo "$PR_BODY")
# Remove blockquote lines
FILTERED_BODY=$(echo "$FILTERED_BODY" | grep -v '^[[:space:]]*>' 2>/dev/null || echo "$FILTERED_BODY")

# --- Scan line-by-line for untracked deferrals ---
UNTRACKED=""

while IFS= read -r line; do
  # Skip empty lines
  [ -z "$line" ] && continue

  # Check if line contains deferral language (case-insensitive)
  if ! echo "$line" | grep -qEi "$DEFERRAL_PATTERNS"; then
    continue
  fi

  # Check if same line contains an issue reference (tracked)
  if echo "$line" | grep -qE "$ISSUE_REF_PATTERNS"; then
    continue
  fi

  # Check for negative constructions (false positives)
  if echo "$line" | grep -qEi "$NEGATIVE_PATTERNS"; then
    continue
  fi

  # Untracked deferral found -- collect it
  # Trim line for display (max 120 chars), sanitize for JSON embedding.
  # Escape backslashes and double quotes for JSON safety, replace single
  # quotes with backticks to avoid shell quoting issues.
  TRIMMED=$(echo "$line" | sed 's/^[[:space:]]*//' | head -c 120)
  TRIMMED=$(printf '%s' "$TRIMMED" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr "'" '`')
  if [ -n "$UNTRACKED" ]; then
    UNTRACKED="${UNTRACKED}, '${TRIMMED}'"
  else
    UNTRACKED="'${TRIMMED}'"
  fi
done <<< "$FILTERED_BODY"

# --- Inject advisory context if untracked deferrals found ---
if [ -n "$UNTRACKED" ]; then
  cat <<HOOKJSON
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "WARNING: The PR body contains deferral language without associated issue links: [${UNTRACKED}]. Per the Deferred Work Tracking rule (issue-workflow skill, Step 4.7), evaluate each against the Follow-Up Issue Threshold: (1) crosses module/service/repo boundary, (2) needs its own design/requirements analysis, (3) risk-elevating for reviewers. Default: do it inline in the current PR. Only create a follow-up issue if the deferral meets one of these criteria."
  }
}
HOOKJSON
fi

exit 0
