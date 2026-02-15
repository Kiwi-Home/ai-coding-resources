---
description: Unified idempotent project initialization -- CLAUDE.md, config, agents, skills, and hooks
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
---

# Workflow Setup

Unified idempotent project initialization. Orchestrates CLAUDE.md, workflow.yaml, agent generation, and skill generation into a single command with a shared preflight audit.

**Pipeline:**
```
Preflight -> CLAUDE.md -> Config -> Assets (Skills then Agents) -> Hooks -> Summary
```

Safe to run repeatedly. Manually created files are preserved. Stale config is detected and offered for update.

---

## Step 0: Unified Preflight Audit (MANDATORY)

Non-interactive. Gather complete project state before any user prompts.

### 0a. Gather Inventory

Scan all three asset layers per the `coding-workflows:asset-discovery` skill's Discovery Locations table:

| Check | How | Result |
|-------|-----|--------|
| CLAUDE.md | Read `CLAUDE.md` at project root | exists / missing |
| workflow.yaml | Read `.claude/workflow.yaml` | exists / missing |
| Assets (all layers) | Scan per `coding-workflows:asset-discovery` Discovery Locations table | list per layer |
| Remotes | `git remote -v` (fetch URLs only, deduplicated by remote name) | list of remote names + URLs |
| Worktrees | `git worktree list` | list of active worktrees (informational) |

The asset-discovery skill defines three layers:
- **Project:** `.claude/agents/*.md`, `.claude/skills/*/SKILL.md`
- **User:** `~/.claude/agents/*.md`, `~/.claude/skills/*/SKILL.md`
- **Plugin:** `plugins/*/skills/*/SKILL.md` (agents: none currently bundled -- do NOT scan for plugin agents)

If a layer directory does not exist, skip silently. If a layer is inaccessible (permissions), warn once and continue with accessible layers.

### 0b. Classify Agents and Skills

Each asset gets a **layer tag** and (for project-layer only) a **provenance tag**, per the `coding-workflows:asset-discovery` skill's rules:

- **Project-layer:** `[project] [generated/manual]` (provenance from frontmatter)
- **User-layer:** `[user]` (no provenance tag)
- **Plugin-layer:** `[plugin:{plugin-name}]` (no provenance tag)

For **project-layer** assets, read YAML frontmatter and classify provenance:

| Condition | Classification | Behavior |
|-----------|---------------|----------|
| Has `generated_by` field | `[generated]` | May update. Staleness determined in Steps 3-4 by generators. |
| No `generated_by` field | `[manual]` | Preserve. Never offer overwrite. |
| Unparseable frontmatter | `[manual]` | Treat as manually created (per asset-discovery fallback). |
| File missing | `[missing]` | Will be created if user selects domain. |

User and plugin assets are informational for overlap detection -- provenance classification does not apply to them.

Additionally, for project-layer assets classified as `[manual]`, check for `# TODO:` markers. If present,
note as informational in Step 0e: these may be legacy generated files from before provenance
tracking was added. This is a UX hint only -- it does not change the classification.

### 0c. Detect Stale Configuration

If `workflow.yaml` exists, run stack detection using the `coding-workflows:stack-detection` skill reference tables against the live codebase. Compare detected values against stored values:

| Field | Stale if... |
|-------|-------------|
| `project.language` | Detected language differs from stored |
| `project.org` | Git remote org differs from stored (use `project.remote` for comparison, default: `origin` if absent) |
| `project.name` | Git remote repo name differs from stored (use `project.remote` for comparison, default: `origin` if absent) |
| Framework | New framework dependency detected but not in config |
| Framework removed | Config references framework but dependency is gone |

When checking org/repo drift:
- If `project.remote` is set in workflow.yaml: use that remote name for comparison
- If `project.remote` is absent: use `origin` (current default behavior)
- No behavior change for existing users whose workflow.yaml lacks `project.remote`

Do NOT mark stale for `commands.test/lint/typecheck` mismatches -- these may be intentional user overrides.

**Review gate drift:** Run review automation detection per `init-config` Step 2e. If `.github/workflows/` now contains review automation signals but `hooks.execute_issue_completion_gate.review_gate` is `false` (or absent), flag as stale: "Review automation detected in CI workflows but `review_gate` is currently `false`."

**Domain drift:** Also detect new directory-based domains (per `coding-workflows:stack-detection` Domain Detection table) not represented in existing agents/skills. Report as informational: "New domains detected: [list]"

### 0d. Monorepo Check

Check for monorepo indicators per `init-config` Step 2d (workspace files, multiple language files in distinct subdirectories).

If detected, warn: "This appears to be a monorepo. Configure for your primary service directory."

### 0e. Present Unified State Report

Display all findings (informational, no prompts). Two display modes based on asset layer spread:

**Single-layer mode** (all assets in project layer only -- the common case):
Use flat format without layer sub-groups:

```
Workflow Preflight Audit
========================

Project: {org}/{repo}
Stack:   {language} / {framework or "none detected"}
{If monorepo: "Note: Monorepo detected. Configuring for primary service."}

Configuration:
  CLAUDE.md              [missing/present]
  .claude/workflow.yaml  [missing/present/stale]

Agents:
  .claude/agents/X.md    [generated/manual/missing]

Skills:
  .claude/skills/X/SKILL.md  [generated/manual/missing]

{If manual assets with TODO markers found: "Note: N manual assets contain TODO markers
(possible pre-provenance generated files). Generators will add provenance tracking if you
choose to regenerate."}

{If stale: "Config drift: language JavaScript -> TypeScript, org old -> new"}
{If domain drift: "New domains detected: auth, infrastructure"}

Phases to run:
  [run/skip] CLAUDE.md
  [run/skip] Configuration
  [run/skip] Asset generation (skills then agents)
  [active]   Hooks (plugin hooks active by default)
```

**Multi-layer mode** (assets exist in 2+ layers):
Group by type, show layer tags:

```
Workflow Preflight Audit
========================

Project: {org}/{repo}
Stack:   {language} / {framework or "none detected"}
{If monorepo: "Note: Monorepo detected. Configuring for primary service."}

Configuration:
  CLAUDE.md              [missing/present]
  .claude/workflow.yaml  [missing/present/stale]

Agents:
  .claude/agents/X.md            [project] [generated]
  ~/.claude/agents/Y.md          [user]

Skills:
  .claude/skills/X/SKILL.md      [project] [manual]
  ~/.claude/skills/Y/SKILL.md    [user]
  coding-workflows:Z             [plugin:coding-workflows]

{If manual assets with TODO markers found: "Note: N manual assets contain TODO markers
(possible pre-provenance generated files). Generators will add provenance tracking if you
choose to regenerate."}

{If stale: "Config drift: language JavaScript -> TypeScript, org old -> new"}
{If domain drift: "New domains detected: auth, infrastructure"}

Phases to run:
  [run/skip] CLAUDE.md
  [run/skip] Configuration
  [run/skip] Asset generation (skills then agents)
  [active]   Hooks (plugin hooks active by default)
```

**Switching rule:** If any non-project-layer asset is discovered, use multi-layer mode. Otherwise, single-layer mode. Empty layers are always omitted (no "none" lines).

### 0f. Determine Pipeline Scope

| Condition | Phase action |
|-----------|-------------|
| CLAUDE.md missing | Run Step 1 |
| CLAUDE.md exists | Skip Step 1 |
| workflow.yaml missing | Run Step 2 |
| workflow.yaml stale | Run Step 2 (show drift, ask to update) |
| workflow.yaml present and current | Skip Step 2 |
Conditions are evaluated in order; first match determines phase behavior.

Asset generation (Step 3) runs if ANY of the following are true for either asset type:

| # | Condition | Phase action |
|---|-----------|-------------|
| 1 | No skills exist | Run Step 3 (skills phase) |
| 2 | Some skills `[generated]` + new domains detected | Run Step 3 (generators determine staleness; also offer new domain generation) |
| 3 | Some skills `[generated]`, no new domains | Run Step 3 (generators determine which are stale and offer updates) |
| 4 | All skills `[manual]` + new domains detected | Run Step 3 (new domains only; existing manual skills preserved) |
| 5 | All skills `[manual]`, no new domains | Skip skills in Step 3 |
| 6 | No agents exist | Run Step 3 (agents phase) |
| 7 | Some agents `[generated]` + new domains detected | Run Step 3 (generators determine staleness; also offer new domain generation) |
| 8 | Some agents `[generated]`, no new domains | Run Step 3 (generators determine which are stale and offer updates) |
| 9 | All agents `[manual]` + new domains detected | Run Step 3 (new domains only; existing manual agents preserved) |
| 10 | All agents `[manual]`, no new domains | Skip agents in Step 3 |

Note: "new domains" means directory-based domains detected by Step 0c's domain drift check that are not represented in any existing agent/skill. Conditions are evaluated independently for skills (1-5) and agents (6-10). Skills are always processed before agents.

### Prompt Budget

Maximum 4 user prompts across the entire pipeline:

| Prompt | When consumed | Phase |
|--------|--------------|-------|
| 1 | CLAUDE.md missing -> "Choose: /init (recommended), describe, or skip" | Step 1 |
| 2 | Config missing/stale -> "Confirm settings" (consolidated) | Step 2 |
| 3 | Combined domain selection (skills + agents together) | Step 3 |
| 4 | Overlap resolution (if WARN-tier collisions detected) | Step 3 |

If both CLAUDE.md is present AND config is current, prompts 1-2 are not consumed, leaving more budget for generation phases. If prompt budget is exhausted, use detected defaults for remaining phases and note in summary.

---

## Step 1: CLAUDE.md Gate (soft)

If CLAUDE.md is **missing**:
- Warn: "No CLAUDE.md found. This file helps Claude understand your project conventions and is the most important context source for initialization quality."
- Offer 3 options (1 prompt):

  **1. Use /init (Recommended)**
  Claude Code's built-in `/init` analyses your actual codebase -- imports, frameworks,
  directory structure -- and generates a CLAUDE.md tailored to what it finds. This
  produces significantly better results than a manual description.

  IMPORTANT: Open a new terminal tab or Claude Code session to run `/init`. Running
  it in the current session will terminate this setup command.

  **2. Describe my project**
  Interactive interview to draft a CLAUDE.md from your description.

  **3. Skip**
  Continue without CLAUDE.md. Asset generation quality will be reduced.

- Default/recommended: Option 1. Presented first with "(Recommended)" label.
- Selection mechanism: User selects by number or keyword ("init"/"describe"/"skip").

**If option 1 selected:**
- Wait for user to confirm /init is done (free-form confirmation, not a prompt slot).
- Re-read `CLAUDE.md` at project root.
- **If CLAUDE.md exists and is non-empty (> 0 bytes after trimming whitespace):**
  continue to Step 2.
- **If CLAUDE.md is missing or empty (1st failure):** Warn: "CLAUDE.md not found or
  empty. Did /init complete successfully?" Re-offer the 3-option menu. This is error
  recovery -- does NOT consume an additional prompt from the budget.
- **If CLAUDE.md is still missing or empty (2nd failure):** Warn: "CLAUDE.md still not
  found after retry. Continuing without it -- you can create one later with /init."
  Fall through to Step 2 (equivalent to option 3). Loop terminates.

**Maximum attempts:** 2 (initial + 1 re-offer). No unbounded loops.

**If option 2:** Interactively draft CLAUDE.md (existing behavior, unchanged).
Do NOT use a template -- CLAUDE.md varies too much between projects.

**If option 3:** Continue. Note that `planning.reference_docs` in workflow.yaml
will not include CLAUDE.md.

If CLAUDE.md **exists**: skip. Do not inspect or suggest modifications.

---

## Step 2: Configuration

If workflow.yaml is **missing**:
- Read the `coding-workflows:stack-detection` skill for detection tables. If the skill file doesn't exist, proceed without it and note the missing skill.
- Using preflight data (including remote detection from Step 0a), present detected settings and ask for confirmation (1 consolidated prompt): language, org/repo, test/lint commands, branch pattern

  **Single remote:** Use it for org/repo extraction. No extra prompt. Current behavior preserved.

  **Multiple remotes:** Present remote selection as part of the config confirmation prompt (no new slot consumed):
  ```
  I detected a [language] project with multiple git remotes:

    1. origin    -> user-fork/my-project
    2. upstream  -> canonical-org/my-project

  Which remote defines your project? This determines the organisation and repository
  name used for issue tracking and PR creation.

    Selected: [default: origin]

  Detected settings:
    Language: [language]
    Org/repo: [org from selected remote]/[repo from selected remote]
    Test: [inferred]
    ...
  ```
  The remote selection and config confirmation are presented together in a single prompt.

  **No remotes:** Fall through to existing error path: ask user for org/repo manually (consumes 1 prompt).

- If user selects a non-origin remote, write `project.remote: {name}` explicitly in workflow.yaml
- Following the template structure in `/coding-workflows:init-config` Step 4, write `.claude/workflow.yaml`

**What `project.remote` means:**

`project.remote` identifies which git remote defines the **project identity** -- the org and repo name used for GitHub issue tracking (`gh issue`), PR creation (`gh pr`), and configuration display. It does NOT change which remote is used for git operations (`git push`, `git fetch`, `git pull`).

**Fork workflow (explicit documentation):**
In a typical fork setup (`origin` = user's fork, `upstream` = canonical repo):
- If user selects `upstream` as `project.remote`: `project.org` = canonical org, `project.name` = canonical repo. This means `gh issue` and `gh pr` commands target the canonical repo (correct -- issues and PRs belong on the upstream repo). Git operations (`git push`) continue to target `origin` (the fork) by default (correct -- code changes go to the user's fork).
- If user selects `origin` as `project.remote`: `project.org` = user's org. All commands target the user's fork (correct for repos where the fork IS the primary project).

Both are valid workflows. The user chooses based on where they want issues and PRs created.

If workflow.yaml is **stale**:
- Show specific drift from preflight Step 0c
- Ask: "Update workflow.yaml with detected values? Custom command overrides will be preserved." (1 prompt)
- If yes: update only the stale fields, preserve user-customized fields (`commands.*`, `planning.*`, `deliberation.*`)
- If no: continue with existing config

If workflow.yaml is **present and current**: skip.

---

## Step 3: Asset Generation

Using preflight data (detected stack, existing assets from all layers, classifications), generate skills first, then agents. This follows the `/coding-workflows:generate-assets` command logic with `both` mode.

**Overlap detection input:** Feed assets from **all discovered layers** (project, user, plugin) into the overlap candidate pool. The `coding-workflows:asset-discovery` skill defines cross-layer comparison (keyword-bag overlap, 0.4 threshold, three-tier classification). Source labels (`[project]`, `[user]`, `[plugin:{name}]`) are included in overlap evidence to help users understand where collisions originate.

**Skills phase (always first):**

1. Reference `/coding-workflows:generate-assets` for the skill template (Step 4a) and domain keyword mappings
2. Reference `coding-workflows:asset-discovery` skill for overlap detection
3. Present detected domains and ask user to select 2-4 for skill generation (combined with agent selection in 1 prompt)
4. For each selected domain, apply `coding-workflows:asset-discovery` three-tier classification against all layers:
   - **BLOCK**: exact name match -> refuse with explanation
   - **WARN**: keyword-bag overlap >= 0.4 -> present evidence with source labels, ask (uses overlap prompt)
   - **IGNORE**: proceed
5. Generate skill files following `/coding-workflows:generate-assets` Step 4a template
6. Manual skills (no `generated_by`) are never touched. Generated skills are evaluated for staleness by the generator command using domain-comparison detection; stale skills are offered for update. Generated current skills are preserved.

**Agents phase (after skills):**

1. Present detected domains for agent generation (part of combined prompt in skills phase)
2. If applicable, ask about `role: architect` assignment
3. Apply `coding-workflows:asset-discovery` overlap detection against all layers
4. Generate agent files following `/coding-workflows:generate-assets` Step 4b template, with `skills:` references populated from the just-generated and existing skills
5. Manual agents preserved. Generated agents evaluated for staleness; stale agents offered for update, current agents preserved.

---

## Step 4: Hooks

Hooks are provided by the plugin and active by default. No configuration is needed.

The plugin ships six hooks across four lifecycle event groups:

**PreToolUse** (advisory, configurable to block):
- `check-dependency-version`: Warns when dependency-add commands lack explicit version pin. Does not flag lockfile-based installs (npm ci, uv sync, pip install -r, etc.).

**PostToolUse** (advisory):
- `test-evidence-logger`: Logs test/lint evidence; warns on failure
- `deferred-work-scanner`: Scans PR body for untracked deferral language

**Stop** (advisory + blocking):
- `stop-deferred-work-check`: Advisory warning for untracked deferred work
- `execute-issue-completion-gate`: Blocks premature exit during CI checks; with `review_gate: true`, also enforces review verdict polling

**SubagentStop** (blocking, lenient):
- `check-agent-output-completeness`: Validates subagent output structure

Hooks can be disabled individually via environment variables (naming convention: `CODING_WORKFLOWS_DISABLE_HOOK_{HOOK_NAME}` where HOOK_NAME drops any "CHECK" prefix/suffix from the filename). See the README Hooks section for the full disable variable list and error handling.

No prompt. No file writes. Display hook status in the summary.

---

## Step 5: Summary Report

```
Workflow Setup Complete
======================

Configuration:
  CLAUDE.md                [created/skipped/present]  {detail}
  .claude/workflow.yaml    [created/updated/skipped]  {detail}

Agents:
  .claude/agents/X.md      [created/skipped]  {reason}

Skills:
  .claude/skills/X/SKILL.md [created/skipped]  {reason}

Hooks:
  check-dependency-version          [active]  Advisory -- warns on unversioned dependency installs
  test-evidence-logger              [active]  Advisory -- logs test/lint evidence
  deferred-work-scanner             [active]  Advisory -- scans PR body for untracked deferrals
  stop-deferred-work-check          [active]  Advisory -- warns on untracked deferred work
  execute-issue-completion-gate     [active]  Blocking -- CI gate always on; review gate if configured
  check-agent-output-completeness   [active]  Blocking (lenient) -- validates subagent output structure

Pipeline completed:
  [x] Preflight audit
  [x] CLAUDE.md              {created / skipped (exists) / skipped (declined)}
  [x] Configuration          {created / updated / skipped (current)}
  [x] Asset generation       Skills: {N created, M skipped}  Agents: {N created, M skipped}
  [x] Hooks                  (active by default -- see README for disable options)

Prompts used: {N} of 4 max

Next steps:
1. Edit generated files -- fill in TODO placeholders with project-specific knowledge
2. Commit: git add .claude/
3. Start using workflow commands:
   - /coding-workflows:create-issue github <description>
   - /coding-workflows:prepare-issue <issue-number>
   - /coding-workflows:execute-issue <issue-number>
   - /coding-workflows:execute-issue-worktree <issue-number> (for parallel development)
   - /coding-workflows:cleanup-worktree <issue-number> (post-merge worktree removal)
```

Status tag definitions:
- `[created]` -- File did not exist, was generated
- `[updated]` -- File was stale or outdated; updated with user confirmation
- `[skipped]` -- File preserved (manual, current, or user declined). Reason in parentheses.
- `[info]` -- Informational only, no action taken

---

## Error Handling

| Error | Action |
|-------|--------|
| Preflight fails (can't read filesystem) | Stop, report error |
| Config creation fails (no git remote, user declines) | Stop -- agents/skills depend on config context |
| No git remotes found | Ask user for org/repo manually (consumes 1 prompt from budget). `project.remote` is omitted. |
| Remote fetch failure (git error) | Ask user for org/repo manually (consumes 1 prompt from budget). `project.remote` is omitted. |
| Remotes with identical org/repo (different protocols) | Deduplicate before presenting selection: show one entry per unique org/repo pair, prefer first remote name. If all remotes resolve to same org/repo, treat as single-remote (no selection needed). |
| User-level asset directory inaccessible | Warn once, continue with project + plugin layers |
| Plugin skill directory inaccessible | Warn once, continue with project + user layers |
| CLAUDE.md missing/empty after /init (1st attempt) | Warn, re-offer 3-option menu (no extra prompt consumed) |
| CLAUDE.md missing/empty after /init (2nd attempt) | Warn, fall through to skip. Loop terminates. |
| Agent generation fails mid-way | Continue to skills, report partial results |
| Skill generation fails mid-way | Report partial results in summary |
| Prompt budget exhausted | Use detected defaults for remaining phases, note in summary |

---

## Recovery / Calling Individual Steps

| State | Recovery |
|-------|----------|
| Has config but no agents | `/coding-workflows:generate-assets agents` |
| Has config but no skills | `/coding-workflows:generate-assets skills` |
| Has config but no agents or skills | `/coding-workflows:generate-assets` |
| Config is stale | Re-run `/coding-workflows:setup` (preflight detects drift) |
| Everything exists and current | `/coding-workflows:setup` is safe to re-run (all phases skip) |
