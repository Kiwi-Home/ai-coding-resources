---
name: asset-discovery
description: |
  Discovers existing skills and agents across project, user, and plugin layers
  and provides similarity heuristics for detecting overlapping assets. Used by
  setup and generator commands to prevent duplicate scaffolding.
triggers:
  - generating skills
  - generating agents
  - detecting duplicate assets
  - checking for name collisions
domains: [discovery, similarity, assets, duplicates]
---

# Asset Discovery

## When to Use

Reference this skill before creating skills or agents. The unified generator command (`/coding-workflows:generate-assets`) and the `/coding-workflows:setup` command consult these tables to detect existing assets and flag potential duplicates before scaffolding.

### Legacy Provenance Mapping

All `generated_by` values across versions map to the current generator. All values classify as "generated" for provenance purposes.

| Legacy Value | Era | Current Equivalent |
|-------------|-----|-------------------|
| `workflow-generate-agents` | pre-v3 | `generate-assets` |
| `workflow-generate-skills` | pre-v3 | `generate-assets` |
| `workflow-setup` | pre-v3 | `generate-assets` |
| `generate-agents` | v3 | `generate-assets` |
| `generate-skills` | v3 | `generate-assets` |
| `setup` | v3+ | `generate-assets` (when setup invokes generation internally) |
| `generate-assets` | v4+ | *(current)* |

## Discovery Locations

Scan these locations for existing assets. Skip any layer whose directory does not exist.

| Layer | Skills | Agents |
|-------|--------|--------|
| Project | `.claude/skills/*/SKILL.md` | `.claude/agents/*.md` |
| User | `~/.claude/skills/*/SKILL.md` | `~/.claude/agents/*.md` |
| Plugin | `plugins/*/skills/*/SKILL.md` | *(none currently bundled)* |

For each discovered asset, read its YAML frontmatter and extract `name`, `description`, `domains`, `generated_by`, and `generated_at`.

**Presentation order:** Group by type (skills, then agents). Within each type, sort by layer (project, user, plugin). Within each layer, sort alphabetically by name.

**Source labels:** Tag each discovered asset with its origin: `[project]`, `[user]`, `[plugin:{name}]`.

If a discovery layer is inaccessible (missing directory, permissions error), warn once and continue with results from accessible layers. Warn more prominently for project-level failures.

### Provenance Classification

Classify each discovered asset's provenance state based on frontmatter fields (see `coding-workflows:agent-patterns` for field definitions):

| State | Detection | Default Action |
|-------|-----------|----------------|
| **Generated** | Has `generated_by` field | Suggest "Update" if stale, "Skip" if current (user always confirms) |
| **Manually created** | No `generated_by` field | Inform only (never offer overwrite) |

**Edge case rules:**
- Unparseable frontmatter: classify as "manually created" (existing fallback behavior)
- `generated_by` present with unrecognized value: still classify as "generated" (informational, not validated)

**Provenance tags in discovery output:** Show `[generated]` or `[manual]` tags for `[project]`-layer assets only. User-layer and plugin-layer assets show without provenance tags.

### Domain-Comparison Staleness Detection

When a self-match is detected for a generated asset, compare the asset's `domains` array from frontmatter against the current analysis output's detected domains for that domain area:

```
Staleness signals (compare per-asset):
- New domains in analysis not in asset's `domains` array → stale
- Domains in asset's `domains` array no longer detected → stale
- Framework change since `generated_at` date → stale
- All domains still present and no new ones → current
```

This is asset-level comparison, not project-level. Each asset is evaluated against its own domain coverage. See `coding-workflows:codebase-analysis` for what constitutes meaningful staleness.

**Note on computation:** This staleness detection requires only comparing arrays and strings -- no cryptographic hashing. The LLM compares the asset's `domains` frontmatter against the domain list from the analysis output.

### Provenance Summary

After the discovery table, present a provenance summary:

```
Provenance summary:
- N agents: X generated (Y stale), Z manual
- N skills: X generated (Y stale), Z manual
```

## Keyword-Bag Construction

Build a keyword bag for each asset from three sources:

1. **Name:** Split on hyphens. Exclude structural suffixes: `patterns`, `conventions`, `reviewer`, `specialist`, `architect`.
2. **Domains:** Array items as-is. If `domains` is empty or missing, this source contributes nothing.
3. **Description:** Split on whitespace, lowercase. Remove stop words: `the`, `a`, `an`, `for`, `and`, `or`, `with`, `to`, `from`, `that`, `this`, `which`, `is`, `are`, `was`, `were`, `be`, `been`, `use`, `when`, `how`.

The keyword bag is the union of all three sources (deduplicated, lowercased).

**Worked example:** `stack-patterns` (proposed) vs `coding-workflows:stack-detection` [plugin:coding-workflows] (existing)

| Source | `stack-patterns` | `coding-workflows:stack-detection` |
|--------|------------------|-------------------|
| Name (minus suffixes) | `stack` | `stack`, `detection` |
| Domains | `[stack, technology]` | `[detection, stack, technology, languages]` |
| Description keywords | `stack`, `conventions`, `projects`, `reviewing`, `code` | `discovers`, `technology`, `stack`, `detection`, `reference`, `tables` |
| **Keyword bag** | `{stack, technology, conventions, projects, reviewing, code}` (6) | `{stack, detection, technology, languages, discovers, reference, tables}` (7) |

Intersection: `{stack, technology}` = 2. Overlap ratio: 2 / min(6, 7) = 0.33 → **IGNORE** (below 0.4). However, if descriptions share more vocabulary, the ratio rises — the threshold is tuned for real-world descriptions, not minimal examples.

## Three-Tier Classification

| Tier | Condition | Action |
|------|-----------|--------|
| **BLOCK** | Exact `name` match in any layer (same type or cross-type) | Must rename or skip. Refuse to generate. |
| **WARN** | Keyword-bag overlap ratio >= 0.4 | Present overlap evidence, offer: skip / rename / generate anyway. For generated assets, also offer: re-generate. |
| **IGNORE** | Below 0.4 threshold | No action. |

**Overlap ratio:** `|intersection| / min(|A|, |B|)` where A and B are the keyword bags of the proposed and existing assets. This is more robust than Jaccard for bags of different sizes -- a small bag fully contained in a larger bag scores 1.0.

**Cross-type matching** (skills vs agents): Same keyword-bag approach, same 0.4 threshold. A skill and agent covering the same domain is a valid pattern (e.g., `api-patterns` skill + `api-reviewer` agent). Only flag when keyword-bag overlap is genuinely high, and present as informational rather than a collision.

## Self-Match Rule

When the proposed output path matches an existing asset's path exactly, this is a **self-match** (an update, not a duplicate). Always apply the self-match check before any collision check.

For self-matches, check the existing asset's provenance state and branch accordingly:

| # | State | UX |
|---|-------|----|
| 1 | Generated + stale | Show domain-comparison staleness summary with evidence. Suggest **Update** (default). Offer: Skip, Show full proposed content. |
| 2 | Generated + current | "Asset is current (generated {date}). Skipping." |
| 3 | Manually created | "Not generated by workflow commands. Skipping." (Informational: analysis notes if relevant, e.g., "analysis detected overlapping domains: X, Y") |

**Error paths:**
- Frontmatter unparseable: treat as manually created
- `generated_by` present but `domains` array empty/missing: skip staleness detection, offer "Update or skip?" (original self-match behavior)

## Frontmatter Parse Failures

Assets without parseable YAML frontmatter:
- **Identity fallback:** Use parent directory name for skills (e.g., `api-patterns` from `.claude/skills/api-patterns/SKILL.md`), file stem for agents (e.g., `api-reviewer` from `.claude/agents/api-reviewer.md`).
- **Keyword comparison:** Include in exact-name matching only. Exclude from keyword-bag overlap (no `domains` or `description` to extract).

## True/False Positive Examples

| Proposed | Existing | Type Match | Result | Why |
|----------|----------|------------|--------|-----|
| `stack-patterns` | `coding-workflows:stack-detection` [plugin:coding-workflows] | same (skill) | **WARN** | Keyword bags share `stack` via name; descriptions likely share `technology`/`detection` |
| `db-patterns` | `data-patterns` [project] | same (skill) | **WARN** | Descriptions both mention `database`/`data`; name-only heuristic would miss this |
| `issue-writer` | `coding-workflows:issue-workflow` [plugin:coding-workflows] | same (skill) | **IGNORE** | Despite shared `issue` prefix, domains differ (`requirements` vs `planning,execution`) and descriptions diverge |
| `api-patterns` | `api-reviewer` [project] | cross (skill vs agent) | **WARN** | Keyword bags share `api` + domain keywords; flagged as informational (valid pairing) |
| `auth-patterns` | `testing-patterns` [project] | same (skill) | **IGNORE** | Only structural suffix `patterns` overlaps (excluded from bag); no keyword overlap |

## Validation Checklist

For command implementers referencing this skill — verify these when integrating discovery into a generator command:

- [ ] Frontmatter parsed successfully from discovered asset (or fallback applied)
- [ ] Self-match check applied before collision check
- [ ] Same-type vs cross-type distinction noted in output
- [ ] Source layer label attached to each discovered asset
- [ ] User presented with concrete keyword overlap evidence (not numeric scores)
- [ ] Inaccessible layers warned, not failed
- [ ] Provenance state shown for project-layer assets
- [ ] Domain-comparison staleness evaluated for generated self-matches
- [ ] Reference integrity: agent `skills` frontmatter entries resolve to existing skills (project, user, or plugin layer). Unresolvable auto-populated refs are removed; unresolvable user-specified refs produce a warning. Dangling `skills` references are an additional staleness signal.

## Related Skills

- `coding-workflows:agent-patterns` -- Defines the agent frontmatter spec (`name`, `domains`, `role`) and provenance fields (`generated_by`, `generated_at`) that this skill reads during discovery. Reference for understanding what fields are available on discovered agents.
- `coding-workflows:codebase-analysis` -- Defines staleness evaluation criteria (what domain/framework changes constitute meaningful staleness). Referenced during domain-comparison staleness detection.
