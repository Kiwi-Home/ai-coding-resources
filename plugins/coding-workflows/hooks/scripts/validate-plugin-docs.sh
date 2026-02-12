#!/usr/bin/env bash
# Build-time validation utility for plugin documentation consistency.
# NOT a lifecycle hook -- not registered in hooks.json.
# Called by /plugin-export as a pre-flight gate.
#
# Discovers all plugin assets on disk (commands, skills, hooks) and
# cross-checks them against documentation surfaces (README.md, help.md).
# Reports mismatches, missing entries, and phantom references.
#
# Usage: validate-plugin-docs.sh [plugin_root]
#   plugin_root defaults to auto-detection from script location.
#
# Exit codes:
#   0 = all checks pass
#   1 = one or more validation failures (mismatches, missing, phantoms)
#   2 = script error (bad arguments, missing plugin directory, parse failure)

set -euo pipefail

# ─── Setup ───────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -ge 1 ]; then
  PLUGIN_ROOT="$1"
else
  # Auto-detect: script is in hooks/scripts/, plugin root is two levels up
  PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fi

if [ ! -d "$PLUGIN_ROOT" ]; then
  echo "ERROR: Plugin directory not found: ${PLUGIN_ROOT}" >&2
  exit 2
fi

README="${PLUGIN_ROOT}/README.md"
HELP_MD="${PLUGIN_ROOT}/commands/help.md"
HOOKS_JSON="${PLUGIN_ROOT}/hooks/hooks.json"
ROOT_README="$(cd "${PLUGIN_ROOT}/../.." 2>/dev/null && pwd)/README.md"

if [ ! -f "$README" ]; then
  echo "ERROR: README.md not found: ${README}" >&2
  exit 2
fi

if [ ! -f "$HELP_MD" ]; then
  echo "ERROR: help.md not found: ${HELP_MD}" >&2
  exit 2
fi

# Counters
issues_found=0
mismatches=0
missing=0
phantoms=0

# Collected output lines (printed at the end)
declare -a output_lines=()

out() {
  output_lines+=("$1")
}

# ─── Helper Functions ────────────────────────────────────────────────────────

# json_field <file> <jq_filter>
# Reads JSON from a file (not stdin). jq with python3 fallback.
json_field() {
  local file="$1" filter="$2"
  if command -v jq &>/dev/null; then
    jq -r "$filter // empty" "$file" 2>/dev/null || true
  elif command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
try:
  data = json.load(open('$file'))
  # Simple dotted path traversal
  path = '$filter'.lstrip('.').split('.')
  val = data
  for p in path:
    if p == '// empty':
      continue
    val = val[p]
  print(val if val is not None else '')
except:
  pass
" 2>/dev/null || true
  fi
}

# extract_frontmatter_desc <file>
# Extracts the description field from YAML frontmatter (between --- delimiters).
# Handles: single-line, quoted, literal block (|), folded block (>).
# Returns normalized single-line description.
extract_frontmatter_desc() {
  local file="$1"
  local in_frontmatter=false
  local found_desc=false
  local desc=""
  local block_type=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [ "$in_frontmatter" = false ]; then
      if [[ "$line" =~ ^---[[:space:]]*$ ]]; then
        in_frontmatter=true
      fi
      continue
    fi

    # End of frontmatter
    if [[ "$line" =~ ^---[[:space:]]*$ ]] && [ "$in_frontmatter" = true ]; then
      break
    fi

    if [ "$found_desc" = true ]; then
      # Collecting multi-line block continuation
      # Continuation lines are indented (start with spaces)
      if [[ "$line" =~ ^[[:space:]]+ ]]; then
        local trimmed
        trimmed="$(echo "$line" | sed 's/^[[:space:]]*//')"
        if [ -n "$desc" ]; then
          desc="${desc} ${trimmed}"
        else
          desc="${trimmed}"
        fi
        continue
      else
        # Non-indented line = next key or end of block
        break
      fi
    fi

    # Look for description key
    if [[ "$line" =~ ^description:[[:space:]]* ]]; then
      local value
      value="${line#description:}"
      value="$(echo "$value" | sed 's/^[[:space:]]*//')"

      if [ "$value" = "|" ] || [ "$value" = ">" ]; then
        # Multi-line block
        block_type="$value"
        found_desc=true
        continue
      elif [ -n "$value" ]; then
        # Single-line value
        desc="$value"
        break
      else
        # Empty value after colon, might be block indicator on same line
        found_desc=true
        continue
      fi
    fi
  done < "$file"

  # Normalize: strip surrounding quotes, collapse whitespace, trim
  desc="$(echo "$desc" | sed 's/^["'"'"']//; s/["'"'"']$//')"
  desc="$(echo "$desc" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')"

  printf '%s' "$desc"
}

# find_in_tables <file> <parent_heading> <asset_name>
# Searches ALL markdown tables under a parent heading for asset_name.
# Returns: "LINE_NUM|DESCRIPTION_TEXT" or empty if not found.
find_in_tables() {
  local file="$1" parent_heading="$2" asset_name="$3"
  local in_section=false
  local line_num=0
  local heading_level=""
  local past_separator=false

  while IFS= read -r line; do
    line_num=$((line_num + 1))
    if [[ "$line" =~ ^(#+)[[:space:]]+(.*) ]]; then
      local hashes="${BASH_REMATCH[1]}"
      local title="${BASH_REMATCH[2]}"
      title="$(echo "$title" | sed 's/[[:space:]]*$//')"

      if [ "$in_section" = true ]; then
        if [ ${#hashes} -le ${#heading_level} ]; then
          break
        fi
      fi

      if [ "$in_section" = false ] && [[ "$title" == *"$parent_heading"* ]]; then
        in_section=true
        heading_level="$hashes"
        continue
      fi
    fi

    if [ "$in_section" = true ]; then
      if [[ "$line" =~ ^\| ]]; then
        # Separator row (e.g., |---|---|): reset past_separator flag for new table
        if [[ "$line" =~ ^[\|[:space:]\-]+$ ]]; then
          past_separator=true
          continue
        fi

        # Skip header rows (before separator)
        if [ "$past_separator" = false ]; then
          continue
        fi

        # Extract first column
        local col1
        col1="$(echo "$line" | awk -F'|' '{print $2}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

        # Normalize: strip backticks, namespace prefix (with or without leading /), argument hints, footnote markers
        local normalized_name
        normalized_name="$(echo "$col1" | sed 's/`//g; s|/coding-workflows:||g; s|coding-workflows:||g; s/ \[.*\]//g; s/ <.*>//g; s/\\\*//g; s/[[:space:]]*$//')"

        if [ "$normalized_name" = "$asset_name" ]; then
          local col2
          col2="$(echo "$line" | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

          # For hook tables (4+ columns), description is in the last content column
          local col_count
          col_count="$(echo "$line" | awk -F'|' '{print NF}')"
          if [ "$col_count" -ge 6 ]; then
            col2="$(echo "$line" | awk -F'|' '{print $5}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
          fi

          printf '%s|%s' "$line_num" "$col2"
          return
        fi
      else
        # Non-table line resets separator tracking (new table starts fresh)
        past_separator=false
      fi
    fi
  done < "$file"
}

# match_descriptions <frontmatter_desc> <table_desc>
# Compares two descriptions after normalization.
# Returns: "OK", "OK (truncated)", or "MISMATCH"
match_descriptions() {
  local fm_desc="$1" tbl_desc="$2"

  # Normalize both: collapse whitespace, trim, strip trailing periods/footnotes, normalize dashes
  local norm_fm norm_tbl
  norm_fm="$(echo "$fm_desc" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//; s/\.$//; s/\\\*$//; s/ -- / -- /g')"
  norm_tbl="$(echo "$tbl_desc" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//; s/\.$//; s/\\\*$//; s/ -- / -- /g')"

  if [ "$norm_fm" = "$norm_tbl" ]; then
    echo "OK"
    return
  fi

  # Faithful truncation: table desc is a prefix of frontmatter desc
  local tbl_len=${#norm_tbl}
  if [ "$tbl_len" -gt 10 ] && [ "${norm_fm:0:$tbl_len}" = "$norm_tbl" ]; then
    echo "OK (truncated)"
    return
  fi

  echo "MISMATCH"
}

# ─── Asset Discovery ─────────────────────────────────────────────────────────

# Commands: all .md files in commands/
declare -a disk_commands=()
for f in "${PLUGIN_ROOT}"/commands/*.md; do
  [ -f "$f" ] || continue
  name="$(basename "$f" .md)"
  disk_commands+=("$name")
done

# Skills: directories with SKILL.md
declare -a disk_skills=()
for f in "${PLUGIN_ROOT}"/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  name="$(basename "$(dirname "$f")")"
  disk_skills+=("$name")
done

# Hooks: unique script names from hooks.json (deduplicated by filename)
disk_hooks=()
_hook_names=""
if [ -f "$HOOKS_JSON" ]; then
  if command -v jq &>/dev/null; then
    _hook_names="$(jq -r '.. | objects | select(.command?) | .command' "$HOOKS_JSON" 2>/dev/null | sed 's|.*scripts/||; s|\.sh$||' | sort -u)"
  elif command -v python3 &>/dev/null; then
    _hook_names="$(python3 -c "
import json
data = json.load(open('$HOOKS_JSON'))
cmds = set()
def walk(obj):
  if isinstance(obj, dict):
    if 'command' in obj:
      name = obj['command'].split('scripts/')[-1].replace('.sh', '')
      cmds.add(name)
    for v in obj.values():
      walk(v)
  elif isinstance(obj, list):
    for v in obj:
      walk(v)
walk(data)
for c in sorted(cmds):
  print(c)
" 2>/dev/null)"
  fi
  while IFS= read -r hook_name; do
    [ -n "$hook_name" ] || continue
    disk_hooks+=("$hook_name")
  done <<< "$_hook_names"
fi

# ─── Command Validation ─────────────────────────────────────────────────────

out ""
out "=== COMMANDS ==="
out ""
out "$(printf '%-25s %-12s %-12s %s' 'Command' 'README' 'help.md' 'Description Match')"
out "$(printf '%-25s %-12s %-12s %s' '-------' '------' '-------' '-----------------')"

for cmd in "${disk_commands[@]}"; do
  cmd_desc="$(extract_frontmatter_desc "${PLUGIN_ROOT}/commands/${cmd}.md")"

  if [ -z "$cmd_desc" ]; then
    out "$(printf '%-25s %-12s %-12s %s' "$cmd" '?' '?' 'NO DESCRIPTION')"
    issues_found=$((issues_found + 1))
    missing=$((missing + 1))
    continue
  fi

  # Check README
  readme_result="$(find_in_tables "$README" "Command Reference" "$cmd")"
  if [ -n "$readme_result" ]; then
    readme_status="L$(echo "$readme_result" | cut -d'|' -f1)"
    readme_desc="$(echo "$readme_result" | cut -d'|' -f2-)"
  else
    readme_status="MISSING"
    readme_desc=""
    issues_found=$((issues_found + 1))
    missing=$((missing + 1))
  fi

  # Check help.md
  help_result="$(find_in_tables "$HELP_MD" "Commands" "$cmd")"
  if [ -n "$help_result" ]; then
    help_status="L$(echo "$help_result" | cut -d'|' -f1)"
    help_desc="$(echo "$help_result" | cut -d'|' -f2-)"
  else
    # help.md doesn't need to list itself
    if [ "$cmd" = "help" ]; then
      help_status="(self)"
      help_desc=""
    else
      help_status="MISSING"
      help_desc=""
      issues_found=$((issues_found + 1))
      missing=$((missing + 1))
    fi
  fi

  # Match descriptions
  match_status="--"
  if [ -n "$readme_desc" ] && [ "$readme_status" != "MISSING" ]; then
    rm_match="$(match_descriptions "$cmd_desc" "$readme_desc")"
    if [ "$rm_match" = "MISMATCH" ]; then
      match_status="README MISMATCH"
      issues_found=$((issues_found + 1))
      mismatches=$((mismatches + 1))
    fi
  fi

  if [ -n "$help_desc" ] && [ "$help_status" != "MISSING" ] && [ "$help_status" != "(self)" ]; then
    hm_match="$(match_descriptions "$cmd_desc" "$help_desc")"
    if [ "$hm_match" = "MISMATCH" ]; then
      if [ "$match_status" = "--" ]; then
        match_status="help.md MISMATCH"
      else
        match_status="${match_status} + help.md"
      fi
      issues_found=$((issues_found + 1))
      mismatches=$((mismatches + 1))
    fi
  fi

  if [ "$match_status" = "--" ]; then
    match_status="OK"
  fi

  out "$(printf '%-25s %-12s %-12s %s' "$cmd" "$readme_status" "$help_status" "$match_status")"

  # Print mismatch details if any
  if [[ "$match_status" == *"MISMATCH"* ]]; then
    out "  frontmatter: ${cmd_desc:0:100}"
    if [[ "$match_status" == *"README"* ]] && [ -n "$readme_desc" ]; then
      out "  README:      ${readme_desc:0:100}"
    fi
    if [[ "$match_status" == *"help.md"* ]] && [ -n "$help_desc" ]; then
      out "  help.md:     ${help_desc:0:100}"
    fi
  fi
done

# ─── Skill Validation ───────────────────────────────────────────────────────

out ""
out "=== SKILLS ==="
out ""
out "$(printf '%-30s %-12s %-12s %s' 'Skill' 'README' 'help.md' 'Description Match')"
out "$(printf '%-30s %-12s %-12s %s' '-----' '------' '-------' '-----------------')"

for skill in "${disk_skills[@]}"; do
  skill_desc="$(extract_frontmatter_desc "${PLUGIN_ROOT}/skills/${skill}/SKILL.md")"

  if [ -z "$skill_desc" ]; then
    out "$(printf '%-30s %-12s %-12s %s' "$skill" '?' '?' 'NO DESCRIPTION')"
    issues_found=$((issues_found + 1))
    missing=$((missing + 1))
    continue
  fi

  # Check README
  readme_result="$(find_in_tables "$README" "Skill Reference" "$skill")"
  if [ -n "$readme_result" ]; then
    readme_status="L$(echo "$readme_result" | cut -d'|' -f1)"
    readme_desc="$(echo "$readme_result" | cut -d'|' -f2-)"
  else
    readme_status="MISSING"
    readme_desc=""
    issues_found=$((issues_found + 1))
    missing=$((missing + 1))
  fi

  # Check help.md
  help_result="$(find_in_tables "$HELP_MD" "Skills" "$skill")"
  if [ -n "$help_result" ]; then
    help_status="L$(echo "$help_result" | cut -d'|' -f1)"
    help_desc="$(echo "$help_result" | cut -d'|' -f2-)"
  else
    help_status="MISSING"
    help_desc=""
    issues_found=$((issues_found + 1))
    missing=$((missing + 1))
  fi

  # Match descriptions
  match_status="--"
  if [ -n "$readme_desc" ] && [ "$readme_status" != "MISSING" ]; then
    rm_match="$(match_descriptions "$skill_desc" "$readme_desc")"
    if [ "$rm_match" = "MISMATCH" ]; then
      match_status="README MISMATCH"
      issues_found=$((issues_found + 1))
      mismatches=$((mismatches + 1))
    fi
  fi

  if [ -n "$help_desc" ] && [ "$help_status" != "MISSING" ]; then
    hm_match="$(match_descriptions "$skill_desc" "$help_desc")"
    if [ "$hm_match" = "MISMATCH" ]; then
      if [ "$match_status" = "--" ]; then
        match_status="help.md MISMATCH"
      else
        match_status="${match_status} + help.md"
      fi
      issues_found=$((issues_found + 1))
      mismatches=$((mismatches + 1))
    fi
  fi

  if [ "$match_status" = "--" ]; then
    match_status="OK"
  fi

  out "$(printf '%-30s %-12s %-12s %s' "$skill" "$readme_status" "$help_status" "$match_status")"

  if [[ "$match_status" == *"MISMATCH"* ]]; then
    out "  frontmatter: ${skill_desc:0:120}"
    if [[ "$match_status" == *"README"* ]] && [ -n "$readme_desc" ]; then
      out "  README:      ${readme_desc:0:120}"
    fi
    if [[ "$match_status" == *"help.md"* ]] && [ -n "$help_desc" ]; then
      out "  help.md:     ${help_desc:0:120}"
    fi
  fi
done

# ─── Hook Validation ────────────────────────────────────────────────────────

out ""
out "=== HOOKS ==="
out ""
out "$(printf '%-35s %-12s %-12s %s' 'Hook' 'hooks.json' 'README' 'Script on disk')"
out "$(printf '%-35s %-12s %-12s %s' '----' '----------' '------' '--------------')"

for hook in "${disk_hooks[@]}"; do
  # Check script exists on disk
  script_path="${PLUGIN_ROOT}/hooks/scripts/${hook}.sh"
  if [ -f "$script_path" ]; then
    script_status="OK"
  else
    script_status="MISSING"
    issues_found=$((issues_found + 1))
    missing=$((missing + 1))
  fi

  # Check README (Shipped Hooks section)
  readme_result="$(find_in_tables "$README" "Shipped Hooks" "$hook")"
  if [ -n "$readme_result" ]; then
    readme_status="L$(echo "$readme_result" | cut -d'|' -f1)"
  else
    readme_status="MISSING"
    issues_found=$((issues_found + 1))
    missing=$((missing + 1))
  fi

  out "$(printf '%-35s %-12s %-12s %s' "$hook" 'OK' "$readme_status" "$script_status")"
done

# ─── Phantom Detection ───────────────────────────────────────────────────────

out ""
out "=== PHANTOM DETECTION ==="
out ""

# Helper: extract all entry names from tables under a heading in a file
extract_table_entries() {
  local file="$1" parent_heading="$2"
  local in_section=false
  local heading_level=""
  local past_separator=false

  while IFS= read -r line; do
    if [[ "$line" =~ ^(#+)[[:space:]]+(.*) ]]; then
      local hashes="${BASH_REMATCH[1]}"
      local title="${BASH_REMATCH[2]}"
      title="$(echo "$title" | sed 's/[[:space:]]*$//')"

      if [ "$in_section" = true ] && [ ${#hashes} -le ${#heading_level} ]; then
        break
      fi

      if [ "$in_section" = false ] && [[ "$title" == *"$parent_heading"* ]]; then
        in_section=true
        heading_level="$hashes"
        continue
      fi
    fi

    if [ "$in_section" = true ] && [[ "$line" =~ ^\| ]]; then
      # Separator row
      if [[ "$line" =~ ^[\|[:space:]\-]+$ ]]; then
        past_separator=true
        continue
      fi

      # Skip header rows (before separator)
      if [ "$past_separator" = false ]; then
        continue
      fi

      local col1
      col1="$(echo "$line" | awk -F'|' '{print $2}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

      # Normalize: strip backticks, namespace prefix (with or without leading /), argument hints, footnote markers
      local normalized
      normalized="$(echo "$col1" | sed 's/`//g; s|/coding-workflows:||g; s|coding-workflows:||g; s/ \[.*\]//g; s/ <.*>//g; s/\\\*//g; s/[[:space:]]*$//')"

      if [ -n "$normalized" ]; then
        echo "$normalized"
      fi
    elif [ "$in_section" = true ]; then
      # Non-table line resets separator tracking
      past_separator=false
    fi
  done < "$file"
}

phantom_count=0

# Check README command tables
while IFS= read -r entry; do
  found=false
  for cmd in "${disk_commands[@]}"; do
    if [ "$cmd" = "$entry" ]; then
      found=true
      break
    fi
  done
  if [ "$found" = false ]; then
    out "PHANTOM: README command table lists '${entry}' but no commands/${entry}.md on disk"
    phantom_count=$((phantom_count + 1))
  fi
done < <(extract_table_entries "$README" "Command Reference")

# Check README skill table
while IFS= read -r entry; do
  found=false
  for skill in "${disk_skills[@]}"; do
    if [ "$skill" = "$entry" ]; then
      found=true
      break
    fi
  done
  if [ "$found" = false ]; then
    out "PHANTOM: README skill table lists '${entry}' but no skills/${entry}/SKILL.md on disk"
    phantom_count=$((phantom_count + 1))
  fi
done < <(extract_table_entries "$README" "Skill Reference")

# Check README hook table
while IFS= read -r entry; do
  found=false
  for hook in "${disk_hooks[@]}"; do
    if [ "$hook" = "$entry" ]; then
      found=true
      break
    fi
  done
  if [ "$found" = false ]; then
    out "PHANTOM: README hook table lists '${entry}' but no hook script for '${entry}' in hooks.json"
    phantom_count=$((phantom_count + 1))
  fi
done < <(extract_table_entries "$README" "Shipped Hooks")

# Check help.md command table
while IFS= read -r entry; do
  found=false
  for cmd in "${disk_commands[@]}"; do
    if [ "$cmd" = "$entry" ]; then
      found=true
      break
    fi
  done
  if [ "$found" = false ]; then
    out "PHANTOM: help.md command table lists '${entry}' but no commands/${entry}.md on disk"
    phantom_count=$((phantom_count + 1))
  fi
done < <(extract_table_entries "$HELP_MD" "Commands")

# Check help.md skill table
while IFS= read -r entry; do
  found=false
  for skill in "${disk_skills[@]}"; do
    if [ "$skill" = "$entry" ]; then
      found=true
      break
    fi
  done
  if [ "$found" = false ]; then
    out "PHANTOM: help.md skill table lists '${entry}' but no skills/${entry}/SKILL.md on disk"
    phantom_count=$((phantom_count + 1))
  fi
done < <(extract_table_entries "$HELP_MD" "Skills")

if [ "$phantom_count" -eq 0 ]; then
  out "No phantom entries found."
else
  issues_found=$((issues_found + phantom_count))
  phantoms=$((phantoms + phantom_count))
fi

# ─── Aggregate Checks ───────────────────────────────────────────────────────

out ""
out "=== AGGREGATE CHECKS ==="
out ""

actual_cmd_count=${#disk_commands[@]}
actual_skill_count=${#disk_skills[@]}
actual_hook_count=${#disk_hooks[@]}

if [ -f "$ROOT_README" ]; then
  # Extract command count from structure tree (e.g., "# 11 user-facing")
  readme_cmd_count="$(grep -oE '#[[:space:]]+[0-9]+[[:space:]]+user-facing' "$ROOT_README" 2>/dev/null | grep -oE '[0-9]+' || true)"
  if [ -n "$readme_cmd_count" ]; then
    if [ "$readme_cmd_count" -ne "$actual_cmd_count" ]; then
      out "MISMATCH: Root README says ${readme_cmd_count} commands, found ${actual_cmd_count} on disk"
      issues_found=$((issues_found + 1))
      mismatches=$((mismatches + 1))
    else
      out "Commands count: ${actual_cmd_count} (matches root README)"
    fi
  else
    out "WARNING: Could not parse command count from root README (best-effort, not counted as failure)"
  fi

  # Extract skill count from structure tree (e.g., "# 11 bundled skills")
  readme_skill_count="$(grep -oE '#[[:space:]]+[0-9]+[[:space:]]+bundled' "$ROOT_README" 2>/dev/null | grep -oE '[0-9]+' || true)"
  if [ -n "$readme_skill_count" ]; then
    if [ "$readme_skill_count" -ne "$actual_skill_count" ]; then
      out "MISMATCH: Root README says ${readme_skill_count} skills, found ${actual_skill_count} on disk"
      issues_found=$((issues_found + 1))
      mismatches=$((mismatches + 1))
    else
      out "Skills count: ${actual_skill_count} (matches root README)"
    fi
  else
    out "WARNING: Could not parse skill count from root README (best-effort, not counted as failure)"
  fi

  # Check hooks/ directory line exists in structure tree
  if grep -q 'hooks/' "$ROOT_README" 2>/dev/null; then
    out "Hooks directory: present in root README structure tree"
  else
    out "WARNING: hooks/ not found in root README structure tree (best-effort, not counted as failure)"
  fi
else
  out "WARNING: Root README not found at ${ROOT_README} (best-effort, not counted as failure)"
fi

out ""
out "=== INVENTORY SUMMARY ==="
out ""
out "Commands on disk: ${actual_cmd_count}"
out "Skills on disk:   ${actual_skill_count}"
out "Hooks in JSON:    ${actual_hook_count}"

# ─── Output ──────────────────────────────────────────────────────────────────

# Print all collected output
for line in "${output_lines[@]}"; do
  echo "$line"
done

echo ""

# Machine-parseable summary
echo "## VALIDATION_RESULT: $([ "$issues_found" -eq 0 ] && echo 'PASS' || echo 'FAIL') count=${issues_found} mismatches=${mismatches} missing=${missing} phantoms=${phantoms}"

# Human-readable summary
if [ "$issues_found" -eq 0 ]; then
  echo "All checks passed."
  exit 0
else
  echo "${issues_found} issues found (${mismatches} mismatches, ${missing} missing, ${phantoms} phantoms)"
  exit 1
fi
