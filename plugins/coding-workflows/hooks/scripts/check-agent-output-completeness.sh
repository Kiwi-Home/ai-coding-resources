#!/usr/bin/env bash
# SubagentStop hook: validates subagent output contains expected structured sections.
#
# Uses a config file (_completion-patterns.json) mapping agent roles to required
# sections. Reads the subagent's transcript to extract output content. Fails open
# on all errors.
#
# Leniency principle: Only blocks on clearly incomplete output (all sections
# missing AND suspiciously short). Missing one section out of two is a warning,
# not a block.
#
# Disable: export CODING_WORKFLOWS_DISABLE_HOOK_AGENT_OUTPUT_COMPLETENESS=1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_workflow-config.sh
source "${SCRIPT_DIR}/_workflow-config.sh"

# --- 1. Read stdin JSON ---
INPUT=$(cat)

# --- 2. Per-hook disable ---
if check_disabled "AGENT_OUTPUT_COMPLETENESS"; then
  exit $HOOK_ALLOW
fi

# --- 3. Read completion patterns config ---
CONFIG_FILE="${SCRIPT_DIR}/_completion-patterns.json"
if [ ! -f "$CONFIG_FILE" ]; then
  advisory_warn "Completion patterns config not found at $CONFIG_FILE. Allowing completion."
  exit $HOOK_ALLOW
fi

CONFIG=$(cat "$CONFIG_FILE" 2>/dev/null || true)
if [ -z "$CONFIG" ]; then
  advisory_warn "Could not read completion patterns config. Allowing completion."
  exit $HOOK_ALLOW
fi

# --- 4. Extract output from subagent transcript ---
AGENT_TRANSCRIPT=$(parse_json_field "$INPUT" ".agent_transcript_path")
AGENT_TYPE=$(parse_json_field "$INPUT" ".agent_type")

if [ -z "$AGENT_TRANSCRIPT" ] || [ ! -f "$AGENT_TRANSCRIPT" ]; then
  # No transcript available -- cannot validate
  exit $HOOK_ALLOW
fi

# Read the last portion of the transcript to get the agent's final output.
# Transcript is JSONL format; extract the last assistant message content.
OUTPUT_TEXT=""
if command -v jq &>/dev/null; then
  OUTPUT_TEXT=$(tail -20 "$AGENT_TRANSCRIPT" 2>/dev/null | while IFS= read -r line; do
    echo "$line"
  done | jq -r 'select(.role == "assistant") | .content // empty' 2>/dev/null | tail -1 || true)
elif command -v python3 &>/dev/null; then
  OUTPUT_TEXT=$(tail -20 "$AGENT_TRANSCRIPT" 2>/dev/null | python3 -c "
import json, sys
last_content = ''
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
        if obj.get('role') == 'assistant':
            content = obj.get('content', '')
            if isinstance(content, list):
                texts = [b.get('text','') for b in content if b.get('type') == 'text']
                content = ' '.join(texts)
            if content:
                last_content = content
    except:
        pass
print(last_content)
" 2>/dev/null || true)
fi

if [ -z "$OUTPUT_TEXT" ]; then
  # Could not extract output -- fail open
  exit $HOOK_ALLOW
fi

# --- 5. Determine role from agent type or output content ---
ROLE=""

# Check agent_type against known roles
case "$AGENT_TYPE" in
  *reviewer*|*review*)
    ROLE="reviewer"
    ;;
  *architect*)
    ROLE="architect"
    ;;
esac

# If still undetermined, search output for role indicators
if [ -z "$ROLE" ]; then
  if echo "$OUTPUT_TEXT" | grep -qiE '(role:\s*reviewer|as a reviewer|review verdict)'; then
    ROLE="reviewer"
  elif echo "$OUTPUT_TEXT" | grep -qiE '(role:\s*architect|as an architect|architecture)'; then
    ROLE="architect"
  fi
fi

# Fall back to default
if [ -z "$ROLE" ]; then
  ROLE="default"
fi

# --- 6. Look up required sections for role ---
REQUIRED_SECTIONS=""
if command -v jq &>/dev/null; then
  REQUIRED_SECTIONS=$(echo "$CONFIG" | jq -r ".patterns[\"$ROLE\"].required_sections // .patterns[\"default\"].required_sections | .[]" 2>/dev/null || true)
elif command -v python3 &>/dev/null; then
  REQUIRED_SECTIONS=$(echo "$CONFIG" | python3 -c "
import json, sys
try:
    config = json.load(sys.stdin)
    patterns = config.get('patterns', {})
    role_config = patterns.get('$ROLE', patterns.get('default', {}))
    for s in role_config.get('required_sections', []):
        print(s)
except:
    pass
" 2>/dev/null || true)
fi

if [ -z "$REQUIRED_SECTIONS" ]; then
  # No sections configured for this role -- nothing to check
  exit $HOOK_ALLOW
fi

# --- 7. Check for required sections ---
TOTAL_SECTIONS=0
MISSING_SECTIONS=0
MISSING_NAMES=""

while IFS= read -r section; do
  [ -z "$section" ] && continue
  TOTAL_SECTIONS=$((TOTAL_SECTIONS + 1))
  if ! has_section "$OUTPUT_TEXT" "$section"; then
    MISSING_SECTIONS=$((MISSING_SECTIONS + 1))
    if [ -n "$MISSING_NAMES" ]; then
      MISSING_NAMES="$MISSING_NAMES, $section"
    else
      MISSING_NAMES="$section"
    fi
  fi
done <<< "$REQUIRED_SECTIONS"

# --- 8. Evaluate completeness ---
MIN_LENGTH=$(parse_json_field "$CONFIG" ".min_output_length")
MIN_LENGTH=${MIN_LENGTH:-200}

OUTPUT_LENGTH=${#OUTPUT_TEXT}

# All sections missing AND output suspiciously short -> block
if [ "$MISSING_SECTIONS" -eq "$TOTAL_SECTIONS" ] && [ "$TOTAL_SECTIONS" -gt 0 ] && [ "$OUTPUT_LENGTH" -lt "$MIN_LENGTH" ]; then
  block_with_reason "Output appears incomplete: missing $MISSING_NAMES. Expected structured response with required sections."
fi

# Some sections missing -> advisory warn, allow
if [ "$MISSING_SECTIONS" -gt 0 ]; then
  advisory_warn "Output missing $MISSING_NAMES. Chair should verify completeness."
  exit $HOOK_ALLOW
fi

# All sections present
exit $HOOK_ALLOW
