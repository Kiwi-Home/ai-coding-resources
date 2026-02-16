---
name: refactoring-patterns
description: |
  Safe refactoring patterns for AI-assisted development. Covers refactoring
  triggers, AI-specific anti-patterns (additive-only changes, wrapper inflation,
  dead code accumulation) with corrective annotations, size-check heuristics,
  and verification criteria. Use when: planning refactoring work, reviewing code
  for structural improvements, addressing tech debt during execution, or
  evaluating whether a change qualifies as refactoring vs. new feature work.
domains: [refactoring, quality, technical-debt, code-health]
user-invocable: false
---

# Refactoring Patterns

Safe refactoring knowledge for AI-assisted development. Fills the gap between **problem identification** (anti-pattern catalogs in `issue-workflow` and `ai-coding-knowledge`) and **remediation guidance** (this skill). Content is language/framework-agnostic and framed as signals and decision criteria, not procedures.

## Activation Criteria

This skill activates when consuming commands encounter refactoring-relevant signals.

| Consuming Command | Trigger Condition |
|-------------------|-------------------|
| `execute-issue` | During REFACTOR step of TDD loop; when file exceeds size-check thresholds |
| `review-pr` | When PR contains structural changes, file size growth, or wrapper additions |
| `plan-issue` | When issue involves refactoring, tech debt reduction, or code health |
| `design-session` | When discussing refactoring approaches or code structure improvements |

**Activation signal**: Any size-check heuristic threshold exceeded, OR issue/PR explicitly mentions refactoring, tech debt, or code cleanup.

---

## Refactoring Triggers

Signals that indicate refactoring should be investigated. Exceeding a trigger means "look closer," not "refactor now."

| Trigger | Signal | AI-Specific Note |
|---------|--------|-------------------|
| Duplication above threshold | 3+ near-identical code blocks | Claude tends to copy-paste rather than extract shared logic |
| Mixed responsibilities | Single function/file handles multiple unrelated concerns | Claude adds new concerns to existing files rather than creating focused modules |
| Wrapper without logic | Function delegates to another without transformation or error handling | Claude adds "thin wrapper" layers for flexibility that never materializes |
| Layered additions | New implementation exists alongside old, unreferenced implementation | Claude avoids modifying existing code, preferring to build alongside it |
| Growing parameter lists | Functions accumulate parameters over successive changes | Claude adds parameters instead of introducing option objects or builders |
| Deep nesting | Conditional logic exceeds 3 levels of nesting | Claude adds conditions incrementally without restructuring |

---

## Safe Refactoring Patterns

**Do not describe the mechanical steps of each refactoring.** Claude knows how to extract functions, inline wrappers, and consolidate duplicates. This section encodes ONLY the decision criteria for when each pattern is warranted and the verification criteria that prove the refactoring is safe.

| Pattern | When to Apply | What to Verify | Risk Level |
|---------|--------------|----------------|------------|
| Extract function | Single function handles 2+ distinct responsibilities; body exceeds size heuristic | Extracted function is called from original site; all tests pass; no behavior change | Low |
| Inline redundant wrapper | Wrapper delegates without adding logic, error handling, or type transformation | All callers updated to use target directly; wrapper removed (not left in place); tests pass | Low |
| Consolidate duplicates | 3+ near-identical blocks with differences expressible as parameters | Shared function covers all variants; original call sites updated; edge cases in variants tested | Medium |
| Simplify conditional | Nested if/else chain expressible as early returns, guard clauses, or lookup table | All branches produce identical results before and after; boundary cases tested | Medium |
| Flatten nesting | Logic nested >3 levels deep without inherent structural reason | Early returns reduce nesting; readability improves without changing control flow | Low |
| Remove dead code | Code unreachable, unreferenced, or commented out | Grep confirms zero references; removal does not break compilation or tests | Low |

---

## AI-Specific Anti-Patterns

Core differentiating section. Each anti-pattern includes a **Corrective** annotation explaining _why Claude defaults to this behavior_ -- without this context, patterns read as generic advice rather than targeted interventions.

### Additive-Only Changes

**Corrective**: Claude avoids modifying existing code to minimize regression risk, defaulting to layering new code alongside old.

| Aspect | Detail |
|--------|--------|
| Signal | New implementation exists alongside unreferenced old implementation; both present in the same file/module |
| Remediation | Replace the old implementation in-place. If old code had callers, update them. If not, delete it. Verify with grep that zero references to the old code remain. |
| Example | New `processOrderV2()` added while `processOrder()` remains with zero callers |

### Wrapper Inflation

**Corrective**: Claude adds abstraction layers "for flexibility" rather than calling lower-level APIs directly, even when no variation is planned.

| Aspect | Detail |
|--------|--------|
| Signal | Wrapper function that passes arguments through to a single target without adding logic, error handling, or type transformation |
| Remediation | Inline the wrapper -- have callers use the target directly. Remove the wrapper entirely. If the wrapper does add value (logging, validation), keep it but document the added value. |
| Example | `fetchUserData()` that only calls `apiClient.get('/users')` and returns the result unchanged |

### Dead Code Accumulation

**Corrective**: Claude comments out rather than deletes, preserving code "in case it's needed later." Version control already provides this safety net.

| Aspect | Detail |
|--------|--------|
| Signal | Commented-out blocks, unused imports, orphaned functions, `// removed` annotations, `_unused` variable renames |
| Remediation | Delete dead code entirely. Do not comment out, do not rename with underscore prefix, do not add "removed" comments. Version control preserves history. |
| Example | `// const oldHandler = ...` left in file after handler was replaced |

### Rename-Without-Delete

**Corrective**: Claude creates a renamed copy rather than modifying in place, leaving the original "for backwards compatibility" without verifying any caller needs it.

| Aspect | Detail |
|--------|--------|
| Signal | Two functions/files with similar names where the older one has zero references outside its own tests |
| Remediation | Verify zero references to the old name (grep across repo). Delete the old version. Update any remaining references to use the new name. |
| Example | Both `formatDate()` and `formatDateNew()` exist; only the latter is referenced |

### Compatibility Shim Hoarding

**Corrective**: Claude preserves backwards-compatibility code indefinitely, never evaluating whether migration is complete.

| Aspect | Detail |
|--------|--------|
| Signal | Compatibility layers, re-exports, type aliases, or adapter functions with no remaining callers outside the shim itself |
| Remediation | Grep for callers of the shim. If zero external callers remain, delete the shim. If callers exist, the shim is still needed -- leave it. |
| Example | Re-export `export { NewThing as OldThing }` where no file imports `OldThing` |

---

## Size-Check Heuristics

**These are investigation triggers, not refactoring mandates.** Exceeding a threshold means "look closer," not "refactor now." Thresholds vary by language, framework, and context.

| Metric | Investigation Trigger | Caveat |
|--------|----------------------|--------|
| Function/method length | >40 lines | Go/Rust functions may legitimately exceed this; Python comprehensions compress it |
| File length | >300 lines | Configuration files, test files, and generated code often exceed this validly |
| Parameter count | >4 parameters | Builder/options patterns are a valid alternative signal, not a violation |
| Nesting depth | >3 levels | Early returns and guard clauses reduce nesting without refactoring |
| Duplication | 3+ near-identical blocks | Verify blocks are truly duplicated (not coincidentally similar) before consolidating |

---

## Refactoring Decision Criteria Within TDD

**Scope**: This section does NOT re-explain the RED/GREEN/REFACTOR cycle (see `coding-workflows:tdd-patterns`). It covers only: (a) criteria for whether a change qualifies as "refactor" within the REFACTOR step, (b) size/scope boundaries for in-Green refactoring vs. separate commit.

### Is This Refactoring or New Feature Work?

| Criterion | Refactoring | New Feature |
|-----------|-------------|-------------|
| Behavior changes? | No -- external behavior identical before and after | Yes -- new or modified behavior |
| Tests change? | No -- existing tests pass without modification | Yes -- new tests required |
| API/interface changes? | No -- callers unaffected | Yes -- callers must update |
| Observable output changes? | No -- same inputs produce same outputs | Yes -- different outputs expected |

**Rule**: If any answer is "Yes," the change is (at least partially) new feature work, not refactoring. Separate the refactoring from the feature work into distinct commits.

### When to Defer Refactoring to a Separate Commit

| Condition | In-line (same commit) | Separate commit |
|-----------|----------------------|-----------------|
| Scope | Touches 1-2 functions in 1 file | Touches 3+ functions or 2+ files |
| Risk | Low (extract, rename, reorder) | Medium+ (consolidate, restructure) |
| Confidence | All tests pass, change is obviously safe | Needs careful verification or new tests |

### When In-Green Refactoring Is Safe

In-Green means all tests pass and you are in the REFACTOR step.

| Safe | Unsafe |
|------|--------|
| Renaming for clarity (no callers outside file) | Renaming exported symbols (callers must update) |
| Extracting private helper from a long function | Extracting to a new module (changes import graph) |
| Replacing magic numbers with named constants | Changing constant values |
| Removing dead code confirmed by grep | Removing code you "think" is unused without grep |

---

## Validation Checklist

Use this checklist to verify refactoring decisions are sound.

- [ ] Refactoring is motivated by a trigger signal (not speculative cleanup)
- [ ] Tests pass before AND after the refactoring (green-to-green)
- [ ] No behavioral changes introduced (refactoring preserves external behavior)
- [ ] Old code removed -- not left alongside new implementation
- [ ] No commented-out code, `_unused` renames, or `// removed` annotations left behind
- [ ] Scope is bounded (one refactoring pattern per commit, not a chain)
- [ ] Grep confirms zero remaining references to removed/replaced code

---

## Cross-References

- `coding-workflows:issue-workflow` references/anti-patterns -- problem-level catalog (over-engineering, silent deferrals, execution anti-patterns)
- `coding-workflows:tdd-patterns` -- RED/GREEN/REFACTOR procedural enforcement and test quality heuristics
- `coding-workflows:ai-coding-knowledge` -- strategic assessment of code bloat / avoided refactors (this skill provides the operational remediation detail that `ai-coding-knowledge` prescribes)
- Consuming commands: `execute-issue`, `review-pr`, `plan-issue`, `design-session`
