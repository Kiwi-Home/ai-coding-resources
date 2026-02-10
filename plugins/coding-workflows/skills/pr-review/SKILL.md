---
name: pr-review
description: |
  Framework for reviewing pull requests with severity-tiered findings,
  ecosystem-adapted focus areas, and strict exit criteria. Defines review
  principles, severity tiers, trivial check criteria, and the CREATE ISSUE
  protocol. Use when reviewing PRs from CLI or CI.
triggers:
  - reviewing pull request
  - pr review
  - code review
domains: [review, pr, quality, validation]
---

# PR Review Framework

Universal review knowledge for pull request evaluation. This skill encodes principles and decision frameworks — all procedural orchestration lives in the `review-pr` command.

## Severity Tiers

Every finding must be classified into exactly one tier. There is no "optional" or "informational" category.

| Tier | Label | Meaning | Merge Impact |
|------|-------|---------|-------------|
| MUST FIX | Blocks merge | Incorrect behavior, broken references, security issues, missing acceptance criteria | PR cannot merge |
| FIX NOW | Mandatory trivial fix | Small editorial fix that passes the Trivial Check below | PR cannot merge until fixed |
| CREATE ISSUE | Non-trivial, tracked | Valid concern requiring separate work; does not block merge once filed | PR can merge after issue is filed |

**Examples:**

| Finding | Tier | Rationale |
|---------|------|-----------|
| Broken cross-reference to a renamed skill | MUST FIX | Reference integrity failure |
| Security vulnerability (SQL injection, XSS) | MUST FIX | Security issue |
| Missing acceptance criterion from linked issue | MUST FIX | Spec non-compliance |
| Typo in a description | FIX NOW | Single-component, editorial, no semantic change |
| Wording improvement for clarity | FIX NOW | Editorial, same behavior |
| Partially implemented acceptance criterion | FIX NOW | Spec partial compliance |
| Refactor needed across multiple modules | CREATE ISSUE | Spans multiple components |
| New validation layer requiring its own design | CREATE ISSUE | Design-required |

---

## Trivial Check Decision Framework

Use this framework to classify findings as FIX NOW or CREATE ISSUE.

**FIX NOW when ALL true:**
- Change is contained within a single component
- No structural metadata changes (e.g., no frontmatter field additions/removals, no schema changes)
- No new cross-component references introduced
- No behavioral semantic changes
- Clearly editorial (typos, wording, formatting)

**CREATE ISSUE when ANY true:**
- Spans multiple components
- Changes structural metadata
- Changes behavioral logic or thresholds
- Introduces new cross-component references
- Modifies severity or exit criteria definitions

**Cross-ecosystem examples:**

| Finding | Context | Classification | Why |
|---------|---------|----------------|-----|
| Fix typo in skill description | Plugin content | FIX NOW | Single asset, editorial |
| Rename concept across commands and skills | Plugin content | CREATE ISSUE | Spans multiple assets |
| Fix incorrect type annotation | TypeScript | FIX NOW | Single file, no behavioral change |
| Add missing error handling across API routes | TypeScript | CREATE ISSUE | Spans multiple components |
| Fix mutable default argument | Python | FIX NOW | Single function, clear fix |
| Add type hints to all public APIs | Python | CREATE ISSUE | Spans multiple modules |

---

## Review Category Framework

Four universal category types define what to evaluate. Project-specific instantiations (what "correct" or "compliant" means for a particular codebase) come from `.claude/review-config.yaml` when available, or from general principles when not.

### 1. Correctness (default: MUST FIX)

Does the artifact produce intended behavior?

Without project config, evaluate:
- Do instructions match what will actually happen when executed?
- Are API calls syntactically correct with expected output?
- Do template/format blocks match what consumers parse for?
- Are descriptions accurate to the actual behavior?

**Bright-line rule:** Correctness applies when you can identify a SPECIFIC incorrect behavior that will result from the content as written. If the content is unclear but you cannot predict a specific wrong outcome, classify under Quality instead.

### 2. Integrity (default: MUST FIX)

Do references and contracts between components hold?

Without project config, evaluate:
- Do cross-references resolve to existing targets?
- Are import paths, API endpoints, or schema references valid?
- Do renamed or deleted items have updated references everywhere?
- Are interface contracts consistent between producers and consumers?

### 3. Compliance (default: FIX NOW)

Does it follow established conventions?

Without project config, evaluate:
- Does it follow patterns established elsewhere in the codebase?
- Is terminology consistent across changed files?
- Are naming conventions followed?

When project config exists, apply the specific conventions listed there.

### 4. Quality (severity via Trivial Check)

Is it clear, complete, and maintainable? This category is universal — it applies the same way across all ecosystems.

Evaluate:
- Logical ordering of sections and steps
- No contradictions between sections in the same file
- No ambiguous instructions with multiple interpretations
- Error and fallback paths defined for external service interactions

**Bright-line rule:** Quality applies when the content is unclear but you cannot predict a SPECIFIC incorrect outcome. If you can predict a specific wrong behavior, classify under Correctness instead.

---

## Iteration Mode Definitions

| Mode | Iterations | Scope |
|------|-----------|-------|
| COMPREHENSIVE | 1, 2, 3 | Apply all four categories. Raise every concern. |
| VERIFICATION | 4+ | Only verify previous MUST FIX items are fixed. Only flag regressions in newly changed lines. Do NOT raise new editorial concerns. |

**Threshold value: `3`** — this is the single source of truth. The `review-pr` command reads this value.

---

## Exit Criteria

Strict bright-line rules with no exceptions:

**"Ready to merge" ONLY when ALL true:**
- Zero MUST FIX items remain
- Zero FIX NOW items remain
- All CREATE ISSUE items have been filed in a consolidated issue

**If ANY items remain unresolved:**
> "Not ready to merge. [N] items remain: [list them]"

**Never use qualified approval language:**
- "Ready to merge once items are addressed" — NO
- "LGTM with minor changes" — NO
- "Approved pending X" — NO
- "Ready to merge with caveats" — NO

The ONLY valid approval is unqualified "Ready to merge" with zero blocking items.

---

## CREATE ISSUE Protocol

When a review contains CREATE ISSUE findings, exactly ONE consolidated issue is created per review.

**Label:** `review-followup`

**Issue body template:**
```markdown
## Overview
[1-2 sentences describing the overall theme across findings]

## Problem
[What's the common thread across these findings?]

## Requirements
[List all CREATE ISSUE findings as requirements — describe behaviors, not implementation]

## Acceptance Criteria
- [ ] [Measurable outcome per finding]

## Reference
- Found during review of PR #[PR_NUMBER]
```

**Rules:**
- ONE issue per review, not per finding
- Filing is mandatory — a review listing CREATE ISSUE findings without creating the issue is incomplete
- Reference the created issue number in the review comment
- If issue creation fails, note the failure in the review and list findings inline

---

## Issue Compliance Check Pattern

When a PR links to an issue (`Closes #N`, `Fixes #N`, `Resolves #N`):

1. Fetch the issue body
2. Extract acceptance criteria
3. Verify each criterion is addressed in the PR changes

| Status | Classification |
|--------|---------------|
| Missing (not addressed at all) | MUST FIX |
| Partial (partially addressed) | FIX NOW |
| Implemented | No finding |

If no linked issue exists, skip the compliance check with a note.
If issue fetch fails, skip with a note.
In VERIFICATION mode, skip entirely (only needed in COMPREHENSIVE).

---

## File-Status Reference Table

| Status | Meaning | Review Action |
|--------|---------|---------------|
| Deleted | All lines removed or file not found | Skip content review; check for orphaned references |
| Renamed | Rename markers in diff | Review at new path; verify references updated |
| Binary | Non-text content | Skip content review; note in output |
| Added/Modified | New or changed content | Read full file; apply all review categories |

---

## Review Config Schema

Project-specific review focus is generated per-repo via `/coding-workflows:generate-assets review-config` and stored in `.claude/review-config.yaml`. When this file exists, the `review-pr` command uses it to adapt the universal framework to the project's specific concerns.

```yaml
# Generated by /coding-workflows:generate-assets review-config
# Project-specific review focus for use with /coding-workflows:review-pr
generated_by: generate-assets
generated_at: "YYYY-MM-DD"

# What "correct" means in this project
correctness:
  - "Description of what correctness means here"

# What references and contracts to verify
integrity:
  - "Description of what references matter here"

# What conventions to enforce
compliance:
  - "Description of what conventions apply here"

# Project-specific anti-patterns to watch for
anti_patterns:
  - name: "Anti-pattern name"
    description: "What it is and why it's problematic"
    detection: "How to spot it during review"
```

**Without this file:** The `review-pr` command applies only the universal framework defined in this skill. The review is less targeted but still functional — severity tiers, exit criteria, and the trivial check all apply universally.

---

## Cross-References

- `coding-workflows:stack-detection` — ecosystem detection for project context resolution
- `coding-workflows:issue-writer` — issue creation patterns (used by CREATE ISSUE protocol)
- `coding-workflows:issue-workflow` — follow-up issue threshold (for deferred work tracking in reviewed PRs)
- Plugin-validation skill — structural validation (this skill does NOT duplicate frontmatter or naming validation)
