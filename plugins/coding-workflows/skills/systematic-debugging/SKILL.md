---
name: systematic-debugging
description: |
  Structured debugging methodology for hypothesis-driven failure resolution.
  Encodes failure classification, evidence hierarchy, hypothesis quality criteria,
  and escalation thresholds. Use when repeated failures occur during test-driven
  development, full suite validation, or CI failure loops.
domains: [debugging, testing, diagnosis, failure-resolution]
---

# Systematic Debugging

Universal debugging knowledge for hypothesis-driven failure resolution. This skill encodes decision frameworks -- all procedural orchestration (when to invoke, retry thresholds) lives in the `execute-issue` command.

### Core Principle

**Observe before acting.** The natural instinct when a test fails is to immediately try a fix. This skill's central discipline is the opposite: gather all available evidence, classify the failure, form ranked hypotheses, then test one variable at a time. The upfront investment in evidence collection saves time overall because it prevents wasted fix attempts on incorrect hypotheses.

The framework has five phases: **Evidence Collection** (gather signals) -> **Classification** (identify failure type) -> **Hypothesis Formation** (generate and rank causes) -> **Single-Variable Testing** (test one hypothesis at a time) -> **Fix Validation** (prove the fix is correct). Each phase has explicit quality criteria defined in the sections below.

---

## Activation Criteria

**Retry threshold: `2`** -- consecutive distinct fix attempts on the same failing test before activating structured debugging. This is the single source of truth; the `execute-issue` command reads this value.

**Definition of "fix attempt":** One cycle of: make a code change, then run the failing test. The test run is the boundary -- everything changed before a test run is one attempt, regardless of how many files or lines were edited. Reverting a change and trying something different counts as a new attempt (because a test run separates them). Making multiple changes before running the test counts as one attempt (and violates the one-variable-at-a-time discipline).

**Counter semantics:** The counter is per-phase (GREEN step, Full Suite Gate, CI loop are independent). Reading the skill once per session is sufficient -- re-reading provides no new information.

| Scenario | Activate? | Why |
|----------|-----------|-----|
| Same test failing after 2+ fix attempts | YES | Threshold met -- structured debugging needed |
| First test failure on a new component | NO | Normal TDD red phase |
| Different tests failing across components | NO | Likely integration issue, not a stuck loop |
| Same error class recurring across fix attempts | YES | Pattern suggests misdiagnosis |
| CI failure on first push | NO | Normal CI feedback |
| CI failure persisting after 2+ fix-push cycles | YES | Stuck CI loop -- threshold met |
| Full suite failure after components pass individually | YES | Threshold N/A -- first occurrence IS the trigger |

**Important:** Normal TDD red-green cycling is NOT a trigger. The first failure on a new test is expected -- that's the "red" in red-green-refactor. This skill activates only when the same test continues to fail despite fix attempts, indicating the developer is stuck rather than progressing through normal TDD.

---

## Evidence Collection Gate

**Before hypothesizing, gather ALL of the following.** Skipping this gate is the #1 cause of wasted debugging cycles.

- [ ] **Full error message and stack trace** (not truncated) -- the stack trace identifies the call chain; truncating it hides the originating frame
- [ ] **The exact command that produced the failure** -- reproducibility requires knowing the precise invocation, including flags and environment
- [ ] **The test's expected vs actual output** -- the gap between expected and actual narrows the search space for root cause
- [ ] **Whether this test passed previously** (and if so, what changed since) -- establishes whether this is a regression or a new failure, which determines the diagnostic strategy
- [ ] **Whether related tests pass or fail** -- patterns across tests reveal whether the issue is localized or systemic
- [ ] **Any relevant log output beyond the test runner** -- application logs, server logs, and system logs may contain signals the test runner does not capture

**Do NOT form hypotheses until all items are checked.** Incomplete evidence leads to incorrect hypotheses, which leads to wasted fix attempts, which leads to threshold escalation.

---

## Failure Classification Framework

Classify the failure into exactly one class before proceeding. Each class has a distinct diagnostic strategy.

| Class | Signal | Diagnostic Strategy | Example |
|-------|--------|---------------------|---------|
| **Regression** | Previously passing test now fails | Bisect to identify breaking change | `test_user_login` passed on commit `abc123`, fails on `def456` -- run `git bisect` to find the breaking change |
| **Environment** | Works locally, fails in CI (or vice versa) | Compare environment configurations | pytest passes on macOS with Python 3.12, fails in CI on Ubuntu with Python 3.11 -- compare versions, env vars, installed packages |
| **Intermittent** | Non-deterministic failure | Isolate timing, state, external dependencies (fix requires 5+ consecutive passes -- see Fix Validation Criteria) | `test_async_handler` fails ~10% of runs -- isolate timing dependencies, shared state, external service calls |
| **Integration** | Components pass alone, fail together | Verify interface contract assumptions | `test_api_endpoint` passes, `test_db_query` passes, but `test_api_with_db` fails -- verify the interface assumptions between API and DB layers |
| **Data** | Correct logic, wrong output | Trace data through transformation chain | Function logic matches spec but output is wrong -- trace data through each transformation step to find where values diverge |

If a failure matches multiple classes, classify by the **strongest signal** and note secondary suspicions.

### Diagnostic Depth by Class

**Regression:** Start with `git log` on the affected file. If the breaking commit is not obvious, use `git bisect` with the failing test as the predicate. The bisect result is high-signal evidence.

**Environment:** Diff the two environments systematically: runtime versions, OS, environment variables, installed dependencies, file permissions, network access. Change one variable at a time until the environments converge.

**Intermittent:** Run the test in a loop (10-50 iterations) to establish the failure rate. Then isolate: disable parallelism, mock external services, fix random seeds, remove shared state. The variable that eliminates the flakiness is the root cause. Note: intermittent failures require a stricter fix validation standard -- see the "Intermittent Failure Carve-Out" subsection below.

**Integration:** Verify the contract at the boundary. Check that the producer's output matches the consumer's expected input -- types, nullability, ordering, encoding. Interface mismatches are the most common integration failure.

**Data:** Add assertions at each transformation step to find where the data diverges from expectations. The first assertion that fails localizes the bug to the preceding transformation.

---

## Evidence Hierarchy

**Rule:** Never act on low-signal evidence alone. Always gather at least one high-signal item before forming hypotheses.

See `references/evidence-hierarchy.md` for the full evidence quality table and signal-combining guidance. Read it when gathering diagnostic evidence to rank by signal quality.

---

## Hypothesis Quality Criteria

A good hypothesis is falsifiable, specific, and ranked.

| Criterion | Bad Hypothesis | Good Hypothesis | Why |
|-----------|---------------|-----------------|-----|
| **Falsifiable** | "Something is wrong with the config" | "The `DATABASE_URL` env var is missing in CI" | Can verify by checking env vars |
| **Specific** | "There's a race condition" | "Thread A reads the counter before Thread B's write is committed" | Names the exact interaction |
| **Ranked** | Trying the hardest fix first | "Most likely: missing import (check first). Less likely: version mismatch. Least likely: compiler bug" | Ordered by probability given evidence |

**Ranking discipline:** Test hypotheses in order of likelihood, not ease of fixing. The most probable cause should be tested first, even if it's harder to verify. Testing easy-but-unlikely causes first wastes fix attempts and accelerates threshold escalation.

### Hypothesis Lifecycle

1. **Generate** -- list all plausible causes given the evidence. Aim for 2-5 hypotheses.
2. **Rank** -- order by likelihood given evidence, not by effort to test.
3. **Test** -- test the top-ranked hypothesis with a single-variable change.
4. **Eliminate or confirm** -- if evidence disproves the hypothesis, eliminate it and move to the next. If evidence supports it, proceed to fix validation.
5. **Document** -- record each hypothesis, the test performed, and the result. This becomes the escalation report if you reach the threshold.

---

## Fix Validation Criteria

Every fix must pass ALL of these criteria. A fix that fails any criterion is incomplete.

| Criterion | What It Means | Example |
|-----------|---------------|---------|
| **Root cause addressed** | Fix targets the cause, not the symptom | Adding a `try/except` to silence an error is a symptom fix. Fixing the null check that causes the error is a root cause fix. |
| **Reproduced-before, absent-after** | Failure confirmed before fix, confirmed absent after | Run the failing test, see it fail. Apply fix. Run the same test, see it pass. |
| **No regressions** | Existing tests still pass | Run the full suite after the fix, not just the previously failing test. |
| **One variable changed** | Single change between test runs | If you changed two things and the test passes, you don't know which change fixed it. Revert one and verify. |

### Intermittent Failure Carve-Out

For non-deterministic failures, the "reproduced-before/absent-after" criterion requires **5+ consecutive passes** after the fix as sufficient evidence. A single pass is not sufficient for intermittent failures -- the test may have passed by chance.

### Common Validation Mistakes

- **Confusing symptom suppression with root cause fix:** Adding error handling around a crash site hides the crash but doesn't fix the cause. The crash will manifest elsewhere.
- **Skipping the regression check:** A fix that breaks other tests is not a fix -- it's a trade. Run the full suite, not just the previously failing test.
- **Multiple changes in one fix:** If you changed the config AND the code, and the test passes, you don't know which change mattered. This is especially dangerous because the unnecessary change may introduce a latent bug.

---

## Debugging Terminal Condition

After the debugging protocol is invoked, you get **2 additional structured attempts** (hypothesis-test-validate cycles following this skill's methodology). If neither resolves the failure, escalate to human with the Escalation Report Template (see `references/escalation-template.md`).

This prevents infinite debugging loops. The total attempt budget per phase:
- **Attempts 1-2:** Normal iteration (pre-skill, handled by `execute-issue`)
- **Attempts 3-4:** Structured debugging (post-skill, guided by this skill's methodology)
- **After attempt 4:** Mandatory human escalation with diagnostic evidence

---

## Escalation Threshold

When to stop debugging and ask the human.

| Condition | Action | Rationale |
|-----------|--------|-----------|
| 3+ hypotheses tested without progress | Escalate | You're not converging -- the root cause may require domain knowledge you don't have |
| Fix requires changes outside your file ownership | Escalate | Scope expansion risks unintended side effects in code you don't fully understand |
| Root cause appears to be in external dependency | Escalate | External dependencies are outside your control; the human may need to file upstream |
| About to revert more than you implemented | Escalate | Net negative progress means the approach may be fundamentally wrong |
| Debugging reveals the plan is flawed | Escalate per `coding-workflows:issue-workflow` | This is a plan problem, not an implementation problem -- use plan revision protocol |

**Key distinction:** Conditions 1-4 are debugging escalations (you don't know how to fix it). Condition 5 is a plan escalation (the fix is correct but the plan is wrong). These trigger different protocols.

See `references/escalation-template.md` for the report format. Read it when preparing to escalate to a human after exhausting structured debugging attempts.

---

## Anti-Patterns

| Anti-Pattern | Why It's Wrong | Do This Instead |
|--------------|----------------|-----------------|
| **Shotgun debugging** | Changing multiple things at once destroys diagnostic information | Change one variable at a time; test after each change |
| **Fix-first, understand-later** | Applying fixes without understanding the root cause leads to symptom patches | Complete the Evidence Collection Gate before any fix attempt |
| **Confidence without evidence** | "I'm sure this will fix it" bypasses the validation criteria | Every fix claim requires reproduced-before/absent-after evidence |
| **Stack Overflow driven development** | Copying solutions without understanding why they work | Understand the root cause first; verify the solution addresses YOUR specific failure |
| **Tunnel vision** | Fixating on one hypothesis and ignoring contradicting evidence | If evidence contradicts your hypothesis, eliminate it and move to the next ranked hypothesis |
| **Reverting without understanding** | Undoing changes without knowing which change caused the failure | Bisect to the specific change, then revert with understanding |
| **Log flooding** | Adding dozens of log statements hoping one reveals the issue | Add targeted logging based on your hypothesis, not scatter-shot |
| **Silent retry loops** | Retrying the same approach hoping for a different result | After 2 attempts (the retry threshold), activate structured debugging instead of continuing to iterate |

---

## Validation Checklist

The debugging protocol ends in exactly one of two ways: (1) a validated fix that passes all criteria below, or (2) an escalation to human via the Escalation Report Template. There is no third option -- "I'll come back to this later" is a silent deferral.

Before exiting with a validated fix, verify:

- [ ] Failure classified into a specific class (per Failure Classification Framework)
- [ ] Evidence Collection Gate completed (all items gathered before first hypothesis)
- [ ] Hypotheses explicitly listed and ranked (per Hypothesis Quality Criteria)
- [ ] Each hypothesis tested with single-variable change
- [ ] Fix validated per Fix Validation Criteria (including intermittent carve-out if applicable)
- [ ] Root cause documented (not just "this fix worked")

---

## Agent Team Mode

Structured debugging applies per-agent for layer-specific failures. Cross-layer integration failures escalate to the team lead.

**Sequencing:** Debugging skill activates at threshold 2 (self-help). Agent-to-lead escalation triggers at threshold 3 (per `coding-workflows:agent-team-protocol`). These are intentionally sequential -- debug first, then escalate to lead if debugging does not resolve the failure.

**Cross-layer failures:** When a full-suite integration failure involves components owned by different agents, the team lead coordinates debugging. Individual agents provide their layer's evidence; the lead synthesizes across layers and applies the Integration class diagnostic strategy.

---

## Quick Decision Reference

| Situation | Decision |
|-----------|----------|
| Test fails for the first time | Normal TDD -- do NOT activate this skill |
| Same test fails after 2 fix attempts | Activate this skill (threshold met) |
| Full suite fails after components pass | Activate this skill (integration signal) |
| CI fails on first push | Normal CI feedback -- fix and push |
| CI fails after 2+ fix-push cycles | Activate this skill (CI threshold met) |
| 3+ hypotheses tested, no progress | Escalate to human with report |
| Fix works but you changed 2 things | Revert one change, verify which one matters |
| Evidence contradicts your top hypothesis | Eliminate it, test next ranked hypothesis |
| Plan seems wrong, not just implementation | Escalate per `coding-workflows:issue-workflow` plan revision |

---

## Cross-References

- `coding-workflows:issue-workflow` -- plan revision escalation (if debugging reveals the plan is flawed, not just the implementation)
- `coding-workflows:agent-team-protocol` -- agent escalation path in team mode
- `coding-workflows:pr-review` -- severity framework for classifying the fix in review
