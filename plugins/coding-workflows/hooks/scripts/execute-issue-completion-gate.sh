#!/usr/bin/env bash
# Stop hook: blocks premature session exit during the CI+Review loop.
#
# Checks PR state via `gh` CLI. Uses open-PR-on-current-branch as the sole
# activation signal (no transcript scanning). Fails open on all errors.
# Escalates to human after configurable threshold (default 3 blocked stops).
#
# Two gates:
#   1. CI gate (always active): blocks while checks are pending or failing.
#   2. Review gate (opt-in): blocks until review verdict is found.
#      Requires `review_gate: true` in workflow.yaml under
#      hooks.execute_issue_completion_gate. Without it, the hook allows
#      exit after CI passes.
#
# This is an INTENTIONAL DEPARTURE from the advisory-only pattern in
# stop-deferred-work-check.sh. The advisory hook warns but cannot prevent
# premature exit -- which is exactly the failure mode #98 addresses. The
# escalation counter (default 3 blocks, then advisory-only) prevents infinite
# loops: after N blocked stops, the hook degrades to advisory mode and allows
# exit with a human-escalation message.
#
# Disable: export CODING_WORKFLOWS_DISABLE_HOOK_EXECUTE_ISSUE_COMPLETION_GATE=1
# Threshold override: export CODING_WORKFLOWS_ESCALATION_THRESHOLD=5
# Review gate: set review_gate: true in workflow.yaml hooks section

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_workflow-config.sh
source "${SCRIPT_DIR}/_workflow-config.sh"

# --- 1. Read stdin JSON ---
INPUT=$(cat)

# --- 2. Recursion guard ---
STOP_ACTIVE=$(parse_json_field "$INPUT" ".stop_hook_active")
if [ "$STOP_ACTIVE" = "true" ]; then
  exit $HOOK_ALLOW
fi

# --- 3. Per-hook disable ---
if check_disabled "EXECUTE_ISSUE_COMPLETION_GATE"; then
  exit $HOOK_ALLOW
fi

# --- 4. Branch check ---
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || true)
if [ -z "$CURRENT_BRANCH" ]; then
  # Detached HEAD or not in a git repo
  exit $HOOK_ALLOW
fi

DEFAULT_BRANCH=$(get_default_branch)
if [ "$CURRENT_BRANCH" = "$DEFAULT_BRANCH" ]; then
  exit $HOOK_ALLOW
fi

# --- 5. PR check (short-circuit for non-execute-issue workflows) ---
if ! command -v gh &>/dev/null; then
  advisory_warn "gh CLI not found. Cannot check PR state. Allowing stop."
  exit $HOOK_ALLOW
fi

PR_NUMBER=$(gh pr list --head "$CURRENT_BRANCH" --state open \
  --json number -q '.[0].number' 2>/dev/null || true)

if [ -z "$PR_NUMBER" ]; then
  # No open PR on this branch -- not in a CI+Review loop
  exit $HOOK_ALLOW
fi

# --- 6. Escalation counter ---
TRANSCRIPT_PATH=$(parse_json_field "$INPUT" ".transcript_path")
BLOCK_COUNT=$(get_block_count "completion-gate" "$TRANSCRIPT_PATH")
REVIEW_GATE=$(is_review_gate_enabled)
CONFIG_THRESHOLD=$(get_escalation_threshold)
THRESHOLD=${CODING_WORKFLOWS_ESCALATION_THRESHOLD:-${CONFIG_THRESHOLD:-3}}

if [ "$BLOCK_COUNT" -ge "$THRESHOLD" ]; then
  advisory_warn "Stop blocked $BLOCK_COUNT times (threshold: $THRESHOLD). Escalating to human. Review CI+Review loop status for PR #$PR_NUMBER manually."
  exit $HOOK_ALLOW
fi

# --- 7. CI check ---
CI_JSON=$(gh pr checks "$PR_NUMBER" --json name,state,conclusion 2>/dev/null || true)
if [ -z "$CI_JSON" ]; then
  advisory_warn "Could not check CI status for PR #$PR_NUMBER (gh error). Allowing stop."
  exit $HOOK_ALLOW
fi

# Check for pending checks
PENDING_NAMES=""
if command -v jq &>/dev/null; then
  PENDING_NAMES=$(echo "$CI_JSON" | jq -r '.[] | select(.state == "PENDING") | .name' 2>/dev/null || true)
elif command -v python3 &>/dev/null; then
  PENDING_NAMES=$(echo "$CI_JSON" | python3 -c "
import json, sys
try:
    checks = json.load(sys.stdin)
    for c in checks:
        if c.get('state','').upper() == 'PENDING':
            print(c.get('name','unknown'))
except:
    pass
" 2>/dev/null || true)
fi

if [ -n "$PENDING_NAMES" ]; then
  increment_block_count "completion-gate" "$TRANSCRIPT_PATH"
  block_with_reason "CI checks still running on PR #$PR_NUMBER. Wait for CI to complete before stopping."
fi

# Check for failed checks
FAILED_NAMES=""
if command -v jq &>/dev/null; then
  FAILED_NAMES=$(echo "$CI_JSON" | jq -r '.[] | select(.state == "COMPLETED" and .conclusion != "SUCCESS" and .conclusion != "NEUTRAL" and .conclusion != "SKIPPED") | .name' 2>/dev/null || true)
elif command -v python3 &>/dev/null; then
  FAILED_NAMES=$(echo "$CI_JSON" | python3 -c "
import json, sys
try:
    checks = json.load(sys.stdin)
    for c in checks:
        if c.get('state','').upper() == 'COMPLETED' and c.get('conclusion','').upper() not in ('SUCCESS','NEUTRAL','SKIPPED'):
            print(c.get('name','unknown'))
except:
    pass
" 2>/dev/null || true)
fi

if [ -n "$FAILED_NAMES" ]; then
  increment_block_count "completion-gate" "$TRANSCRIPT_PATH"
  block_with_reason "CI checks failing on PR #$PR_NUMBER. Fix failures and push before stopping."
fi

# --- 8. Review gate check ---
# Review polling is opt-in via workflow.yaml. Without it, CI passing is
# sufficient to allow exit (the execute-issue command still has its own
# review loop -- this hook just won't enforce it).
if [ "$REVIEW_GATE" != "true" ]; then
  exit $HOOK_ALLOW
fi

# --- 9-10. Review check ---
COMMENTS_JSON=$(gh pr view "$PR_NUMBER" --json comments 2>/dev/null || true)
if [ -z "$COMMENTS_JSON" ]; then
  advisory_warn "Could not fetch PR #$PR_NUMBER comments (gh error). Allowing stop."
  exit $HOOK_ALLOW
fi

# Find the most recent review comment by highest content-review-iteration:N marker.
# Extract all comments, find the one with the highest iteration number.
LATEST_REVIEW=""
if command -v jq &>/dev/null; then
  LATEST_REVIEW=$(echo "$COMMENTS_JSON" | jq -r '
    [.comments[]
     | select(.body | test("content-review-iteration:[0-9]+"))
     | {body, iter: (.body | capture("content-review-iteration:(?<n>[0-9]+)") | .n | tonumber)}]
    | sort_by(.iter)
    | last
    | .body // empty
  ' 2>/dev/null || true)
elif command -v python3 &>/dev/null; then
  LATEST_REVIEW=$(echo "$COMMENTS_JSON" | python3 -c "
import json, sys, re
try:
    data = json.load(sys.stdin)
    comments = data.get('comments', [])
    best = None
    best_iter = -1
    for c in comments:
        body = c.get('body', '')
        m = re.search(r'content-review-iteration:(\d+)', body)
        if m:
            n = int(m.group(1))
            if n > best_iter:
                best_iter = n
                best = body
    if best:
        print(best)
except:
    pass
" 2>/dev/null || true)
fi

# --- 10. Check for unqualified "Ready to merge" ---
if [ -n "$LATEST_REVIEW" ]; then
  # Verdict match is case-sensitive (format prescribed by pr-review skill).
  # Qualification check below is case-insensitive (natural language after verdict).
  if echo "$LATEST_REVIEW" | grep -qF "$VERDICT_READY"; then
    # Reject qualified approvals: "Ready to merge" followed by qualifying words.
    # Separator class `[[:space:],;:\-]*` matches zero or more separator chars
    # (comma, semicolon, colon, dash, whitespace) to handle natural language
    # variations like "Ready to merge, once..." or "Ready to merge: pending...".
    QUALIFIED=$(echo "$LATEST_REVIEW" | grep -iE "${VERDICT_READY}[[:space:],;:\-]*(once|after|pending|with|when|if|but)" || true)
    if [ -z "$QUALIFIED" ]; then
      # Unqualified approval -- valid exit
      exit $HOOK_ALLOW
    fi
  fi

  # Check for blocking items
  if echo "$LATEST_REVIEW" | grep -qF "$VERDICT_MUST_FIX"; then
    increment_block_count "completion-gate" "$TRANSCRIPT_PATH"
    block_with_reason "Unresolved $VERDICT_MUST_FIX items in review for PR #$PR_NUMBER. Address all blocking items before stopping."
  fi

  if echo "$LATEST_REVIEW" | grep -qF "$VERDICT_FIX_NOW"; then
    increment_block_count "completion-gate" "$TRANSCRIPT_PATH"
    block_with_reason "Unresolved $VERDICT_FIX_NOW items in review for PR #$PR_NUMBER. Address all blocking items before stopping."
  fi

  # Review exists but no clear verdict
  advisory_warn "Review comment found on PR #$PR_NUMBER but no clear verdict detected. Verify CI+Review loop status."
  exit $HOOK_ALLOW
fi

# No review comment found
increment_block_count "completion-gate" "$TRANSCRIPT_PATH"
block_with_reason "No review comment found on PR #$PR_NUMBER. Wait for review before stopping."
