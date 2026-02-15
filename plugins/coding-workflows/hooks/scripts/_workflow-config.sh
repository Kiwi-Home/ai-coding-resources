# Shared utility for coding-workflows hook scripts.
# Source this file -- do not execute directly.
# No shebang, no exit calls (would exit the caller).

# JSON field extraction with jq / python3 fallback.
# Usage: parse_json_field "$json_string" ".field.path"
# Returns empty string on any failure (fail-open for callers that need it).
parse_json_field() {
  local input="$1" field="$2"
  if command -v jq &>/dev/null; then
    echo "$input" | jq -r "$field // empty" 2>/dev/null
  elif command -v python3 &>/dev/null; then
    echo "$input" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    keys = '${field}'.lstrip('.').split('.')
    v = d
    for k in keys:
        if isinstance(v, dict):
            v = v.get(k, '')
        else:
            v = ''
            break
    print(v if v else '')
except:
    print('')
" 2>/dev/null
  else
    echo ""
  fi
}

# --- Hook disable variable naming convention ---
# Env var pattern: CODING_WORKFLOWS_DISABLE_HOOK_{HOOK_NAME}
#
# Derivation rules (applied in order):
#   1. Strip .sh extension
#   2. Replace hyphens with underscores, convert to UPPER_CASE
#   3. Drop "CHECK" -- remove leading CHECK_ prefix or trailing _CHECK suffix
#      (the word "check" is implementation noise, not descriptive of what the hook protects)
#
# Rule 3 explains all shortened names without ad-hoc exceptions:
#
#   Script filename                     → After rule 2            → After rule 3 (HOOK_NAME)
#   check-dependency-version.sh         → CHECK_DEPENDENCY_VERSION → DEPENDENCY_VERSION (*)
#   check-agent-output-completeness.sh  → CHECK_AGENT_OUTPUT_...   → AGENT_OUTPUT_COMPLETENESS
#   stop-deferred-work-check.sh         → STOP_DEFERRED_WORK_CHECK → STOP_DEFERRED_WORK
#   test-evidence-logger.sh             → TEST_EVIDENCE_LOGGER     → TEST_EVIDENCE_LOGGER (no change)
#   deferred-work-scanner.sh            → DEFERRED_WORK_SCANNER    → DEFERRED_WORK_SCANNER (no change)
#   execute-issue-completion-gate.sh    → EXECUTE_ISSUE_COMP...     → EXECUTE_ISSUE_COMPLETION_GATE (no change)
#
#   (*) check-dependency-version uses DEPENDENCY_VERSION_CHECK (CHECK moved to suffix)
#       for semantic clarity: the hook checks that a version was provided.
#       This is the sole exception to rule 3's mechanical stripping.

# Per-hook disable check.
# Usage: check_disabled "STOP_DEFERRED_WORK" && return 0
# The env var checked is CODING_WORKFLOWS_DISABLE_HOOK_{hook_name}.
check_disabled() {
  local hook_name="$1"
  local var_name="CODING_WORKFLOWS_DISABLE_HOOK_${hook_name}"
  # Use eval for indirect expansion -- safe because hook_name is always a
  # hardcoded constant from our own scripts, never user input.
  eval "[ \"\${${var_name}:-}\" = \"1\" ]"
}

# --- Shared pattern constants ---
# Used by both PostToolUse deferred-work-scanner and Stop deferred-work-check.
DEFERRAL_PATTERNS='TODO|FIXME|deferred|follow.up|future work|out of scope'
ISSUE_REF_PATTERNS='#[0-9]+|github\.com/.*/issues/[0-9]+'
NEGATIVE_PATTERNS='no silent|addressed inline|not deferred|completed inline|done inline'

# Locate workflow.yaml by searching from CWD upward.
# Returns the path if found, empty string otherwise.
find_workflow_yaml() {
  local dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/.claude/workflow.yaml" ]; then
      echo "$dir/.claude/workflow.yaml"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  echo ""
}

# Extract test/lint/typecheck command prefixes from workflow.yaml.
# Caches results per session. Returns the cache file path.
# Usage: cache_path=$(get_test_lint_commands "$session_id")
get_test_lint_commands() {
  local session_id="$1"
  local cache_file="${TMPDIR:-/tmp}/coding-workflows-commands-${session_id}.txt"

  local yaml_path
  yaml_path=$(find_workflow_yaml)

  # Return cached if exists AND is newer than workflow.yaml (mtime check).
  # If yaml_path is empty or gone, -nt fails → regenerate (safe).
  if [ -f "$cache_file" ] && [ -n "$yaml_path" ] && [ "$cache_file" -nt "$yaml_path" ]; then
    echo "$cache_file"
    return 0
  fi

  if [ -z "$yaml_path" ]; then
    # No workflow.yaml -- write empty cache (fail-open)
    touch "$cache_file"
    echo "$cache_file"
    return 0
  fi

  local prefixes=""

  # Helper: validate extracted command value.
  # Strips leading whitespace, then checks non-empty and not a comment.
  _is_valid_command() {
    local val="$1"
    val=$(printf '%s' "$val" | sed 's/^[[:space:]]*//')
    [ -n "$val" ] && ! printf '%s' "$val" | grep -qE '^#'
  }

  # Helper: extract value after a YAML key, strip quotes and whitespace.
  # Portable across macOS (BSD sed) and Linux (GNU sed).
  _extract_yaml_value() {
    local line="$1"
    # Remove everything up to and including the key + colon
    local val
    val=$(echo "$line" | sed 's/^[^:]*:[[:space:]]*//')
    # Strip surrounding quotes (single or double)
    val=$(echo "$val" | sed 's/^["'"'"']//' | sed 's/["'"'"']$//')
    # Extract prefix before {path} placeholder
    val=$(echo "$val" | sed 's/[[:space:]]*{path}.*//')
    # Strip trailing dot (e.g., "ruff check ." → "ruff check")
    val=$(echo "$val" | sed 's/[[:space:]]*\.$//')
    # Strip trailing whitespace
    val=$(echo "$val" | sed 's/[[:space:]]*$//')
    echo "$val"
  }

  # Extract test.full command
  local test_full_line test_full
  test_full_line=$(grep -A5 '^[[:space:]]*test:' "$yaml_path" 2>/dev/null | grep '[[:space:]]*full:' | head -1 || true)
  test_full=$(_extract_yaml_value "$test_full_line")
  if _is_valid_command "$test_full"; then
    prefixes="${prefixes}${test_full}"$'\n'
  fi

  # Extract test.focused command
  local test_focused_line test_focused
  test_focused_line=$(grep -A5 '^[[:space:]]*test:' "$yaml_path" 2>/dev/null | grep '[[:space:]]*focused:' | head -1 || true)
  test_focused=$(_extract_yaml_value "$test_focused_line")
  if _is_valid_command "$test_focused" && [ "$test_focused" != "$test_full" ]; then
    prefixes="${prefixes}${test_focused}"$'\n'
  fi

  # Extract lint command
  local lint_line lint_cmd
  lint_line=$(grep '^[[:space:]]*lint:' "$yaml_path" 2>/dev/null | head -1 || true)
  lint_cmd=$(_extract_yaml_value "$lint_line")
  if _is_valid_command "$lint_cmd"; then
    prefixes="${prefixes}${lint_cmd}"$'\n'
  fi

  # Extract typecheck command
  local typecheck_line typecheck_cmd
  typecheck_line=$(grep '^[[:space:]]*typecheck:' "$yaml_path" 2>/dev/null | head -1 || true)
  typecheck_cmd=$(_extract_yaml_value "$typecheck_line")
  if _is_valid_command "$typecheck_cmd"; then
    prefixes="${prefixes}${typecheck_cmd}"$'\n'
  fi

  # Write prefixes to cache, stripping empty and whitespace-only lines.
  # (May be empty -- that's fine, means fail-open.)
  printf '%s' "$prefixes" | grep -v '^[[:space:]]*$' > "$cache_file" 2>/dev/null || touch "$cache_file"
  echo "$cache_file"
}

# Check if a command matches any cached test/lint prefix.
# Usage: is_test_or_lint_command "$command" "$cache_file"
# Returns 0 (match) or 1 (no match).
is_test_or_lint_command() {
  local command="$1" cache_file="$2"

  # Empty cache = no commands configured = no match
  if [ ! -s "$cache_file" ]; then
    return 1
  fi

  # Check if command contains any cached prefix
  while IFS= read -r prefix; do
    if [ -n "$prefix" ] && echo "$command" | grep -qF "$prefix"; then
      return 0
    fi
  done < "$cache_file"

  return 1
}

# --- Hook-specific config readers ---

# Check if the review gate is enabled in workflow.yaml.
# Returns "true" or "false" (string). Defaults to "false" if not configured.
is_review_gate_enabled() {
  local yaml_path
  yaml_path=$(find_workflow_yaml)
  [ -z "$yaml_path" ] && { echo "false"; return 0; }
  local value
  value=$(grep -A10 'execute_issue_completion_gate:' "$yaml_path" 2>/dev/null \
    | grep '[[:space:]]*review_gate:' | head -1 \
    | sed 's/^[^:]*:[[:space:]]*//' | sed 's/[[:space:]]*$//' \
    | tr '[:upper:]' '[:lower:]' || true)
  [ "$value" = "true" ] && echo "true" || echo "false"
}

# Read escalation_threshold from workflow.yaml hooks config.
# Returns the numeric value or empty string if not configured.
# Callers should fall back to env var or default.
get_escalation_threshold() {
  local yaml_path
  yaml_path=$(find_workflow_yaml)
  [ -z "$yaml_path" ] && { echo ""; return 0; }
  local value
  value=$(grep -A10 'execute_issue_completion_gate:' "$yaml_path" 2>/dev/null \
    | grep '[[:space:]]*escalation_threshold:' | head -1 \
    | sed 's/^[^:]*:[[:space:]]*//' | sed 's/[[:space:]]*$//' || true)
  echo "$value"
}

# --- Exit code constants ---
HOOK_ALLOW=0
HOOK_BLOCK=2

# --- Verdict string constants (single source of truth) ---
VERDICT_READY="Ready to merge"
VERDICT_MUST_FIX="MUST FIX"
VERDICT_FIX_NOW="FIX NOW"

# --- Advisory/blocking helpers ---
advisory_warn() {
  echo "[coding-workflows] Warning: $1" >&2
}

block_with_reason() {
  echo "[coding-workflows] Blocked: $1" >&2
  exit $HOOK_BLOCK
}

# --- Portable hashing (reads from stdin, writes hash to stdout) ---
# Guarantees non-empty output on all code paths.
# Usage: echo -n "$str" | _portable_hash
#        _portable_hash < "$file"
_portable_hash() {
  local hash
  if command -v md5sum &>/dev/null; then
    hash=$(md5sum | cut -d' ' -f1)
  elif command -v md5 &>/dev/null; then
    hash=$(md5 -q)
  elif command -v cksum &>/dev/null; then
    hash=$(cksum | cut -d' ' -f1)
  else
    hash=$(date +%s)
  fi
  echo "$hash"
}

# --- Escalation counter (temp file persistence) ---
# Uses ${TMPDIR}/coding-workflows-{hook_name}-{hash} files.
# Hash is derived from transcript_path to scope counters per session.
#
# Lifetime: counters are session-scoped via the transcript path hash.
# They persist in $TMPDIR (or /tmp) across process restarts within the
# same Claude Code session. They are NOT cleaned up automatically --
# files are small (<10 bytes) and become inert when a new session starts
# (new transcript path → new hash → new counter file).
# Old counter files are harmless and will be removed by OS tmpfile cleanup.
_counter_file() {
  local hook_name="$1" transcript_path="$2"
  local hash
  hash=$(echo -n "$transcript_path" | _portable_hash)
  echo "${TMPDIR:-/tmp}/coding-workflows-${hook_name}-${hash}"
}

get_block_count() {
  local file
  file=$(_counter_file "$1" "$2")
  if [ -f "$file" ]; then cat "$file" 2>/dev/null || echo 0; else echo 0; fi
}

increment_block_count() {
  local file
  file=$(_counter_file "$1" "$2")
  local count
  count=$(get_block_count "$1" "$2")
  echo $((count + 1)) > "$file"
}

# --- Text section helper ---
has_section() {
  echo "$1" | grep -qiF "$2"
}

# --- Default branch detection ---
# Optional parameter: remote name (default: origin).
# Identity remote = the remote used for org/repo resolution (from
# workflow.yaml project.remote), distinct from the push target.
# Callers that know the identity remote pass it explicitly;
# existing callers with no argument get origin behavior.
get_default_branch() {
  local remote_name="${1:-origin}"
  local default_branch
  default_branch=$(git symbolic-ref "refs/remotes/${remote_name}/HEAD" 2>/dev/null \
    | sed "s|refs/remotes/${remote_name}/||")
  if [ -z "$default_branch" ]; then
    if git show-ref --verify --quiet refs/heads/main 2>/dev/null; then
      default_branch="main"
    else
      default_branch="master"
    fi
  fi
  echo "$default_branch"
}

# --- PreToolUse output helpers ---
# PreToolUse hooks use hookSpecificOutput with permissionDecision (allow/deny/ask)
# and top-level systemMessage. This differs from PostToolUse/Stop hooks which use
# additionalContext inside hookSpecificOutput or top-level decision/reason.

# Advisory: inject context but allow the command to proceed.
# Usage: pretool_advisory "Warning message"
pretool_advisory() {
  local msg="$1"
  local escaped
  escaped=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | tr '\n' ' ')
  cat <<HOOKJSON
{
  "hookSpecificOutput": {
    "permissionDecision": "allow"
  },
  "systemMessage": "${escaped}"
}
HOOKJSON
  exit $HOOK_ALLOW
}

# Deny: block the tool call with a reason shown to Claude.
# Usage: pretool_deny "Reason for blocking"
pretool_deny() {
  local msg="$1"
  local escaped
  escaped=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | tr '\n' ' ')
  cat <<HOOKJSON
{
  "hookSpecificOutput": {
    "permissionDecision": "deny"
  },
  "systemMessage": "${escaped}"
}
HOOKJSON
  exit $HOOK_ALLOW
}

# --- YAML array reader ---
# Read a YAML array under a section key.
# Returns one item per line. Empty output = no items or section not found.
# Supports block format only (- item). Flow format ([a, b]) is NOT supported.
# Usage: read_yaml_array "$yaml_path" "check_dependency_version" "allowlist"
read_yaml_array() {
  local yaml_path="$1" section="$2" key="$3"
  # Pipeline may fail if section/key not found. The || true ensures
  # a clean exit under set -euo pipefail (the caller gets empty output).
  grep -A100 "${section}:" "$yaml_path" 2>/dev/null \
    | grep -A100 "${key}:" \
    | tail -n +2 \
    | while IFS= read -r line; do
        # Stop at next non-array line (not starting with whitespace+dash)
        echo "$line" | grep -qE '^[[:space:]]*-' || break
        echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//' | sed 's/[[:space:]]*$//'
      done || true
}

# --- Dependency version check config readers ---

# Get dependency check mode from workflow.yaml.
# Returns "warn" (default) or "block".
get_dependency_check_mode() {
  local yaml_path
  yaml_path=$(find_workflow_yaml)
  [ -z "$yaml_path" ] && { echo "warn"; return 0; }
  local value
  # || true ensures clean exit if section not found in workflow.yaml
  value=$(grep -A10 'check_dependency_version:' "$yaml_path" 2>/dev/null \
    | grep '[[:space:]]*mode:' | head -1 \
    | sed 's/^[^:]*:[[:space:]]*//' | sed 's/[[:space:]]*$//' \
    | tr '[:upper:]' '[:lower:]' || true)
  if [ "$value" = "block" ]; then echo "block"; else echo "warn"; fi
}

# Get dependency check allowlist from workflow.yaml.
# Returns one package name per line. Empty if not configured.
get_dependency_check_allowlist() {
  local yaml_path
  yaml_path=$(find_workflow_yaml)
  [ -z "$yaml_path" ] && return 0
  read_yaml_array "$yaml_path" "check_dependency_version" "allowlist"
}

# Get dependency check package manager filter from workflow.yaml.
# Returns one PM name per line. Empty = all supported PMs.
get_dependency_check_package_managers() {
  local yaml_path
  yaml_path=$(find_workflow_yaml)
  [ -z "$yaml_path" ] && return 0
  read_yaml_array "$yaml_path" "check_dependency_version" "package_managers"
}
