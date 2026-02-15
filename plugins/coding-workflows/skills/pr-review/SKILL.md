---
name: pr-review
description: |
  Framework for reviewing pull requests with severity-tiered findings,
  ecosystem-adapted focus areas, and strict exit criteria. Defines review
  principles, severity tiers, finding disposition framework, and the CREATE
  ISSUE protocol. Use when reviewing PRs from CLI or CI.
domains: [review, pr, quality, validation]
---

# PR Review Framework

Universal review knowledge for pull request evaluation. This skill encodes principles and decision frameworks — all procedural orchestration lives in the `review-pr` command.

## Severity Tiers

Every finding must be classified into exactly one tier. There is no "optional" or "informational" category.

| Tier | Label | Meaning | Merge Impact |
|------|-------|---------|-------------|
| MUST FIX | Blocks merge | Incorrect behavior, broken references, security issues, missing acceptance criteria | PR cannot merge |
| FIX NOW | Mandatory fix, inline | Fix that can be made within the current PR per the Finding Disposition Framework below | PR cannot merge until fixed |
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

## Finding Disposition Framework

After classifying findings by review category, apply this framework to assign the final severity tier (FIX NOW vs CREATE ISSUE). This framework replaces any binary trivial/non-trivial classification with a disposition-first approach.

### Inline-First Principle

**When in doubt, classify as FIX NOW, not CREATE ISSUE.** The cost of a small inline fix is lower than the overhead of tracking a separate issue. Err on the side of fixing in the current PR.

### Disposition Pre-Filter

Before assigning FIX NOW or CREATE ISSUE, ask:

> **Can the PR author fix this within the current PR without expanding the PR's scope?**

- **YES** → **FIX NOW** (regardless of whether it touches multiple files already in the diff)
- **NO** → Proceed to the CREATE ISSUE gate below

"Expanding scope" means requiring changes to files not already in the PR diff, or requiring new design decisions or architectural changes beyond the PR's stated objective.

### FIX NOW Criteria

Classify as FIX NOW when the fix:
- Is contained within files already in the PR diff
- Does not require new design decisions or architectural changes
- Does not expand the PR's scope to untouched modules

### CREATE ISSUE Gate (ALL must be true)

A finding becomes CREATE ISSUE **only when ALL four conditions are true**:

1. **Too large for inline fix** — cannot be resolved within the current PR's file scope without significantly expanding the diff
2. **Too important to ignore** — the finding has real impact on correctness, security, or maintainability (not just stylistic preference)
3. **Clearly valid** — passes the Finding Validation Gate (below)
4. **Genuinely out of scope** — addresses concerns beyond the PR's stated objective

If ANY condition is false, the finding is either **FIX NOW** (conditions 1 or 4 are false) or **dropped** (conditions 2 or 3 are false).

### Cross-Ecosystem Examples

| Finding | Context | Classification | Why |
|---------|---------|----------------|-----|
| Fix typo in skill description | Plugin content | FIX NOW | Editorial, fixable inline |
| Rename concept across commands and skills | Plugin content | CREATE ISSUE | All 4: too large (spans many files), important, valid, out of scope |
| Fix incorrect type annotation | TypeScript | FIX NOW | Single file already in diff |
| Add missing error handling across API routes | TypeScript | CREATE ISSUE | All 4: spans untouched files, important, valid, out of scope |
| Fix mutable default argument | Python | FIX NOW | Single function, clear fix |
| Add type hints to all public APIs | Python | CREATE ISSUE | All 4: spans untouched modules, important, valid, out of scope |
| Fix logic error in touched function | Any | FIX NOW | File already in diff, no scope expansion |
| Add input validation to 3 files in diff | Any | FIX NOW | All files already in diff, no new design needed |
| Add input validation to 3 untouched files | Any | CREATE ISSUE | All 4: expands scope, important, valid, out of scope |

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

### 4. Quality (severity via Finding Disposition Framework)

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

> **Note:** This skill defines the review verdict. CI status is a separate,
> prerequisite signal -- not a substitute for review approval. See the CI/Review
> Conflation anti-pattern in `coding-workflows:issue-workflow` for the Two
> Distinct Signals model.

---

## CREATE ISSUE Protocol

When a review contains CREATE ISSUE findings, exactly ONE consolidated issue is created per PR.

**Sequencing rule:** ALL findings must be fully collected and classified BEFORE any issue is created. Do NOT create issues as you discover findings. Issue creation is a single batch operation that happens after the review is complete.

**Cross-iteration rule:** ONE issue per PR, not per iteration. Before creating a new issue:
1. Query for existing `review-followup` issues referencing this PR:
   ```bash
   gh issue list --repo {org}/{repo} --label review-followup --state open --search "PR #{pr_number}" --json number,title,body
   ```
2. If a matching issue exists (body contains `PR #[pr_number]`): append new findings as a comment on the existing issue. Do NOT create a second issue.
3. If no matching issue exists: create one using the template below.
4. If the query fails (non-zero exit after retry): skip dedup and create the issue directly using the template below. Add note in the issue body: "Created without dedup verification — may duplicate an existing follow-up issue for this PR." This ensures findings are always tracked in an issue, even when dedup is unavailable.

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
- ONE issue per PR, not per finding, not per iteration
- Do NOT create issues during the review phase — collect all findings first
- Filing is mandatory — a review listing CREATE ISSUE findings without creating the issue is incomplete
- Reference the created issue number (new or existing) in the review comment
- If issue creation fails, note the failure in the review and list findings inline

---

## Finding Validation Gate

Before a finding can be classified as CREATE ISSUE, it must pass validation:

- [ ] Not already addressed in the PR (check the diff, not just the finding description)
- [ ] Not a misunderstanding of an established pattern (check existing codebase for precedent)
- [ ] Genuinely out of scope for the current PR (not fixable with a small edit to files already in the diff)

Findings that fail validation are dropped — they are not findings.

---

## Anti-Patterns

### Issue Sprawl
Creating multiple follow-up issues from a single review or across iterations of the same PR. ONE issue per PR, consolidated. If a follow-up issue already exists, append to it.

### Mid-Review Issue Creation
Creating issues as findings are discovered rather than batching at the end. All findings must be collected and classified before any issue creation.

### Inline Finding Orphaning
Listing CREATE ISSUE findings inline in the review comment instead of creating a tracked issue when a fallback path is available. Inline findings create a signal gap — subsequent iterations cannot distinguish them from normal review prose, and they are not considered "filed" for exit criteria purposes. Always prefer creating a tracked issue, even at the cost of potential duplication.

### Review-Scope Creep
Requesting inline fixes that expand the PR beyond its original scope. If fixing a finding would require changes to files not already in the diff or introduce new architectural decisions, classify as CREATE ISSUE rather than FIX NOW.

**Examples:**

| Scenario | Classification | Why |
|----------|----------------|-----|
| "This function in `auth.py` should also validate tokens" on a PR that only touches `user.py` | CREATE ISSUE | `auth.py` is not in the diff — fixing expands scope |
| "Add error handling for this new API endpoint" on a PR that adds the endpoint | FIX NOW | File is already in the diff, no scope expansion |
| "Refactor this module to use the strategy pattern" on a bug-fix PR | CREATE ISSUE | Architectural change beyond the PR's objective |
| "Fix the off-by-one error in the loop you added" on the same PR | FIX NOW | Direct fix to code already in the diff |

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

See `references/review-config-schema.md` for the full YAML schema. Read it when generating or editing `.claude/review-config.yaml`.

**Without this file:** The `review-pr` command applies only the universal framework defined in this skill. The review is less targeted but still functional — severity tiers, exit criteria, and the finding disposition framework all apply universally.

---

## Cross-References

- `coding-workflows:stack-detection` -- ecosystem detection for project context resolution
- `coding-workflows:issue-writer` -- issue creation patterns (used by CREATE ISSUE protocol)
- `coding-workflows:issue-workflow` -- follow-up issue threshold (deferred work tracking); CI/Review Conflation anti-pattern (CI pass is prerequisite, not substitute for review approval)
- Plugin-validation skill -- structural validation (this skill does NOT duplicate frontmatter or naming validation)
