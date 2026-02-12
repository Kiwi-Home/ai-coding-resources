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

| Check | How | Result |
|-------|-----|--------|
| CLAUDE.md | Read `CLAUDE.md` at project root | exists / missing |
| workflow.yaml | Read `.claude/workflow.yaml` | exists / missing |
| Agents | Glob `.claude/agents/*.md` | list of paths |
| Skills | Glob `.claude/skills/*/SKILL.md` | list of paths |

### 0b. Classify Agents and Skills

For each discovered agent and skill file, read YAML frontmatter and classify using the
provenance rules from the `coding-workflows:asset-discovery` skill:

| Condition | Classification | Behavior |
|-----------|---------------|----------|
| Has `generated_by` field | `[generated]` | May update. Staleness determined in Steps 3-4 by generators. |
| No `generated_by` field | `[manual]` | Preserve. Never offer overwrite. |
| Unparseable frontmatter | `[manual]` | Treat as manually created (per asset-discovery fallback). |
| File missing | `[missing]` | Will be created if user selects domain. |

Additionally, for assets classified as `[manual]`, check for `# TODO:` markers. If present,
note as informational in Step 0e: these may be legacy generated files from before provenance
tracking was added. This is a UX hint only -- it does not change the classification.

### 0c. Detect Stale Configuration

If `workflow.yaml` exists, run stack detection using the `coding-workflows:stack-detection` skill reference tables (`plugins/coding-workflows/skills/stack-detection/SKILL.md`) against the live codebase. Compare detected values against stored values:

| Field | Stale if... |
|-------|-------------|
| `project.language` | Detected language differs from stored |
| `project.org` | Git remote org differs from stored |
| `project.name` | Git remote repo name differs from stored |
| Framework | New framework dependency detected but not in config |
| Framework removed | Config references framework but dependency is gone |

Do NOT mark stale for `commands.test/lint/typecheck` mismatches -- these may be intentional user overrides.

**Review gate drift:** Run review automation detection per `init-config` Step 2e. If `.github/workflows/` now contains review automation signals but `hooks.execute_issue_completion_gate.review_gate` is `false` (or absent), flag as stale: "Review automation detected in CI workflows but `review_gate` is currently `false`."

**Domain drift:** Also detect new directory-based domains (per `coding-workflows:stack-detection` Domain Detection table) not represented in existing agents/skills. Report as informational: "New domains detected: [list]"

### 0d. Monorepo Check

Check for monorepo indicators per `init-config` Step 2d (workspace files, multiple language files in distinct subdirectories).

If detected, warn: "This appears to be a monorepo. Configure for your primary service directory."

### 0e. Present Unified State Report

Display all findings (informational, no prompts):

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
| 1 | CLAUDE.md missing -> "Create one now?" | Step 1 |
| 2 | Config missing/stale -> "Confirm settings" (consolidated) | Step 2 |
| 3 | Combined domain selection (skills + agents together) | Step 3 |
| 4 | Overlap resolution (if WARN-tier collisions detected) | Step 3 |

If both CLAUDE.md is present AND config is current, prompts 1-2 are not consumed, leaving more budget for generation phases. If prompt budget is exhausted, use detected defaults for remaining phases and note in summary.

---

## Step 1: CLAUDE.md Gate (soft)

If CLAUDE.md is **missing**:
- Warn: "No CLAUDE.md found. This file helps Claude understand your project conventions and is the most important context source for initialization quality."
- Offer: "Would you like to describe your project so I can draft a CLAUDE.md?" (1 prompt)
- If yes: interactively draft CLAUDE.md (do NOT use a template -- CLAUDE.md varies too much between projects)
- If no: continue. Note that `planning.reference_docs` in workflow.yaml will not include CLAUDE.md.

If CLAUDE.md **exists**: skip. Do not inspect or suggest modifications.

---

## Step 2: Configuration

If workflow.yaml is **missing**:
- Read the `coding-workflows:stack-detection` skill for detection tables
- Using preflight data, present detected settings and ask for confirmation (1 consolidated prompt): language, org/repo, test/lint commands, branch pattern
- Following the template structure in `/coding-workflows:init-config` Step 4, write `.claude/workflow.yaml`

If workflow.yaml is **stale**:
- Show specific drift from preflight Step 0c
- Ask: "Update workflow.yaml with detected values? Custom command overrides will be preserved." (1 prompt)
- If yes: update only the stale fields, preserve user-customized fields (`commands.*`, `planning.*`, `deliberation.*`)
- If no: continue with existing config

If workflow.yaml is **present and current**: skip.

---

## Step 3: Asset Generation

Using preflight data (detected stack, existing assets, classifications), generate skills first, then agents. This follows the `/coding-workflows:generate-assets` command logic with `both` mode.

**Skills phase (always first):**

1. Reference `/coding-workflows:generate-assets` for the skill template (Step 4a) and domain keyword mappings
2. Reference `coding-workflows:asset-discovery` skill for overlap detection
3. Present detected domains and ask user to select 2-4 for skill generation (combined with agent selection in 1 prompt)
4. For each selected domain, apply `coding-workflows:asset-discovery` three-tier classification:
   - **BLOCK**: exact name match -> refuse with explanation
   - **WARN**: keyword-bag overlap >= 0.4 -> present evidence, ask (uses overlap prompt)
   - **IGNORE**: proceed
5. Generate skill files following `/coding-workflows:generate-assets` Step 4a template
6. Manual skills (no `generated_by`) are never touched. Generated skills are evaluated for staleness by the generator command using domain-comparison detection; stale skills are offered for update. Generated current skills are preserved.

**Agents phase (after skills):**

1. Present detected domains for agent generation (part of combined prompt in skills phase)
2. If applicable, ask about `role: architect` assignment
3. Apply `coding-workflows:asset-discovery` overlap detection
4. Generate agent files following `/coding-workflows:generate-assets` Step 4b template, with `skills:` references populated from the just-generated and existing skills
5. Manual agents preserved. Generated agents evaluated for staleness; stale agents offered for update, current agents preserved.

---

## Step 4: Hooks

Hooks are provided by the plugin and active by default. No configuration is needed.

The plugin ships five hooks across three lifecycle events:

**PostToolUse** (advisory):
- `test-evidence-logger`: Logs test/lint evidence; warns on failure
- `deferred-work-scanner`: Scans PR body for untracked deferral language

**Stop** (advisory + blocking):
- `stop-deferred-work-check`: Advisory warning for untracked deferred work
- `execute-issue-completion-gate`: Blocks premature exit during CI checks; with `review_gate: true`, also enforces review verdict polling

**SubagentStop** (blocking, lenient):
- `check-agent-output-completeness`: Validates subagent output structure

Hooks can be disabled individually via environment variables. See the README Hooks section for details, disable variables, and error handling.

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
| Git remote not found | Ask user for org/repo manually (consumes 1 prompt from budget) |
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
