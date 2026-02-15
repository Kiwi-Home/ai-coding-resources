# Execution Details

Procedural elaboration for Phase 2 execution steps, output format templates, and deferred work guidance.

> **Context:** See the core issue-workflow skill for workflow rules, verification gates, and decision criteria.
> This file provides step details, output templates, and examples for the execution phase.

---

## Verification Evidence Template (Step 4.5)

Report with evidence after running the full test suite and linter:

```markdown
## Verification Evidence

- Tests: [count] passing
  ```
  [paste actual test output]
  ```
- Linter: 0 errors
  ```
  [paste actual linter output]
  ```
- Acceptance criteria verified:
  - [x] Criterion 1 - [how verified]
  - [x] Criterion 2 - [how verified]
```

---

## Spec Compliance Template (Step 4.6)

```markdown
## Spec Compliance Check

| Requirement | Implementation | Evidence |
|-------------|----------------|----------|
| [Requirement 1] | [What was built] | [Test that proves it] |

**Over-engineering check:**
- [ ] No unplanned features added beyond spec
- [ ] No "while I'm here" additions
- [ ] No unnecessary abstractions
```

---

## Deferred Work: Two Failure Modes (Step 4.7)

The correct behavior sits between two anti-patterns:

| Anti-Pattern | Signal | Cost |
|--------------|--------|------|
| **Silent deferral** | Planned work disappears without tracking | Lost work, broken traceability |
| **Micro-issue sprawl** | Every small fix gets its own GitHub issue | Noise, triage overhead, slower delivery |

**The correct approach: Apply the Follow-Up Issue Threshold** (defined in core Step 4.7). Significant deferrals get tracked as issues. Small fixes discovered during work get done inline.

**Do NOT create issues for these (micro-issue sprawl):**
- Fixing a typo in a file you are already editing
- Adding a missing cross-reference between two docs
- Removing dead code you discovered while implementing
- Aligning a description string with its source of truth

**DO create issues for these (silent deferral risk):**
- Refactoring a shared module that multiple services depend on
- Adding a feature the chair recommended but that needs its own design
- Migrating a data format that affects the entire codebase

---

## Step 6a: Wait for CI

If any check fails:
1. Read the failure logs
2. Fix the issue
3. Commit and push
4. **Stuck check:** Is this the same CI error failing after 2 fix-and-push cycles (per-phase counter)?
   - **No**: Return to step 1 of Step 6a
   - **Yes**: Read the `coding-workflows:systematic-debugging` skill and follow its protocol before the next push. If the skill is not available, escalate to human with diagnostic evidence. If the debugging protocol does not resolve the CI failure within 2 additional structured attempts, escalate to human with the skill's escalation report.

**NO LINT BLAME-SHIFTING:**
If linter fails, YOU fix it. Either:
1. **Fix it** - even if pre-existing
2. **Prove it's pre-existing AND out of scope** - show `git blame` evidence, then create an issue to track it separately

---

## Step 6b: Wait for Review

After CI passes, poll for review comments on the PR:

```bash
gh pr view [PR_NUMBER] --repo "{org}/{repo}" --comments --json comments
```

Look for comments containing review verdicts ("Ready to merge", MUST FIX, FIX NOW, or CREATE ISSUE). Ignore CI bot status comments -- these are CI signals, not review verdicts (see Two Distinct Signals in core Step 6).

**Silence is not approval.** If no review comment has been posted yet, the review is still pending. Do not interpret the absence of review comments as implicit approval. Wait and re-poll.

---

## Step 6c: Process Review Findings

| Finding | Action |
|---------|--------|
| "Ready to merge" (unqualified) | **EXIT LOOP** |
| MUST FIX items | Fix ALL, commit, push, restart |
| FIX NOW items | Fix ALL, commit, push, restart |
| CREATE ISSUE items | Note them, continue |

> Review verdicts follow the severity tiers and exit criteria defined in the
> `coding-workflows:pr-review` skill. That skill is the single source of truth
> for what "Ready to merge", MUST FIX, and FIX NOW mean.

---

## Step 6d: Iteration Limit

After **3 full iterations**, if blocking items still exist, stop and escalate to human.
