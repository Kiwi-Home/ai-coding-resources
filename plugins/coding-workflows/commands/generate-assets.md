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

Scan the codebase to detect technology stack, analyze project patterns, and generate project-specific agent and skill files. Skills are generated before agents so that agents can declare valid `skills:` frontmatter references.

**Mode argument:** Controls what is generated.
- `both` (default): Generate skills first, then agents with `skills:` cross-references
- `skills`: Generate skills only
- `agents`: Generate agents only (references only existing skills)
- `review-config`: Generate `.claude/review-config.yaml` only (project-specific review focus areas)
- `all`: Generate skills, agents, and review-config in one pass

Generated assets are **pre-populated with project-specific knowledge** when sufficient context is available (CLAUDE.md, README, source files). When context is limited, assets are scaffolding with TODO placeholders. Hand-edited assets remain the most effective.

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

Present unfamiliarity flags to user with proposed search queries:

```
Unfamiliar libraries/domains detected:
- "dramatiq" -- async task queue (used in app/workers/, 8 files) -- NOVEL: unfamiliar framework
- "peft" -- parameter-efficient fine-tuning (used in training/) -- DOMAIN: niche ML technique

Proposed searches (1 per flag, max 5 total):
1. "dramatiq best practices Python async workers"
2. "peft LoRA fine-tuning patterns production"

Execute these searches? (y/n)
```

If user confirms: execute searches, incorporate findings into analysis (conventions, checklist items, anti-patterns).
If user declines: proceed with analysis results; flag affected domains with "LIMITED CONTEXT" in Step 3 proposals. Pre-population will be sparser for these domains.

Prioritization (if >5 flags): direct dependency > usage frequency in sampled files > domain criticality (auth/payments > logging).

---

## Step 1b: Fallback to Stack Detection (conditional)

**Gate**: If Step 1 analysis is premature (per `coding-workflows:codebase-analysis` criteria: no docs, <5 source files, or 0 domains detected), use this fallback. Otherwise skip to Step 2.

Fall back to the declarative reference tables in `coding-workflows:stack-detection`:
- Use Language Detection, Framework Detection, and Domain Detection tables
- Present results as: "Using stack detection (limited project context available)"

When fallback is used, the question budget in Step 3 increases from 2 to 3 (more user input needed to compensate for less analysis context).

---

## Step 2: Discover Existing Assets & Present Findings

Read the `coding-workflows:asset-discovery` skill for discovery locations and similarity heuristics. If the skill file doesn't exist, proceed without it and note the missing skill.

Scan all three layers for existing assets (both agents AND skills, for cross-type matching):

| Layer | Skills scan | Agents scan |
|-------|-------------|-------------|
| Project | `.claude/skills/*/SKILL.md` | `.claude/agents/*.md` |
| User | `~/.claude/skills/*/SKILL.md` | `~/.claude/agents/*.md` |
| Plugin | `plugins/*/skills/*/SKILL.md` | *(none currently bundled)* |

For each discovered asset, read its frontmatter (`name`, `description`, `domains`, `generated_by`, `generated_at`). If a discovery layer is inaccessible, warn once and continue.

Classify each project-layer asset's provenance state per the `coding-workflows:asset-discovery` skill's Provenance Classification rules.

Present to user (grouped by type, sorted by layer then alphabetically). Show provenance tags for project-layer assets only:

```
Detected stack:
- Language: [language]
- Framework: [framework]
- Domains found: [list]

Existing assets discovered:
- [project]  .claude/skills/{name}/SKILL.md -- "{description}" [generated]
- [project]  .claude/skills/{name}/SKILL.md -- "{description}" [manual]
- [user]     ~/.claude/skills/{name}/SKILL.md -- "{description}"
- [plugin:coding-workflows]  coding-workflows:{name} -- "{description}"
- [project]  .claude/agents/{name}.md -- "{description}" [generated]
- [project]  .claude/agents/{name}.md -- "{description}" [manual]

Provenance summary:
- N skills: X generated (Y stale), Z manual
- N agents: X generated (Y stale), Z manual
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

#### Analysis path (Step 1 succeeded, Step 1b was skipped):

Present analysis summary, then skill proposals with codebase evidence:

```
Codebase Analysis Summary:
- Project: [purpose from README/CLAUDE.md]
- Primary domains: [list with file evidence]
- Conventions observed: [2-3 key patterns with citations]
- Existing skills: [list from discovery]

Proposed skills based on analysis:

1. **error-handling-patterns**
   - Why: Custom error wrapper observed in 5+ modules (src/errors/, app/middleware/error_handler.py)
   - Domains: [errors, exceptions, error-handling]
   - Pre-populated: error wrapper pattern, response format conventions

2. **api-patterns**
   - Why: Consistent API response format across 8 controllers (app/controllers/)
   - Domains: [api, routes, endpoints, http]
   - Pre-populated: response format, authentication patterns, validation conventions

[Similarity check results from coding-workflows:asset-discovery]

Proceed with generation? (adjust list or confirm)
```

**Question 1**: "Confirm or adjust proposed skills?"
**Question 2** (if existing project skills found): "Update existing skills or skip them?"

#### Fallback path (Step 1b was used):

Present detected stack, offer domain selection:

**Question 1:** "Which domains should have project-specific skills?"

Using the domains detected in Step 1b (from the `coding-workflows:stack-detection` skill's Domain Detection Table), present each as an option with its proposed skill name:

| Detected Domain | Proposed Skill Name |
|-----------------|---------------------|
| API layer | `api-patterns` |
| Data models | `data-patterns` |
| Data access | `storage-patterns` |
| Business logic | `service-patterns` |
| Auth/Security | `security-patterns` |
| Testing | `testing-patterns` |
| Framework | `{framework}-conventions` |
| Infrastructure | `infra-patterns` |

Only show domains that were actually detected. Infrastructure requires 2+ signals (per the `coding-workflows:stack-detection` skill's gating rule). Recommend 2-4 domains.

**Question 2** (if existing project skills found): "Update existing skills or skip them?"
**Question 3** (if needed): "Any additional domains not listed above?"

#### Skill abort condition:

If user confirms 0 skills for generation: in `skills` mode, stop with: "No skills selected. Run again when ready, or create skills manually in `.claude/skills/`." In `both` mode, skip skill generation and proceed to agent proposals.

For each proposed skill, apply the similarity heuristics from the `coding-workflows:asset-discovery` skill against all discovered assets. If any overlap is detected at the WARN tier:

```
Potential overlaps:
  {proposed-name}  <-->  {existing-name} [{source-layer}]
    Overlap: keywords share: {shared keywords}
    Action: skip / rename / generate anyway
```

If a proposed skill triggers BLOCK (exact name match), refuse with explanation.

### Agent Proposals

#### Analysis path (Step 1 succeeded, Step 1b was skipped):

Present analysis summary, then proposals with codebase evidence:

```
Proposed agents based on analysis:

1. **payments-reviewer**
   - Why: Stripe integration (src/billing/, 8 files, 3 service objects)
   - Domains: [payments, stripe, webhooks, billing]
   - Skills: [billing-patterns]  (just generated / existing)
   - Pre-populated: webhook handling patterns, idempotency conventions

2. **background-jobs-specialist**
   - Why: Sidekiq usage with custom job base class (app/jobs/, 12 job classes)
   - Domains: [background-jobs, sidekiq, async, workers]
   - Skills: []  (no matching skills)
   - Pre-populated: retry strategies, job serialization patterns

[Similarity check results from coding-workflows:asset-discovery]

Proceed with generation? (adjust list or confirm)
```

**Question 1**: "Confirm or adjust proposed agents?"
**Question 2** (if needed): "Adjust any agent roles? Options: `reviewer` (default), `architect`, `specialist`. See Role-Based Defaults (Step 4b) for trade-offs."

#### Fallback path (Step 1b was used):

Present detected stack, offer domain selection (current behavior):

**Question 1**: "Which domains should have specialist agents?" (show detected domains)
**Question 2**: "Adjust any agent roles? Options: `reviewer` (default), `architect`, `specialist`. See Role-Based Defaults (Step 4b) for trade-offs."
**Question 3** (if existing agents found): "Update existing agents or skip them?"

#### Agent abort condition:

If user confirms 0 agents for generation: in `agents` mode, stop with: "No agents selected. Run again when ready, or create agents manually in `.claude/agents/`." In `both` mode, skip agent generation and proceed to summary.

---

## Step 4a: Generate Skill Files

**Gate**: Skip if mode is `agents`.

For each selected domain, create `.claude/skills/{domain}/SKILL.md`.

### Pre-population Sources

| Section | Analysis Path | Fallback Path | Minimal Context |
|---------|---------------|---------------|-----------------|
| `name` | Domain-specific from analysis | Generic from `coding-workflows:stack-detection` table | Generic from `coding-workflows:stack-detection` table |
| Purpose | From project analysis with evidence | TODO | TODO |
| Conventions | Observed patterns with file citations | Framework-specific hints (see below) | Framework-specific hints |
| Patterns | Repeating patterns from code sampling | TODO | TODO |
| Anti-Patterns | Common mistakes inferred from codebase | TODO | TODO |
| Validation Checklist | Domain-specific checks from analysis | TODO | TODO |

TODOs only for: edge cases requiring human judgment, production-specific knowledge not visible in code, areas where research was declined.

### Evidence Citations

When pre-populating conventions, cite evidence:
- File paths: `src/billing/webhooks.py`
- Pattern coverage: `app/services/*.rb (8 files matching pattern)`
- Always include at least one concrete file path per convention -- never just counts

### Pre-Generation Checks

Before writing each file, apply the three-tier classification from the `coding-workflows:asset-discovery` skill:

1. **Self-match with provenance branching:** If the proposed output path matches an existing file:
   1. Read provenance fields (`generated_by`, `generated_at`) from existing file's frontmatter
   2. If generated: compare existing asset's `domains` array against current analysis domains for staleness (see `coding-workflows:asset-discovery` skill's Domain-Comparison Staleness Detection)
   3. Branch to appropriate UX:

   | # | State | UX |
   |---|-------|----|
   | 1 | Generated + stale | Show staleness summary (below). Suggest **Update** (default). Offer: Skip, Show full proposed content. |
   | 2 | Generated + current | "Asset is current (generated {date}). Skipping." |
   | 3 | Manually created | "Not generated by workflow commands. Skipping." (Informational: analysis notes if relevant, e.g., "analysis detected overlapping domains: X, Y") |

   **Error paths:**
   - Frontmatter unparseable: treat as manually created
   - `generated_by` present but `domains` array empty/missing: skip staleness detection, offer "Update or skip?"

   **Staleness summary format:**
   ```
   {filename} may need updating (generated {date}):

     New domains relevant to this asset:
     + {domain} (detected in {file_path}, {N} files)

     Domains no longer detected:
     - {domain} ({evidence})

     Framework changed:
     ~ {old} -> {new}

     [Update / Skip / Show full proposed content]
   ```

2. **BLOCK:** If exact name matches an installed plugin skill, refuse: "Skill `{name}` is already provided by the `{plugin}` plugin."
3. **WARN:** If similarity threshold exceeded (caught in Step 3 but re-checked here as safety net), confirm user's choice.
4. **Non-standard structure:** If `.claude/skills/` contains flat files (not in subdirectories), warn the user and suggest restructuring.

### Skill Scaffold Template

**Frontmatter reference:** Spec fields per `coding-workflows:skill-creator` (Step 4 > Frontmatter table). The `domains`, `generated_by`, and `generated_at` fields are internal provenance tracking for staleness detection, used by `coding-workflows:asset-discovery` — not part of the Anthropic spec (validators accept these fields).

**Description quality:** Description field requirements per `coding-workflows:skill-creator` (Step 4 > Frontmatter). Generated descriptions must discriminate THIS skill from others — generic triggers that differ only by domain noun are non-discriminating. Interpolate analysis-derived specifics whenever available.

#### Analysis path (Step 1 succeeded):

```yaml
---
name: {domain}-patterns
description: "{Domain} conventions and patterns for {framework} projects. Encodes {specific_conventions_from_analysis}. Use when: {analysis_trigger_1}, {analysis_trigger_2}, or {analysis_trigger_3}."
domains: [{domain keywords}]
generated_by: generate-assets
generated_at: "{YYYY-MM-DD}"
---
```

Example: If analysis found custom error wrapper + response envelope + auth middleware:
```yaml
description: "API conventions and patterns for FastAPI projects. Encodes error wrapper pattern, standard response envelope, and dependency-injection auth. Use when: implementing new API endpoints, reviewing request/response handling, or debugging middleware chains."
```

#### Fallback path (Step 1b was used, limited context):

```yaml
---
name: {domain}-patterns
description: "{Domain} conventions and patterns for {framework} projects. TODO: Replace with project-specific description per coding-workflows:skill-creator guidance. Use when: reviewing {domain} code, implementing new {domain} features, or onboarding to {domain} patterns."
domains: [{domain keywords}]
generated_by: generate-assets
generated_at: "{YYYY-MM-DD}"
---
```

```markdown
# {Domain} Patterns

## Purpose
{analysis_path: 1-2 sentences from analysis with evidence}
{fallback_path: TODO block}

## Conventions
{analysis_path: observed patterns with file citations}
{fallback_path: framework-specific hints from table below}

## Patterns
### {Pattern Category}
{analysis_path: repeating patterns from code sampling}
{fallback_path: TODO block}

## Anti-Patterns
{analysis_path: common mistakes inferred from codebase}
{fallback_path: TODO block}

## Validation Checklist
{analysis_path: domain-specific checks}
{fallback_path: TODO block}

## Reference
# TODO: Links to internal docs, ADRs, or external resources
```

**Note:** The template does NOT include a "When to Use" body section. Per the skill-creator spec, "when to use" information belongs in the `description` field -- the body loads only after triggering, so body-level usage guidance wastes tokens.

### Framework-Specific Hints (Fallback Path Only)

Inject framework-appropriate hints into the `## Conventions` section when using the fallback path:

**FastAPI:**

| Domain | Hints |
|--------|-------|
| API | Dependency injection patterns (Depends()), Pydantic request/response models, async handler patterns, error response format, router organization |
| Data | SQLAlchemy patterns, Alembic migration conventions, session management |
| Testing | pytest fixtures, httpx.AsyncClient usage, factory patterns |

**Rails:**

| Domain | Hints |
|--------|-------|
| API | Controller conventions (thin controllers, service objects), strong parameters, concerns, error response format, route organization |
| Data | ActiveRecord patterns, migration conventions, query scoping, association patterns |
| Testing | RSpec factories, request specs, shared examples, fixture strategies |

**Next.js:**

| Domain | Hints |
|--------|-------|
| API | App router patterns, API routes, middleware, server actions, data fetching |
| Data | Prisma patterns, server actions, data access layer conventions |
| Testing | Jest + React Testing Library, component testing, mock patterns |

**Express:**

| Domain | Hints |
|--------|-------|
| API | Router patterns, middleware chains, error handlers, validation middleware |
| Data | Sequelize/Knex patterns, migration management, connection pooling |
| Testing | Supertest, Jest, integration test patterns |

For frameworks not listed above, use generic hints:
```markdown
## Conventions
# TODO: List your team's conventions for {domain}
# NOTE: Focus on YOUR project's specific conventions, not generic framework
# knowledge. Claude already knows general {framework} patterns.
```

**Polyglot projects:** Ask which language's framework to use for hints. Domain detection is directory-based and applies to all languages.

---

## Step 4b: Generate Agent Files

**Gate**: Skip if mode is `skills`.

For each selected domain, generate `.claude/agents/{domain}-{role}.md`.

### Pre-population Sources

| Section | Analysis Path | Fallback Path | Minimal Context |
|---------|---------------|---------------|-----------------|
| `name` | Domain-specific from analysis | Generic from `coding-workflows:stack-detection` table | Generic from `coding-workflows:stack-detection` table |
| `description` | Feature-specific with library names | Framework-level | Framework-level |
| `domains` | Analysis-detected keywords | `coding-workflows:stack-detection` domain keyword table | `coding-workflows:stack-detection` domain keyword table |
| `skills` | Confirmed/generated skills matching domain + existing plugin skills | Existing plugin skill references only | Existing plugin skill references only |
| Project Conventions | 2-3 observed patterns with file citations | TODO block | TODO block (current scaffolding) |
| Settled Decisions | From CLAUDE.md quotes only | TODO block | TODO block (current scaffolding) |
| Review Checklist | Domain-specific items from codebase patterns + research | Generic framework items | Generic items (current scaffolding) |
| Skills Referenced | Matching project + plugin skills (markdown section) | Plugin skill references only | Plugin skill references only |

**`skills:` population rules:**
- Only reference skills that were **confirmed and generated** in Step 4a, or that already exist (discovered in Step 2).
- Never reference proposed-but-declined skills.
- In `agents`-only mode: reference only already-existing skills. For absent skills that would be relevant, log a warning instead.
- Domain overlap matching: compare agent `domains` against skill `domains` to auto-populate.
- Universal skills: the following plugin skills are ALWAYS included in every
  generated agent's frontmatter `skills:`, regardless of role or domain. They
  shape fundamental agent behavior and cannot be inherited from parent context.
  - `plugin:coding-workflows:knowledge-freshness` (~1,273 tokens)
- Domain skills: skills matched by domain overlap (agent `domains` vs skill
  `domains`) are added to frontmatter `skills:` alongside universal skills.
  All matched skills go in frontmatter — there is no per-skill size threshold.
  Per-skill size thresholds were evaluated and removed: a per-skill gate
  (e.g., 2000 chars) is redundant when the aggregate budget check (below)
  already caps total injection. Individual skills that are too large would
  blow the aggregate budget naturally, making a separate per-skill check
  unnecessary. See `references/token-budgets.md` for full rationale.
- Context budget check: sum the token estimates of all frontmatter-listed skills
  (universal + domain). The recommended aggregate budget is ~5,000 tokens per
  agent. Universal skills consume a fixed baseline (~1,273 tokens currently),
  leaving ~3,727 tokens for domain-specific skills. If total exceeds ~5,000
  tokens, warn during Step 3 agent proposal:
  "Skills budget: ~{N} tokens ({count} skills).
   Baseline (universal): ~{U} tokens ({u_count} skills)
   Domain-specific: ~{D} tokens ({d_count} skills)
   Exceeds recommended ~5,000 token budget. Consider removing lower-priority
   domain skills from frontmatter."
  User may proceed or adjust the domain skills list. Universal skills cannot
  be removed.

  For rationale, measurement methodology, and adjustment guidance for these
  token budgets, see `coding-workflows:asset-discovery` skill's
  `references/token-budgets.md`. The canonical token estimate for each
  universal skill is maintained at its first occurrence in the universal
  skills list above (currently the `knowledge-freshness` bullet item).

TODOs only for: edge cases requiring human judgment, production-specific knowledge not visible in code, areas where research was declined.

### Evidence Citations

When pre-populating conventions, cite evidence:
- File paths: `src/billing/webhooks.py`
- Pattern coverage: `app/jobs/*.rb (12 files matching pattern)`
- Always include at least one concrete file path per convention -- never just counts

### Pre-Generation Checks

Before writing each file, apply the three-tier classification from the `coding-workflows:asset-discovery` skill:

1. **Cross-name detection:** When generating `{domain}-{role}.md`, check if other agents exist at `.claude/agents/{domain}-*.md` with a different role suffix. If found, flag:
   "Existing agent `{domain}-{old_role}.md` found. The new agent will be generated as `{domain}-{role}.md`. Consider renaming or removing the old file to avoid confusion."
   This is informational only -- do not auto-delete.

2. **Self-match with provenance branching:** If `.claude/agents/{name}.md` already exists at the exact output path:
   1. Read provenance fields (`generated_by`, `generated_at`) from existing file's frontmatter
   2. If generated: compare existing asset's `domains` array against current analysis domains for staleness (see `coding-workflows:asset-discovery` skill's Domain-Comparison Staleness Detection). Also compare existing asset's `tools` field against the **role-specific** template tools (from Role-Based Tool Sets table), using the agent's `role` field to select the correct template set (agents only, not skills -- see `coding-workflows:asset-discovery` skill's Tools-Comparison Staleness Detection). Also compare existing asset's `skills` array against the expected skills set (universal + domain-matched) for staleness (see `coding-workflows:asset-discovery` skill's Skills-Comparison Staleness Detection).
   3. Branch to appropriate UX:

   | # | State | UX |
   |---|-------|----|
   | 1 | Generated + stale | Show staleness summary (below). Suggest **Update** (default). Offer: Skip, Show full proposed content. |
   | 2 | Generated + current | "Asset is current (generated {date}). Skipping." |
   | 3 | Manually created | "Not generated by workflow commands. Skipping." (Informational: analysis notes if relevant, e.g., "analysis detected overlapping domains: X, Y") |

   **Error paths:**
   - Frontmatter unparseable: treat as manually created
   - `generated_by` present but `domains` array empty/missing: skip staleness detection, offer "Update or skip?"
   - `role` field absent: treat as `role: reviewer` (default) for comparison purposes
   - `tools` field absent: skip tools staleness (agent inherits all)
   - `tools` field empty string: treat as absent (skip tools staleness)
   - `tools` field is YAML list: normalize to set for comparison (same as comma-separated)
   - `skills` field absent: treat as stale (missing all expected skills)
   - `skills` field empty array: treat as stale (missing all expected skills)

   **Staleness summary format:**
   ```
   {filename} may need updating (generated {date}):

     New domains relevant to this asset:
     + {domain} (detected in {file_path}, {N} files)

     Domains no longer detected:
     - {domain} ({evidence})

     Framework changed:
     ~ {old} -> {new}

     Tools out of sync with current template:
     + {tool} (in template, missing from agent)
     - {tool} (in agent, not in current template)

     Skills drift:
       Missing universal skills:
       + {skill} (required by workflow — agent predates upgrade)
       Missing domain skills:
       + {skill} (matches agent domains — added since last generation)
       Dangling references:
       - {skill} (in agent, no longer resolves to any layer)
       User-added skills (informational):
       ~ {skill} (not in expected set — preserved)

     [Update / Skip / Show full proposed content]
   ```

   **Tools staleness notes:**
   - The `+` lines are actioned during update (added via set-union). The `-` lines are informational only (user-added tools are preserved, template-removed tools are flagged for user awareness).
   - Users may edit `tools` freely. Template removals do NOT automatically propagate to existing agents. See `coding-workflows:agent-patterns` for `tools` field semantics and `coding-workflows:asset-discovery` for staleness signal definitions.

   **Skills staleness notes:**
   - Missing universal skills (`+` lines under "Missing universal skills") indicate the agent was generated before a workflow upgrade introduced the universal skill. These are always actioned during update.
   - Missing domain skills (`+` lines under "Missing domain skills") indicate the project's skill inventory has grown since the agent was generated. These are actioned during update.
   - Dangling references (`-` lines) indicate skills that were removed or renamed since generation. These are removed during update.
   - User-added skills (`~` lines) are informational only and preserved during update.

   **Update behavior for tools:** When the "Update" action is chosen for a stale agent, tools are merged via set-union: `updated_tools = existing_tools | template_tools`. This adds missing template tools while preserving user-added tools. When a role change is detected (existing `role` differs from proposed `role`), merge tools via set-union of the new role's default tools and any user-added tools from the existing agent. User-added tools are those present in the existing agent but NOT in the old role's default tool set.

   **Update behavior for skills:** When the "Update" action is chosen for a stale agent, skills are updated as: `updated_skills = (existing_skills - dangling_refs) | universal_skills | domain_matched_skills`. This adds missing universal and domain skills, removes dangling references, and preserves user-added skills.

3. **BLOCK:** If exact name matches an existing agent in any layer, warn and offer rename.
4. **WARN:** If similarity threshold exceeded, confirm user's choice.
5. **Cross-type:** If keyword-bag overlap with an existing skill meets the threshold, note as informational (expected pattern for domain coverage).

### Role-Based Defaults

| Field | `reviewer` | `architect` | `specialist` |
|-------|------------|-------------|--------------|
| `model` | `sonnet` | *(omit)* | *(omit)* |
| `permissionMode` | `default` | `default` | `default` |
| `maxTurns` | `50` | `75` | *(omit)* |
| `color` | `blue` | `purple` | `green` |

Apply these defaults when generating agent frontmatter based on the agent's `role`.
Fields marked *(omit)* should NOT be written to the generated file -- omission
inherits the parent context's value (for `model`) or leaves the agent unbounded
(for `maxTurns`).

**`permissionMode` note:** All roles use `default` per the `coding-workflows:agent-patterns`
spec (line 93: "Recommended for reviewers"). Read-only enforcement for reviewer agents
is achieved through the `tools` field (see Role-Based Tool Sets), not through
`permissionMode`. The `plan` mode is reserved for planning/research agents, not reviewers.

**Role inference during Step 3 proposals:**
- Single domain with review focus -> `reviewer` (default)
- Cross-cutting or multi-domain -> `architect`
- Domain-specific implementation focus -> `specialist`
- Default when user doesn't specify -> `reviewer`

**Unknown role:** If `role` is not one of `specialist`, `reviewer`, or `architect`,
warn user ("Unknown role '{value}'. Valid values: specialist, reviewer, architect.
Defaulting to reviewer.") and apply `reviewer` defaults.

### Role-Based Tool Sets

| Role | `tools` value |
|------|---------------|
| `reviewer` | `Read, Grep, Glob, SendMessage, TaskUpdate, TaskList` |
| `architect` | `Read, Grep, Glob, Bash, SendMessage, TaskUpdate, TaskList` |
| `specialist` | `Read, Grep, Glob, Bash, Write, Edit, SendMessage, TaskUpdate, TaskList` |

**Trust boundary:** Reviewer agents intentionally omit `Bash`, `Write`, and `Edit`
to enforce read-only access. This is a trust boundary, not a convenience.
See `coding-workflows:agent-patterns` for tool configuration patterns.

### Agent Template

**Conditional field omission:** The `model` and `maxTurns` fields are only written when
the role-based default is NOT *(omit)*. When *(omit)*, omit the entire line from the
generated file (do not write the key at all). See the rendered examples below for
correct output per role.

```markdown
---
name: {domain}-{role}
description: "Reviews {domain} code for {framework} patterns and project conventions"
tools: {role_tools}
model: {role_model}
permissionMode: default
maxTurns: {role_maxTurns}
color: {role_color}
domains: [{domain keywords}]
# NOTE: skills listed here are fully injected into agent context at startup.
# This consumes context tokens (~5,000 token aggregate budget recommended).
# Universal skills (always included — do not remove):
#   - plugin:coding-workflows:knowledge-freshness (~1,273 tokens)
# Remaining budget (~3,727 tokens) is for domain-specific skills.
skills: [plugin:coding-workflows:knowledge-freshness, {matching domain skill names}]
role: {role}
generated_by: generate-assets
generated_at: "{YYYY-MM-DD}"
---

# {Domain} {Role_capitalized}

## Your Role
{role_description}

## Project Conventions
{analysis_path: 2-3 observed patterns with file path citations}
{fallback_path: TODO block with guidance comments}

## Settled Decisions
Decisions that are NOT up for debate:
{analysis_path: 1-2 decisions quoted from CLAUDE.md with citations}
{fallback_path: TODO block}

## Review Checklist
{analysis_path: domain-specific items from codebase patterns}
{fallback_path: generic items}
- [ ] Follows project naming conventions
- [ ] Error handling is consistent with project patterns
- [ ] Tests cover happy path and error cases
- [ ] No security issues (input validation, data exposure)

## Skills You Should Reference
The following skills provide relevant patterns (informational -- they are NOT
auto-injected unless also listed in frontmatter `skills:` above):
{analysis_path: matching project + plugin skills with brief context}
{fallback_path: matching plugin skills only}
```

**Rendered Examples (one per role):**

These examples show **frontmatter only** because the body structure (Your Role, Project Conventions, Settled Decisions, Review Checklist, Skills You Should Reference) is role-independent -- see the Agent Template above for the full body template. The frontmatter is what varies by role.

Reviewer (`api-reviewer.md`):
```yaml
---
name: api-reviewer
description: "Reviews API code for FastAPI patterns and project conventions"
tools: Read, Grep, Glob, SendMessage, TaskUpdate, TaskList
model: sonnet
permissionMode: default
maxTurns: 50
color: blue
domains: [api, routes, endpoints, http, middleware]
# Universal: knowledge-freshness (always included). Domain: api-patterns.
skills: [plugin:coding-workflows:knowledge-freshness, api-patterns]
role: reviewer
generated_by: generate-assets
generated_at: "2026-02-13"
---
```

Architect (`infra-architect.md`):
```yaml
---
name: infra-architect
description: "Reviews infrastructure code for deployment patterns and project conventions"
tools: Read, Grep, Glob, Bash, SendMessage, TaskUpdate, TaskList
permissionMode: default
maxTurns: 75
color: purple
domains: [deploy, ci, docker, infrastructure, config]
# Universal: knowledge-freshness (always included).
skills: [plugin:coding-workflows:knowledge-freshness]
role: architect
generated_by: generate-assets
generated_at: "2026-02-13"
---
```
Note: `model` line is absent (inherits from parent context).

Specialist (`billing-specialist.md`):
```yaml
---
name: billing-specialist
description: "Reviews billing code for Stripe patterns and project conventions"
tools: Read, Grep, Glob, Bash, Write, Edit, SendMessage, TaskUpdate, TaskList
permissionMode: default
color: green
domains: [billing, payments, stripe, webhooks]
# Universal: knowledge-freshness (always included). Domain: billing-patterns.
skills: [plugin:coding-workflows:knowledge-freshness, billing-patterns]
role: specialist
generated_by: generate-assets
generated_at: "2026-02-13"
---
```
Note: both `model` and `maxTurns` lines are absent.

**`tools` field note:** The `tools` field is role-dependent (see Role-Based Tool Sets table above). Reviewer agents are restricted to read-only tools as a trust boundary. Architect agents add `Bash` for shell execution. Specialist agents add `Bash`, `Write`, and `Edit` for full implementation capability. All roles include `SendMessage`, `TaskUpdate`, and `TaskList` for team coordination. See `coding-workflows:agent-patterns` for tool configuration patterns.

### Domain-Specific Keywords

| Domain | Example `domains` array |
|--------|------------------------|
| API | `[api, routes, endpoints, http, middleware, handlers]` |
| Storage | `[storage, database, schema, queries, migrations, models]` |
| Auth | `[auth, authentication, authorization, security, sessions]` |
| Business Logic | `[services, business-logic, use-cases, operations]` |
| Testing | `[testing, tdd, coverage, fixtures, mocks]` |
| Infrastructure | `[deploy, ci, docker, infrastructure, config]` |

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
{If skills generated:}
- .claude/skills/{domain1}/SKILL.md
- .claude/skills/{domain2}/SKILL.md
{If agents generated:}
- .claude/agents/{domain1}-{role}.md
- .claude/agents/{domain2}-{role}.md
{If review config generated:}
- .claude/review-config.yaml

All assets (discovered + generated):
Skills:
[List each discovered skill with source label: - [plugin:coding-workflows] {name} -- {description}]
[List each user-level skill: - [user] {name} -- {description}]
[List each project skill: - [project] {name} -- {description}]
Agents:
[List each discovered agent with source label: - [{layer}] {name} -- {description}]
[List each generated agent as: - [project] {name} -- {description}]

Next steps:
1. Review pre-populated conventions and settled decisions for accuracy
2. Fill in remaining TODO placeholders with your team's actual patterns
3. Commit the files: git add .claude/agents/ .claude/skills/
4. Reference skills from your agents' "Skills You Should Reference" section
5. Assets will be automatically discovered by workflow commands

Tip: Skills are the single source of truth for spec and framework rules.
Agents encode project-specific knowledge (how YOUR team works).
Agents reference skills -- they should never duplicate rule content.
```
