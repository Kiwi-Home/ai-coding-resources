# Anti-Patterns Reference

Complete anti-pattern reference with examples for all workflow phases.

> **Context:** See the core issue-workflow skill for the summary rules and checklists.
> This file provides detailed explanations and examples to help recognize and avoid each anti-pattern.

---

## During Planning

- **Skipping research**: Always research, even briefly. The build-vs-buy step exists because existing solutions save weeks of maintenance. Skipping it leads to custom code that duplicates well-maintained libraries.
- **Vague plans**: Be specific about components, files, and approach. A plan that says "refactor the module" without naming files, describing changes, or specifying integration points is not a plan -- it's a wish.
- **Premature implementation**: Finish the plan, get approval, then code. Starting implementation during planning leads to sunk-cost bias where bad design decisions get defended because code already exists.

---

## Over-Engineering (Unplanned Additions)

Over-engineering means adding complexity **nobody asked for**. It does NOT mean cutting planned deliverables that lack immediate consumers.

Red flags when not in the plan: circuit breakers before you have traffic, feature flags when one implementation suffices, database models for static config, separate classes when a parameter would suffice.

**The test**: Was this in the plan or a chair decision? If yes, implement it. If no, would you mass-delete this code in a month? If yes, it's too much.

**Important distinction**:
- **Unplanned addition** (over-engineering): "While I'm here, let me also add X" -- don't do this
- **Planned deliverable, no consumer yet** (phased delivery): Implement it, or defer per the Follow-Up Issue Threshold in core Step 4.7. Don't silently drop it. Minor items (below threshold) should be done inline; significant items (above threshold) get a follow-up issue.

Reviewers SHOULD NOT overrule chair decisions or plan items based on "no consumer yet." Defer with a tracking issue if the item meets the threshold; otherwise, include it in the current PR.

---

## During Execution

- **Stopping after push**: Complete the CI + review loop
- **Lint blame-shifting**: Own it or prove pre-existing with evidence
- **Accepting qualified approvals**: Read carefully for conditions
- **Deviating silently**: Comment on issue when plan changes
- **Silent deferrals / micro-issue sprawl**: Apply the Follow-Up Issue Threshold (core Step 4.7)
- **Merging without instruction**: Always wait for human

---

## CI/Review Conflation (The Exit-Early Trap)

The correct behavior separates two gates: CI must pass (machine gate), THEN review must approve (human/agent gate).

| Anti-Pattern | Signal | Cost |
|--------------|--------|------|
| **Exit on CI pass** | Agent sees `gh pr checks` exit 0, declares "all checks passing" and stops | Review findings ignored, bugs ship, review loop never entered |
| **CI-as-approval** | Agent treats review bot's CI check "pass" as implicit approval | Bot ran successfully but posted MUST FIX findings in comments |

**How it happens**: `gh pr checks --watch` returns exit code 0. The agent interprets this as "all checks passed, PR is ready" and either exits the loop or posts "Ready for merge" without reading review comments.

**Why it's wrong**: A review bot runs as a CI job. Its CI status ("pass") means the bot executed without crashing -- not that it approved the code. The bot's VERDICT lives in the PR comment it posted, which may contain MUST FIX items despite the CI job reporting success.

**The rule**: CI pass means proceed to review. Review verdict means proceed to merge decision. These are two separate gates -- never skip the second because the first passed. See the Two Distinct Signals table in core Step 6 for the full conceptual model.

**Correct sequence**:
1. `gh pr checks --watch` -> exit 0 -> CI gate passed
2. Fetch PR comments -> find review comment -> parse verdict
3. Verdict says "Ready to merge" with zero blocking items -> review gate passed
4. BOTH gates passed -> post "Ready for merge. Awaiting human decision."

**Wrong sequence**:
1. `gh pr checks --watch` -> exit 0 -> "All checks passed!"
2. Skip to "Ready for merge" (WRONG -- review verdict was never checked)

---

## Agent Team Pitfalls

- Assign **non-overlapping files** to avoid conflicts
- Lead **coordinates** during parallel phase, agents implement
- **Mandatory full suite gate** after all agents complete
