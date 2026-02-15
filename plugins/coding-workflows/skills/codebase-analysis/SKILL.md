---
name: codebase-analysis
description: |
  Criteria for analyzing codebases to inform agent and skill generation.
  Encodes signal hierarchy, specialist indicators, and domain significance evaluation.
  Use when: generating agents, generating skills, or evaluating project setup.
domains: [analysis, generation, patterns, domain-identification]
---

# Codebase Analysis

## Purpose

Criteria for understanding a project's domain, patterns, and conventions before proposing agents or skills. This skill teaches what makes a good analysis, not how to perform one step-by-step.

**Boundary with stack-detection**: Stack-detection answers WHAT technologies exist. Codebase-analysis evaluates HOW they're used and WHETHER they warrant specialists.

**Related skills**:
- `coding-workflows:stack-detection` -- Technology identification (WHAT). Reference its Analysis Guidance section for per-stack deep analysis criteria
- `coding-workflows:asset-discovery` -- Overlap detection and provenance-aware discovery. Check BEFORE proposing new agents/skills
- `coding-workflows:agent-patterns` -- Agent metadata spec (name, domains, role) and provenance fields. For formatting proposals
Naming constraints for agent names are documented in project-level validation skills when available.

---

## Signal Hierarchy

What's high-signal vs low-signal when building a project mental model:

**High-signal**: Project identity docs reveal intent and settled decisions.
- CLAUDE.md is the single source of truth for conventions. Definitive language is appropriate when quoting it.
- README.md reveals project purpose, architecture overview, and intended usage.
- These are always read when present, even if not listed in `planning.reference_docs` (documented in workflow.yaml).

**Medium-signal**: Existing assets reveal what's already covered.
- Agents in `.claude/agents/` show what domains have specialist coverage.
- Skills in `.claude/skills/` and plugin skills show what patterns are encoded.
- `planning.reference_docs` from workflow.yaml lists additional project docs worth reading.

**Lower-signal**: Code structure validates or contradicts stated intent.
- Package manifests reveal specialized libraries (potential unfamiliarity flags).
- Directory structure suggests domain boundaries, but must be validated against actual code.

**Missing file handling**: If a reference_doc is listed but missing, warn user and continue. If CLAUDE.md is absent, note "limited convention context" in analysis output.

---

## File Sampling Criteria

How to select representative source files for deeper analysis:

- **Entry points** (main.py, app.js, main.go, config/routes.rb) -- reveal application architecture
- **High import count modules** -- central to the application, many dependents
- **Domain-keyword files** -- files in paths matching domain terms (api/, billing/, auth/)
- **Recently active files** -- via git history, where current development is focused
- 2-3 files per detected domain is sufficient; don't read the entire codebase

---

## Specialist Indicators

Codebase signals that suggest an agent or skill is warranted. Each includes a counter-example and validation criterion to prevent false positives.

### Agent Indicators

| Signal | Suggests | Counter-Example | Validation |
|--------|----------|-----------------|------------|
| Background job dir (jobs/, workers/) with multiple classes | Async/queue specialist | Single job class -- not enough complexity | Count job files; 3+ suggests specialist |
| Payment models + service objects | Payments specialist | Test fixtures referencing Stripe -- not real usage | Grep for payment processing in services, not just models |
| ML model dirs, training scripts | ML specialist | Pre-trained model loaded but never fine-tuned | Check for training config or custom training code |
| Custom middleware directory | API/middleware specialist | Single logging middleware file | Count middleware files; 2+ custom middleware suggests specialist |
| Multi-service integration layer | Integration specialist | Single external API call wrapped in a service | Count distinct external service integrations; 3+ suggests specialist |

### Skill Indicators

| Signal | Suggests | Counter-Example | Validation |
|--------|----------|-----------------|------------|
| Consistent error handling across 5+ modules | Error handling patterns skill | All using framework defaults | Grep for custom exception classes or result wrappers |
| Standardized API response format | API conventions skill | Single controller with format | Check 3+ controllers for same pattern |
| Shared test utilities and custom assertions | Testing patterns skill | Standard framework test helpers only | Look for project-specific test base classes or helpers |
| Custom validation layer | Validation patterns skill | Framework's built-in validators only | Check for custom validator classes or validation modules |

---

## Domain Significance Evaluation

A domain warrants a specialist agent or skill when it matters, not just when it exists. Evaluate on these criteria:

- **Integration breadth**: How many modules touch this domain? (1-2 = incidental, 3+ = significant)
- **Risk profile**: Does failure cause data loss, security issues, or financial impact?
- **Complexity signals**: Custom abstractions, multi-step workflows, external service integrations
- **Active development**: Is this domain actively changing? (git log frequency signal)

**Threshold**: A domain warrants a specialist agent if it scores on 2+ of these criteria. A single criterion is insufficient -- a high-risk module touched by one file is better served by documentation than an agent.

---

## Convention Discovery

What to extract from CLAUDE.md and code as pre-population material for agents and skills:

- **Naming conventions**: File naming, function naming, variable naming patterns observed in code
- **Error handling patterns**: Custom exceptions, result types, error codes, response formats
- **Testing conventions**: Framework choice, fixture patterns, coverage expectations, test organization
- **Code organization**: Feature-based vs layer-based, module boundaries, import conventions

**Language guidance**: Use "appears to", "observed in N files" for code-derived conventions. Reserve definitive language for CLAUDE.md quotes and explicit config values. This prevents hallucinated conventions from being treated as authoritative.

---

## Research Triggers

Indicators for when web search is warranted during analysis:

- **Novel signal**: Library whose purpose you cannot explain in one sentence without guessing
- **Version signal**: Installed version significantly newer than familiar patterns suggest
- **Domain signal**: Niche terminology in source files (LoRA, MQTT, HL7, FIX protocol, DICOM)
- **Ecosystem signal**: Pre-1.0 frameworks or recent major version releases with breaking changes

**Anti-pattern**: Don't research well-established frameworks (React, Rails, Django), standard library usage, or generic patterns (REST, CRUD, MVC).

**Prioritization** (when flags exceed search budget): direct dependency > usage frequency in sampled files > domain criticality (auth/payments > logging/metrics).

---

## When Analysis Is Premature

Conditions where deeper analysis won't help -- fall back to `coding-workflows:stack-detection` declarative tables:

- No CLAUDE.md AND no README AND fewer than 5 source files
- Config-only repo with no application code
- Single-file project (no domain boundaries to specialize)
- Analysis completes but produces 0 domains (empty or trivial codebase)

When falling back, present to the user: "Using stack detection (limited project context available)."

---

## Analysis Deliverable Characteristics

Quality criteria for analysis output consumed by generator commands.

**Minimum viable analysis**: 2+ domains with file path evidence. If fewer domains found, fall back to `coding-workflows:stack-detection`. If domains found but no conventions, flag: "Limited context -- recommend adding CLAUDE.md."

**Good analysis includes**:
- Detected domains with file path evidence (e.g., `src/billing/webhooks.py`, `app/jobs/*.rb (12 files)`)
- Conventions observed with citations -- at least one concrete file path per convention, never just counts
- Unfamiliarity flags: library/domain name, reason (novel/version/domain signal), usage evidence (file count + key file)
- Coverage gaps: which domains lack agents or skills

**Note:** When generating both asset types in a single pass (via `/coding-workflows:generate-assets`), run analysis once and extract both deliverable sets.

See `references/generation-deliverables.md` for generator-specific deliverable requirements. Read it when running `/coding-workflows:generate-assets` to understand what the generation phase needs from analysis.

---

## Staleness Detection

What constitutes meaningful staleness when comparing current analysis against an existing generated asset (see `coding-workflows:agent-patterns` for provenance field definitions):

| Change | Stale? | Rationale |
|--------|--------|-----------|
| New domain detected that overlaps asset's coverage area | Yes | May warrant expanding asset's domains or content |
| Domain in asset's `domains` array no longer detected | Yes | Asset covers removed domain |
| Framework change | Yes | Fundamental shift in what assets need to know |
| New convention observed | No | Refines existing assets, doesn't invalidate them |
| New library detected | No (usually) | Within-domain change |
| File count changes within a domain | No | Quantity is noise |

Staleness is evaluated per-asset by comparing the asset's `domains` array against current analysis domains. A project gaining a new domain does not make existing assets stale unless the new domain overlaps with their coverage area.

---

## Anti-Patterns

| Anti-Pattern | Why It's Wrong | Do This Instead |
|--------------|----------------|-----------------|
| Count files to determine importance | 3 files could be high-value or trivial | Assess integration breadth, risk, active development |
| Assume framework = domain | Misses application-specific complexity | Read business logic, not just framework boilerplate |
| Generate for unused features | Detected library does not equal active domain | Validate usage count via grep |
| Duplicate CLAUDE.md into agents | Creates maintenance burden and drift | Reference CLAUDE.md, don't copy it |
| Skip reading existing assets | Leads to duplicate agents/skills | Always check `coding-workflows:asset-discovery` before proposing |
| Claim confidence without evidence | LLM hallucination risk | Cite file paths for every convention claimed |
| Research everything | Wastes search budget on known frameworks | Only research genuinely unfamiliar libraries/domains |

---

## Related Skills

- `coding-workflows:stack-detection` -- Technology identification (WHAT exists). Reference its Analysis Guidance section for per-stack deep analysis criteria
- `coding-workflows:asset-discovery` -- Overlap detection and provenance-aware discovery. Check BEFORE proposing new agents/skills. References this skill's staleness criteria during domain-comparison staleness detection.
- `coding-workflows:agent-patterns` -- Agent metadata spec (name, domains, role, skills) and provenance fields (generated_by, generated_at). For formatting proposals and staleness detection
Naming constraints for agent names are documented in project-level validation skills when available.
- `coding-workflows:knowledge-freshness` -- staleness triage for evaluating when training data is reliable
