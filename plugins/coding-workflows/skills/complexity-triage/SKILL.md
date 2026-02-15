---
name: complexity-triage
description: |
  Complexity assessment framework for routing issues to appropriate preparation
  depth. Defines triage signals, mode selection criteria, and output templates
  for solo and lightweight modes. Referenced by prepare-issue before design
  session dispatch.
domains: [triage, complexity, workflow, planning]
user-invocable: false
---

# Complexity Triage

Assess issue complexity and route to the appropriate design session depth: solo, lightweight, or full.

**Iron rule**: When uncertain, choose the higher-process mode. Solo is only for clearly simple issues.

---

## Triage Signals

Evaluate against already-fetched issue data only. No codebase scans during triage.

| Signal | What to Check |
|--------|--------------|
| **Domain count** | How many specialist domains does the issue touch? (mapped against available agents) |
| **Precedent** | Does the issue reference existing commands/skills as a pattern to follow? |
| **Ambiguity** | Are there open questions, conflicting requirements, or underspecified acceptance criteria? |
| **Scope** | Additive (new files) vs cross-cutting (modifying existing systems)? |
| **Scale** | Number of acceptance criteria, number of files mentioned |
| **Labels** | Any complexity indicators from issue labels |

---

## Mode Selection

| Signal Profile | Mode |
|---------------|------|
| 1 domain, clear precedent, no ambiguity, additive scope, ≤5 acceptance criteria | **Solo** |
| 1-2 domains, minor ambiguity OR moderate scope, some uncertainty | **Lightweight** |
| 3+ domains, OR significant ambiguity, OR cross-cutting scope, OR competing concerns | **Full** |
| Ambiguous / insufficient signal to classify | **Lightweight** (err toward more process) |
| Very sparse issue body (< 3 sentences, no acceptance criteria) | **Full** (insufficient info to triage safely) |

**Signal precedence**: Any single Full-tier signal (3+ domains, significant ambiguity, cross-cutting scope, competing concerns) overrides all Solo/Lightweight signals. Solo requires ALL signals to be low-complexity — one elevated signal is enough to escalate.

---

## Output Templates

### Solo Mode

```markdown
## Design Session

*Complexity triage: solo — lead assessment only, no specialist dispatch.*

### Decision
[Lead's analysis of what to build and key approach]

### Rationale
[Why this approach, including trade-offs considered]

### Specialist Input
| Specialist | Finding | Confidence |
|------------|---------|------------|
| Lead (solo assessment) | [Key finding] | [High/Medium/Low] |

### Conflicts Resolved
N/A — solo assessment.

### Action Items (Inline)
- [ ] [Items for the implementation plan]

### Action Items (Separate Issue Required)
None identified.

### Open Questions
[Any items needing human input, or "None."]

---
*Solo design assessment via `/coding-workflows:prepare-issue` (complexity: low)*
```

### Lightweight Mode

Same structure as full design session output, with these degenerate values:
- `### Specialist Input` table has exactly 1 row
- `### Conflicts Resolved` → "N/A — single specialist, no conflicting perspectives."
- Footer: `*Lightweight design session via /coding-workflows:prepare-issue (complexity: medium, 1 specialist)*`

---

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| No agents available + lightweight requested | Degrade to solo with warning |
| Low-signal / sparse issue body in auto mode | Default to full |
| Invalid mode value | Warn with valid options, default to auto |
| `planning.triage.default_mode: full` in config | Triage effectively disabled — always full |

---

## Anti-Patterns

- **Over-triaging**: Spending significant tokens evaluating complexity defeats the purpose. Triage reads the issue body and applies the decision table — nothing more.
- **Triage as analysis**: Triage does NOT perform codebase exploration, dependency research, or deep analysis. It classifies and routes.

---

## Examples

| Issue | Signals | Mode |
|-------|---------|------|
| "Fix typo in README" | 1 domain, clear precedent, additive, 1 AC | Solo |
| "Add a new command that wraps existing logic" | 1-2 domains, follows pattern, additive | Solo |
| "Add complexity triage to prepare-issue" | 3+ domains, cross-cutting, novel pattern | Full |
| "Improve error handling in plan-issue" | 1-2 domains, moderate scope | Lightweight |
| "Redesign the agent discovery system" | 3+ domains, architecture decision, cross-cutting | Full |
| "Add OAuth2 authentication" | Sparse, no precedent, significant scope | Full |

---

## Cross-References

- `coding-workflows:prepare-issue` -- uses this skill for complexity assessment before design session dispatch
- `coding-workflows:design-session` -- full deliberation mode (invoked when triage selects full)
- `coding-workflows:agent-patterns` -- agent discovery (used by lightweight mode for specialist selection)
