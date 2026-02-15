#!/usr/bin/env bash
# PreToolUse hook: dependency version pin detection.
#
# Detects dependency-add commands and checks for explicit version pins
# in the command text. This is STATELESS -- no session history, no
# transcript reading, no evidence files. The command either contains
# a version pin or it does not.
#
# Exemptions: lockfile-based installs (npm ci, uv sync, pip install -r,
# bundle install with no args, etc.) are never flagged.
#
# Default: advisory (injects systemMessage, command proceeds)
# Opt-in: block mode via workflow.yaml mode: block (denies the tool call)
#
# Output contract: PreToolUse JSON via hookSpecificOutput (exit 0).
# Uses permissionDecision (allow/deny) + systemMessage.
#
# Timeout: 3000ms (in hooks.json). PreToolUse hooks block before execution,
# making latency more critical than PostToolUse (5000ms). The fast-path
# regex exits non-matching commands in <5ms; config is only read on match.
#
# Disable: export CODING_WORKFLOWS_DISABLE_HOOK_DEPENDENCY_VERSION_CHECK=1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_workflow-config.sh
source "${SCRIPT_DIR}/_workflow-config.sh"

# --- Guard: per-hook disable ---
if check_disabled "DEPENDENCY_VERSION_CHECK"; then
  exit $HOOK_ALLOW
fi

# --- Read stdin JSON ---
INPUT=$(cat)
COMMAND=$(parse_json_field "$INPUT" ".tool_input.command")
[ -z "$COMMAND" ] && exit $HOOK_ALLOW

# === FAST PATH: regex match before any config reading ===

# Match dependency-add commands.
# Anchors: start of string, whitespace, or shell operator (&&, ||, ;) to avoid
# matching substrings like "dump install" or variable names containing "add".
DEP_ADD_PATTERN='(^|[[:space:]]|&&|\|\||;)(uv add|uv pip install|pip install|npm install|npm i|yarn add|pnpm add|cargo add|gem install|bundle add)\b'
if ! echo "$COMMAND" | grep -qE "$DEP_ADD_PATTERN"; then
  exit $HOOK_ALLOW
fi

# Exclude lockfile/bulk installs (no new dependency being added).
# These commands install from existing manifests/lockfiles, not new packages.
EXCLUDE_PATTERN='pip install[[:space:]]+(-r[[:space:]]|--requirement[[:space:]]'  # requirements file
EXCLUDE_PATTERN+='|-e[[:space:]]|--editable[[:space:]]'                           # editable install
EXCLUDE_PATTERN+='|\.[[:space:]]*$|\.\/)'                                          # current package (pip install . or ./)
EXCLUDE_PATTERN+="|npm ci\b"                                                       # clean install from lockfile
EXCLUDE_PATTERN+="|npm install[[:space:]]*$|npm i[[:space:]]*$"                    # install from package.json (no pkg arg)
EXCLUDE_PATTERN+="|yarn install[[:space:]]*$"                                      # install from yarn.lock
EXCLUDE_PATTERN+="|pnpm install[[:space:]]*$"                                      # install from pnpm-lock.yaml
EXCLUDE_PATTERN+="|bundle install[[:space:]]*$"                                    # install from Gemfile.lock
EXCLUDE_PATTERN+="|uv sync|uv pip sync"                                            # lockfile sync
if echo "$COMMAND" | grep -qE "$EXCLUDE_PATTERN"; then
  exit $HOOK_ALLOW
fi

# === MATCH FOUND: extract matched package manager and package ===

# Determine which package manager (PM) matched
MATCHED_CMD=""
PKG=""

# Extract the dependency-add segment and package name.
# We parse the first matching command and its arguments.
if echo "$COMMAND" | grep -qE '(^|[[:space:]]|&&|\|\||;)uv add\b'; then
  MATCHED_CMD="uv add"
  # Extract args after "uv add" (skip flags starting with -)
  PKG=$(echo "$COMMAND" | sed -En 's/.*uv add[[:space:]]+//p' | tr ' ' '\n' | grep -v '^-' | head -1)
elif echo "$COMMAND" | grep -qE '(^|[[:space:]]|&&|\|\||;)uv pip install\b'; then
  MATCHED_CMD="uv pip install"
  PKG=$(echo "$COMMAND" | sed -En 's/.*uv pip install[[:space:]]+//p' | tr ' ' '\n' | grep -v '^-' | head -1)
elif echo "$COMMAND" | grep -qE '(^|[[:space:]]|&&|\|\||;)pip install\b'; then
  MATCHED_CMD="pip install"
  PKG=$(echo "$COMMAND" | sed -En 's/.*pip install[[:space:]]+//p' | tr ' ' '\n' | grep -v '^-' | head -1)
elif echo "$COMMAND" | grep -qE '(^|[[:space:]]|&&|\|\||;)npm install\b'; then
  MATCHED_CMD="npm install"
  PKG=$(echo "$COMMAND" | sed -En 's/.*npm install[[:space:]]+//p' | tr ' ' '\n' | grep -v '^-' | head -1)
elif echo "$COMMAND" | grep -qE '(^|[[:space:]]|&&|\|\||;)npm i\b'; then
  MATCHED_CMD="npm i"
  PKG=$(echo "$COMMAND" | sed -En 's/.*npm i[[:space:]]+//p' | tr ' ' '\n' | grep -v '^-' | head -1)
elif echo "$COMMAND" | grep -qE '(^|[[:space:]]|&&|\|\||;)yarn add\b'; then
  MATCHED_CMD="yarn add"
  PKG=$(echo "$COMMAND" | sed -En 's/.*yarn add[[:space:]]+//p' | tr ' ' '\n' | grep -v '^-' | head -1)
elif echo "$COMMAND" | grep -qE '(^|[[:space:]]|&&|\|\||;)pnpm add\b'; then
  MATCHED_CMD="pnpm add"
  PKG=$(echo "$COMMAND" | sed -En 's/.*pnpm add[[:space:]]+//p' | tr ' ' '\n' | grep -v '^-' | head -1)
elif echo "$COMMAND" | grep -qE '(^|[[:space:]]|&&|\|\||;)cargo add\b'; then
  MATCHED_CMD="cargo add"
  PKG=$(echo "$COMMAND" | sed -En 's/.*cargo add[[:space:]]+//p' | tr ' ' '\n' | grep -v '^-' | head -1)
elif echo "$COMMAND" | grep -qE '(^|[[:space:]]|&&|\|\||;)gem install\b'; then
  MATCHED_CMD="gem install"
  PKG=$(echo "$COMMAND" | sed -En 's/.*gem install[[:space:]]+//p' | tr ' ' '\n' | grep -v '^-' | head -1)
elif echo "$COMMAND" | grep -qE '(^|[[:space:]]|&&|\|\||;)bundle add\b'; then
  MATCHED_CMD="bundle add"
  PKG=$(echo "$COMMAND" | sed -En 's/.*bundle add[[:space:]]+//p' | tr ' ' '\n' | grep -v '^-' | head -1)
fi

# If we couldn't extract a package name, allow (fail-open)
[ -z "$PKG" ] && exit $HOOK_ALLOW

# Strip version specifiers from package name for display/allowlist matching
# e.g., "requests==2.31.0" -> "requests", "express@4.18.2" -> "express"
PKG_BARE=$(echo "$PKG" | sed 's/[=<>!~@].*//')

# === Allowlist check (lazy config read -- only on match) ===
ALLOWLIST=$(get_dependency_check_allowlist) || true
if [ -n "$ALLOWLIST" ]; then
  while IFS= read -r allowed; do
    [ -z "$allowed" ] && continue
    if [ "$PKG_BARE" = "$allowed" ]; then
      exit $HOOK_ALLOW
    fi
  done <<< "$ALLOWLIST"
fi

# === Package manager filter check ===
# The filter uses ecosystem-level names ("pip", "npm", "cargo", "gem") rather than
# raw command strings. This is intentional: users configure by ecosystem, but the
# regex matches specific commands within that ecosystem (e.g., "pip" covers both
# "pip install" and "uv add" since both install Python packages).
PM_FILTER=$(get_dependency_check_package_managers) || true
if [ -n "$PM_FILTER" ]; then
  PM_MATCHED="false"
  # Map matched command to ecosystem name for filter comparison
  case "$MATCHED_CMD" in
    "uv add"|"uv pip install"|"pip install") PM_NAME="pip" ;;
    "npm install"|"npm i"|"yarn add"|"pnpm add") PM_NAME="npm" ;;
    "cargo add") PM_NAME="cargo" ;;
    "gem install"|"bundle add") PM_NAME="gem" ;;
    *) PM_NAME="" ;;
  esac
  while IFS= read -r filtered_pm; do
    [ -z "$filtered_pm" ] && continue
    if [ "$PM_NAME" = "$filtered_pm" ]; then
      PM_MATCHED="true"
      break
    fi
  done <<< "$PM_FILTER"
  if [ "$PM_MATCHED" = "false" ]; then
    exit $HOOK_ALLOW
  fi
fi

# === PIN DETECTION ===
# A "pin" is any explicit version specifier demonstrating version awareness.
# Pins: ==2.31.0, >=2.31.0, ~=2.31, ^4.18, @4.18.2, @^4.18, @~4.18,
#        --vers 1.0, --version 1.0, -v 7.1.3
# NOT pins: @latest, @next, @canary, bare package name

IS_PINNED="false"

case "$MATCHED_CMD" in
  "uv add"|"uv pip install"|"pip install")
    # Python: version specifiers after package name (==, >=, <=, ~=, !=)
    if echo "$PKG" | grep -qE '(==|>=|<=|~=|!=)[[:space:]]*[0-9]'; then
      IS_PINNED="true"
    fi
    ;;
  "npm install"|"npm i"|"yarn add"|"pnpm add")
    # Node: @version after package name (but NOT @latest, @next, @canary)
    if echo "$PKG" | grep -qE '@[0-9^~]'; then
      IS_PINNED="true"
    fi
    ;;
  "cargo add")
    # Rust: @version or --vers/--version flags
    if echo "$PKG" | grep -qE '@[0-9]'; then
      IS_PINNED="true"
    elif echo "$COMMAND" | grep -qE -- '--vers[[:space:]=]+[0-9]|--version[[:space:]=]+[0-9]'; then
      IS_PINNED="true"
    fi
    ;;
  "gem install"|"bundle add")
    # Ruby: -v or --version flags (space or = separator)
    if echo "$COMMAND" | grep -qE -- '-v[[:space:]=]+[0-9]|--version[[:space:]=]+[0-9]'; then
      IS_PINNED="true"
    fi
    ;;
esac

# If pinned, allow silently
if [ "$IS_PINNED" = "true" ]; then
  exit $HOOK_ALLOW
fi

# === NOT PINNED: build PM-specific lookup command and pin example ===

LOOKUP_CMD=""
PIN_EXAMPLE=""

case "$MATCHED_CMD" in
  "uv add"|"uv pip install"|"pip install")
    LOOKUP_CMD="curl -s https://pypi.org/pypi/${PKG_BARE}/json | jq -r '.info.version'"
    PIN_EXAMPLE="${MATCHED_CMD} ${PKG_BARE}==<version>"
    ;;
  "npm install"|"npm i"|"yarn add"|"pnpm add")
    LOOKUP_CMD="curl -s https://registry.npmjs.org/${PKG_BARE}/latest | jq -r '.version'"
    PIN_EXAMPLE="${MATCHED_CMD} ${PKG_BARE}@<version>"
    ;;
  "cargo add")
    LOOKUP_CMD="curl -s https://crates.io/api/v1/crates/${PKG_BARE} | jq -r '.crate.max_stable_version'"
    PIN_EXAMPLE="cargo add ${PKG_BARE}@<version>"
    ;;
  "gem install"|"bundle add")
    LOOKUP_CMD="curl -s https://rubygems.org/api/v1/gems/${PKG_BARE}.json | jq -r '.version'"
    PIN_EXAMPLE="${MATCHED_CMD} ${PKG_BARE} -v <version>"
    ;;
esac

# === Mode check and output ===
MODE=$(get_dependency_check_mode)

if [ "$MODE" = "block" ]; then
  pretool_deny "Dependency '${PKG_BARE}' added without version pin. Verify first: ${LOOKUP_CMD}. Then pin: ${PIN_EXAMPLE}. See /coding-workflows:knowledge-freshness."
else
  pretool_advisory "Dependency install detected (\`${MATCHED_CMD} ${PKG_BARE}\`) without version pin. Per the knowledge-freshness skill, library versions are HIGH staleness risk. Verify latest version: ${LOOKUP_CMD}. Then pin: ${PIN_EXAMPLE}. See \`/coding-workflows:knowledge-freshness\` and resources/version-discovery.md."
fi
