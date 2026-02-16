---
description: Generate project-specific agents and skills by scanning the codebase
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
  - WebSearch
args:
  mode:
    description: "What to generate: agents, skills, or both (default: both)"
    required: false
---

# Generate Assets

> **Size note:** This command exceeds the standard ~200-line guideline due to multi-mode UX flows (5 modes, 2 asset types, 2 analysis paths). See [design session on #241](https://github.com/Kiwi-Home/ai-coding-resources-complete/issues/241#issuecomment-3906290654) for rationale.

Scan the codebase to detect technology stack, analyze project patterns, and generate project-specific agent and skill files. Skills are generated before agents so that agents can declare valid `skills:` frontmatter references.

**Mode argument:** Controls what is generated.
- `both` (default): Generate skills first, then agents with `skills:` cross-references
- `skills`: Generate skills only
- `agents`: Generate agents only (references only existing skills)
- `review-config`: Generate `.claude/review-config.yaml` only (project-specific review focus areas)
- `all`: Generate skills, agents, and review-config in one pass

Generated assets are **pre-populated with project-specific knowledge** when sufficient context is available (CLAUDE.md, README, source files). When context is limited, assets are scaffolding with TODO placeholders. Hand-edited assets remain the most effective.

## Reference Index

This command delegates to and references the following skills and reference files:

| Skill | Reference File | Description |
|-------|---------------|-------------|
| `coding-workflows:codebase-analysis` | SKILL.md | Analysis criteria |
| `coding-workflows:stack-detection` | SKILL.md + `references/framework-hints.md` | Stack detection + framework convention hints |
| `coding-workflows:asset-discovery` | SKILL.md + `references/staleness-ux.md` + `references/token-budgets.md` | Discovery, staleness UX, token budgets |
| `coding-workflows:skill-creator` | `references/frontmatter-reference.md` + `references/generation-template.md` | Frontmatter spec, skill scaffold |
| `coding-workflows:agent-patterns` | `references/agent-generation-spec.md` + `references/role-defaults.md` | Agent generation template, role configuration |
| `coding-workflows:pr-review` | SKILL.md | Review config schema |

---

## Step 0: Resolve Project Context

1. Use the Read tool to read `.claude/workflow.yaml`.
   - If file exists: extract `project.language` and other settings.
   - If file does not exist: run `/coding-workflows:init-config` first, or auto-detect below.

2. **Read reference docs**:
   - If `planning.reference_docs` is configured, use Read tool on each listed file.
   - If a listed file is missing, warn user ("File X listed in workflow.yaml not found") and continue.
   - **Auto-discovery**: Also read CLAUDE.md and README.md if present, even if not in config.
   - Extract: conventions, patterns, settled decisions, project purpose.
   - These become input to Step 1 analysis.

3. If no config, auto-detect from project files (same detection as `/coding-workflows:init-config`).

**Parse mode argument:** Read `{{ARGUMENTS}}`. If empty or `both`, generate both skills and agents. If `skills`, generate skills only. If `agents`, generate agents only. If `review-config`, generate review config only. If `all`, generate skills, agents, and review config. Any other value: warn and default to `both`.

---

## Step 1: Analyze Codebase

Read the `coding-workflows:codebase-analysis` skill for analysis criteria and the `coding-workflows:stack-detection` skill for per-stack analysis guidance.

If the `coding-workflows:codebase-analysis` skill is not found, perform basic analysis: read CLAUDE.md, README.md, and existing agent/skill frontmatter only.

Using the reference docs from Step 0 and the skills above:

1. Identify the project's technology stack (language, framework, key libraries)
2. Sample key source files per detected domain (selection criteria in `coding-workflows:codebase-analysis` skill)
3. Identify domains, conventions, and patterns
4. Flag unfamiliar libraries/domains (novel, version, or domain signals per `coding-workflows:codebase-analysis`)
5. Assess existing agent/skill coverage gaps

**Analysis output must include:**
- Detected domains with file path evidence
- Conventions observed with citations (at least one concrete file path each)
- For agent generation: role signals (which domains warrant architect vs reviewer vs specialist)
- For skill generation: validation criteria (what rules can be checked programmatically), pattern catalog (which patterns repeat)
- Unfamiliarity flags (if any)
- Coverage gaps

**Note:** Analysis runs once regardless of mode. When generating both asset types, extract both agent and skill deliverable sets from the same analysis pass (see `coding-workflows:codebase-analysis` skill).

---

## Step 1a: Domain Research (conditional)

**Gate**: If Step 1 produced unfamiliarity flags, proceed. Otherwise skip to Step 2.

Present unfamiliarity flags to user with proposed search queries (1 per flag, max 5 total):

```
Unfamiliar libraries/domains detected:
- "dramatiq" -- async task queue (app/workers/, 8 files) -- NOVEL
- "peft" -- parameter-efficient fine-tuning (training/) -- DOMAIN

Proposed searches:
1. "dramatiq best practices Python async workers"
2. "peft LoRA fine-tuning patterns production"

Execute these searches? (y/n)
```

If user confirms: execute searches, incorporate findings. If user declines: flag affected domains with "LIMITED CONTEXT" in Step 3 proposals.

Prioritization (if >5 flags): direct dependency > usage frequency > domain criticality (auth/payments > logging).

---

## Step 1b: Fallback to Stack Detection (conditional)

**Gate**: If Step 1 analysis is premature (per `coding-workflows:codebase-analysis` criteria: no docs, <5 source files, or 0 domains detected), use this fallback. Otherwise skip to Step 2.

Fall back to the declarative reference tables in `coding-workflows:stack-detection`:
- Use Language Detection, Framework Detection, and Domain Detection tables
- Present results as: "Using stack detection (limited project context available)"

When fallback is used, the question budget in Step 3 increases from 2 to 3 (more user input needed to compensate for less analysis context).

---

## Step 2: Discover Existing Assets & Present Findings

Read the `coding-workflows:asset-discovery` skill for discovery locations and similarity heuristics.

Scan all three layers for existing assets (both agents AND skills, for cross-type matching):

| Layer | Skills scan | Agents scan |
|-------|-------------|-------------|
| Project | `.claude/skills/*/SKILL.md` | `.claude/agents/*.md` |
| User | `~/.claude/skills/*/SKILL.md` | `~/.claude/agents/*.md` |
| Plugin | `plugins/*/skills/*/SKILL.md` | *(none currently bundled)* |

For each discovered asset, read its frontmatter (`name`, `description`, `domains`, `generated_by`, `generated_at`). Classify each project-layer asset's provenance state per the `coding-workflows:asset-discovery` skill.

Present to user (grouped by type, sorted by layer then alphabetically):

```
Detected stack: [language] / [framework]
Domains found: [list]

Existing assets:
- [project]  .claude/skills/{name}/SKILL.md -- "{description}" [generated|manual]
- [plugin:coding-workflows]  coding-workflows:{name} -- "{description}"
- [project]  .claude/agents/{name}.md -- "{description}" [generated|manual]

Provenance: N skills (X generated, Y stale, Z manual), N agents (...)
```

---

## Step 3: Propose & Confirm

### `both` Mode UX Flow

When generating both asset types, proposals are presented sequentially: skills first, then agents. This ordering ensures agents can reference just-generated skills.

1. Propose skills based on analysis (see Skill Proposals below)
2. User confirms skill selection
3. Propose agents based on analysis, with `skills:` references to the just-confirmed skills (see Agent Proposals below)
4. User confirms agent selection

### `skills` Mode

Present only skill proposals. Skip agent proposals entirely.

### `agents` Mode

Present only agent proposals. `skills:` references are populated only from existing skills (project, user, or plugin layer). If a skill would be relevant but doesn't exist, log: "Skill `X` would be relevant for agent `Y` but does not exist. Run `/coding-workflows:generate-assets skills` first."

### Skill Proposals

#### Analysis path (Step 1 succeeded):

Present analysis summary, then skill proposals with codebase evidence. Each proposal includes: name, why (with file paths), domains, and what will be pre-populated.

**Question 1**: "Confirm or adjust proposed skills?"
**Question 2** (if existing project skills found): "Update existing skills or skip them?"

#### Fallback path (Step 1b was used):

Using the domains detected from the `coding-workflows:stack-detection` skill's Domain Detection Table, present each detected domain with a proposed skill name (e.g., API layer -> `api-patterns`, Data models -> `data-patterns`). Only show detected domains. Infrastructure requires 2+ signals. Recommend 2-4 domains.

**Question 1:** "Which domains should have project-specific skills?"
**Question 2** (if existing project skills found): "Update existing skills or skip them?"
**Question 3** (if needed): "Any additional domains not listed above?"

#### Skill abort condition:

If user confirms 0 skills: in `skills` mode, stop. In `both` mode, skip to agent proposals.

For each proposed skill, apply the similarity heuristics from the `coding-workflows:asset-discovery` skill. If WARN tier overlap detected, present and ask: skip / rename / generate anyway. If BLOCK (exact name match), refuse with explanation.

### Agent Proposals

#### Analysis path (Step 1 succeeded):

Present proposals with codebase evidence. Each proposal includes: name, why (with file paths), domains, skills references, and what will be pre-populated.

**Question 1**: "Confirm or adjust proposed agents?"
**Question 2** (if needed): "Adjust any agent roles? Options: `reviewer` (default), `architect`, `specialist`. Read `references/role-defaults.md` from the `coding-workflows:agent-patterns` skill for trade-offs."

#### Fallback path (Step 1b was used):

Present detected stack, offer domain selection.

**Question 1**: "Which domains should have specialist agents?" (show detected domains)
**Question 2**: "Adjust any agent roles?"
**Question 3** (if existing agents found): "Update existing agents or skip them?"

#### Agent abort condition:

If user confirms 0 agents: in `agents` mode, stop. In `both` mode, skip to summary.

---

## Step 4a: Generate Skill Files

**Gate**: Skip if mode is `agents`.

For each selected domain, create `.claude/skills/{domain}/SKILL.md`.

**Read these references for generation details:**
- Read `references/generation-template.md` from the `coding-workflows:skill-creator` skill for the scaffold template (frontmatter + body), pre-population sources, and evidence citation rules.
- Read `references/frontmatter-reference.md` from the `coding-workflows:skill-creator` skill for field definitions and description authoring guidance.
- Read `references/framework-hints.md` from the `coding-workflows:stack-detection` skill for fallback-path convention hints.

**Pre-generation checks:** Apply the three-tier classification from the `coding-workflows:asset-discovery` skill. Read `references/staleness-ux.md` from the `coding-workflows:asset-discovery` skill for display templates and UX flows (Skill Pre-Generation Checks section).

---

## Step 4b: Generate Agent Files

**Gate**: Skip if mode is `skills`.

For each selected domain, generate `.claude/agents/{domain}-{role}.md`.

**Read these references for generation details:**
- Read `references/agent-generation-spec.md` from the `coding-workflows:agent-patterns` skill for the agent template, rendered examples, conditional field omission rules, and domain keywords.
- Read `references/role-defaults.md` from the `coding-workflows:agent-patterns` skill for role-based frontmatter defaults, tool sets, and trust boundary.
- Read `references/token-budgets.md` from the `coding-workflows:asset-discovery` skill for `skills:` population rules (universal skills, domain matching, aggregate budget check).

**Pre-generation checks:** Apply the three-tier classification from the `coding-workflows:asset-discovery` skill. Read `references/staleness-ux.md` from the `coding-workflows:asset-discovery` skill for display templates and UX flows (Agent Pre-Generation Checks section).

---

## Step 4c: Generate Review Config

**Gate**: Skip if mode is `skills`, `agents`, or `both`.

Generate `.claude/review-config.yaml` using the codebase analysis from Step 1.

1. Read the `coding-workflows:pr-review` skill to understand the four universal review category types and the review config schema. If the skill file doesn't exist, proceed without it and note the missing skill.
2. Map codebase analysis results to category instantiations:
   - **Correctness**: What does "correct" mean here? (from framework patterns, test expectations, CLAUDE.md requirements)
   - **Integrity**: What references matter? (import graph, API contracts, config references, cross-module dependencies)
   - **Compliance**: What conventions apply? (from CLAUDE.md, linter config, observed patterns)
   - Quality is universal and does not need project-specific config
3. Extract anti-patterns from codebase signals (common mistakes in test failures, patterns CLAUDE.md warns against, framework-specific pitfalls)
4. Write `.claude/review-config.yaml` following the schema documented in the `coding-workflows:pr-review` skill

**Pre-generation check:** If `.claude/review-config.yaml` already exists:
- Read provenance fields (`generated_by`, `generated_at`)
- If generated: offer to update or skip
- If manually created: skip with note

---

## Step 5: Update Config (if applicable)

If the user selected an architect-role agent, and there are 2+ agents total, suggest adding conflict overrides to `.claude/workflow.yaml`:

```yaml
deliberation:
  conflict_overrides:
    - { agent_a: "{architect-agent}", agent_b: "{other-agent}", level: "HIGH" }
```

---

## Step 6: Summary

```
Generated assets:
{list generated files by type}

All assets (discovered + generated):
Skills: [list each with source label and description]
Agents: [list each with source label and description]

Next steps:
1. Review pre-populated conventions and settled decisions for accuracy
2. Fill in remaining TODO placeholders with your team's actual patterns
3. Commit the files: git add .claude/agents/ .claude/skills/
4. Assets will be automatically discovered by workflow commands

Tip: Skills are the single source of truth for spec and framework rules.
Agents encode project-specific knowledge. Agents reference skills -- never duplicate rule content.
```
