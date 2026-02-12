---
name: issue-workflow
description: |
  Structured workflow for planning and executing GitHub issues. Ensures thorough
  research, proper requirements analysis, and build-vs-buy evaluation before
  implementation. Use when: planning an issue, executing an issue, or reviewing
  a plan.
triggers:
  - /plan-issue
  - /execute-issue
  - /review-plan
  - planning implementation
  - working on issue
domains: [planning, execution, workflow]
---

# Issue Workflow

## Agent Invocation

Different phases benefit from different specialists. Agents are discovered dynamically from `.claude/agents/*.md` based on frontmatter metadata.

| Phase | Condition | Agent Selection |
|-------|-----------|-----------------|
| Planning | Domain-specific work | Match issue keywords against agent `domains` metadata |
| Planning | Architecture | Match agents with `role: architect` |
| Review | All plans | Use `/coding-workflows:review-plan` for adversarial dispatch |
| Execution | All | Match agents with testing/TDD focus |
| Pre-PR | All | Match agents with `role: reviewer` |

**The `/coding-workflows:plan-issue`, `/coding-workflows:review-plan`, `/coding-workflows:execute-issue` commands handle agent invocation** - use those commands rather than invoking this skill directly.

---

Structured process for planning and executing GitHub issues with mandatory research and build-vs-buy evaluation.

## CRITICAL: Plan Output Location

**NEVER create plan files locally** - not in `~/.claude/plans/`, not in the repo, not anywhere on disk.

**ALWAYS post plans directly to the GitHub issue:**
```bash
gh issue comment [NUMBER] --body "[plan content]"
```

This is non-negotiable. Plans belong on the issue for visibility and review, not in local files that get lost.

---

## Phase 1: Planning

### Step 1: Requirements Analysis (MANDATORY)

Before anything else, extract and verify understanding:

```markdown
## Requirements Extracted

**Problem**: [1-2 sentences - what's broken or missing?]

**Must Have**:
- [ ] Requirement 1
- [ ] Requirement 2

**Constraints**:
- Constraint 1
- Constraint 2

**Success Criteria**:
- [ ] Acceptance criterion 1
- [ ] Acceptance criterion 2

**Dependencies**: [Issues that must complete first, or "None"]

**Open Questions**: [Ambiguities that need clarification before proceeding]
```

If requirements are unclear or conflicting, **STOP and ask** before proceeding.

### Step 2: Build vs Buy Research (MANDATORY)

**Always research before assuming you need to build.** Even if the issue doesn't mention libraries, check if solutions exist.

#### 2a. Search for Existing Solutions

```markdown
## Research: Existing Solutions

**Search queries used**:
- "[language] [problem domain] library"
- "[framework] [feature] package"

**Solutions Found**:

| Solution | Type | Maintenance | Compatibility | Fit |
|----------|------|-------------|---------------|-----|
| package-name | Library | Active/Stale | [runtime] | Good/Partial/Poor |

**Evaluation**:
- Option A: [library] - Pros: ... Cons: ...
- Option B: [different library] - Pros: ... Cons: ...
- Option C: Build native - Pros: ... Cons: ...
```

#### 2b. Evaluate Each Option

For each potential solution, check:

- **Maintenance**: Last commit, open issues, release frequency
- **Compatibility**: Runtime version, dependency conflicts
- **Adoption**: GitHub stars, downloads, production usage
- **Fit**: Does it solve 80%+ of requirements? What's missing?
- **Complexity**: Setup burden, learning curve, operational overhead
- **Current Version**: Verify latest stable (see [Version Discovery](#version-discovery-required-for-new-dependencies) below)

> **IMPORTANT**: For EVERY new dependency you plan to add, verify the current stable version. Never rely on training data versions.

#### 2c. Make a Recommendation

```markdown
## Recommendation

**Approach**: [Use X / Build native / Hybrid]

**Rationale**: [Why this option over alternatives]

**Trade-offs accepted**: [What we're giving up]

**Risks**: [What could go wrong]
```

**Default to existing solutions** unless:
- No maintained solution exists
- Solutions don't fit 60%+ of requirements
- Integration complexity exceeds build complexity
- Licensing/security concerns

### Step 3: Codebase Exploration (MANDATORY)

Before designing, understand what exists. Search for related code, existing patterns, and prior art in the repository.

```markdown
## Codebase Context

**Related code found**:
- `path/to/file` - Does X, could extend for Y

**Existing patterns to follow**:
- [Pattern name from project conventions]

**Code to modify vs create**:
- Modify: `existing_file` (add capability)
- Create: `new_file` (new responsibility)
```

### Step 4: Implementation Plan

Only after Steps 1-3, draft the plan:

```markdown
## Implementation Plan

### Approach
[High-level description of the solution]

### Files to Modify

| File | Change |
|------|--------|

> For plans with 3+ distinct layers, add Layer and Agent columns to enable parallel execution:
> | File | Change | Layer | Agent |
> |------|--------|-------|-------|

### Integration Points
- Integrates with: [existing code/systems]
- Affects: [other parts of codebase]

### Testing Strategy
- Unit tests for: [components]
- Integration tests for: [workflows]
- Edge cases: [specific scenarios]

### Rollout Considerations
- Migration needed: [yes/no, details]
- Feature flag: [yes/no]
```

> **Tip**: Reference `coding-workflows:tdd-patterns` for stack-appropriate testing strategies when filling in the Testing Strategy section.

**Note**: Backwards compatibility is NOT required unless explicitly requested in the issue.
Prefer clean implementations over compatibility shims for pre-production projects.

### Step 5: Post Plan to Issue

Before posting, check if a plan comment already exists (look for `## Implementation Plan` header). If one exists, update the existing comment rather than creating a duplicate.

Append the plan as a comment on the GitHub issue with a clear header:

```bash
gh issue comment [NUMBER] --body "## Implementation Plan

[plan content from Step 4]

---
*Plan generated by Claude Code - awaiting review before execution*"
```

### Step 6: Invoke Plan Review

After posting the plan, run `/coding-workflows:review-plan [NUMBER]` to challenge it:

- Auto-selects depth based on plan complexity
- Surfaces weaknesses, gaps, and alternatives before implementation
- **Automatically posts a revised plan** addressing all issues raised
- Or confirms the plan if no issues found

The revised plan will include an "Issues Addressed" table showing how each concern was resolved.

**STOP HERE** - Wait for human approval before executing.

---

## Phase 2: Execution

Only proceed after plan is reviewed.

### Step 0: Resolve Project Context (MANDATORY)

1. **Read config:** Use the Read tool to read `.claude/workflow.yaml`.
   - If file exists: extract all fields. Proceed to step 3.
   - If file does not exist: proceed to step 2.

2. **Auto-detect (zero-config fallback):**
   - Run `git remote get-url origin` to extract org and repo name
   - Scan for project files: `pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod`, `Gemfile`
   - Infer test/lint commands from detected ecosystem
   - **CONFIRM with user:** "I detected [language] project [org/repo] with test command `[inferred]`. Is this correct?" DO NOT proceed without confirmation.

3. **Validate resolved context:**
   - `project.org` and `project.name` must be non-empty (stop if missing)
   - `commands.test.full` should exist (warn if missing, skip test steps)
   - `git_provider` must be `github` (stop with message if not)

**DO NOT GUESS configuration values.** If a value cannot be read from workflow.yaml or confirmed via auto-detection, ask the user.

### Step 1: Load the Plan (MANDATORY)

**Before doing anything else, read the issue AND its comments to find the implementation plan:**

```bash
gh issue view [NUMBER] --comments
```

Look for a comment containing `## Implementation Plan`. This is your spec - follow it.

If no plan exists, **STOP** and run Planning phase first.

### Step 2: Setup

- [ ] Create feature branch using the branch pattern from your resolved config
- [ ] Verify dependencies are available
- [ ] Confirm no blocking issues

### Step 3: Implement

Follow the plan. If you discover the plan is wrong:

1. **STOP implementation**
2. Update the plan with findings
3. Comment on issue with revised approach
4. Continue only after acknowledging the change

#### Agent Team Variant

If agent teams are active (see Execution Topology in `execute-issue`), the lead coordinates per the `coding-workflows:agent-team-protocol` skill.

**Lead writes**: contract shells, shared files, integration tests, interface fixes.
**Lead does NOT write**: layer-specific implementation or unit tests -- agents own those.
**Agents**: Follow TDD independently, mark tasks completed, report blockers via SendMessage.

### Step 4: Test

- [ ] Write tests FIRST (TDD) or alongside implementation
- [ ] Run full test suite using the command from your resolved config
- [ ] Run linter using the command from your resolved config
- [ ] Manual verification of acceptance criteria

### Step 4.5: Verification Gate (MANDATORY)

**Before claiming implementation is complete, verify with fresh evidence.**

> **Iron Law:** No completion claims without fresh verification evidence.
> If you haven't run the verification command in this message, you cannot claim it passes.

Run the full test suite and linter from your resolved config.

**Report with evidence:**
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

**Red flags - STOP if any apply:**
- Using "should", "probably", "seems to work"
- About to commit without running tests *in this session*
- Trusting memory of a previous run
- Saying "I'm confident" (confidence is not evidence)

### Step 4.6: Spec Compliance Self-Check (MANDATORY)

**Before PR creation, verify you built what was requested - nothing more, nothing less.**

| Check | Question |
|-------|----------|
| **Missing requirements** | Did I implement everything in the spec? Re-read each requirement. |
| **Extra work** | Did I build only what was requested? No "while I'm here" additions? |
| **Misunderstandings** | Did I solve the right problem the right way? |

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

### Step 4.7: Deferred Work Tracking (MANDATORY)

**If the plan deferred any work** (items from the original plan or chair decisions that were descoped during review), evaluate each deferral against the threshold before creating issues.

#### Follow-Up Issue Threshold

**Default: Do it inline.** A separate follow-up issue is only warranted when the work meets ANY of these criteria:

- **Cross-boundary**: Crosses a module, service, or repository boundary (not merely touching a file outside the issue's listed files -- incidental edits to adjacent files are normal)
- **Design-required**: Needs its own requirements analysis, architecture decision, or testing strategy
- **Risk-elevating**: Requires reviewers to assess side effects outside the PR's primary scope, or needs its own test plan

These three criteria are the canonical set. If a deferral does not meet any of them, it belongs in the current PR.

| Scenario | Verdict | Why |
|----------|---------|-----|
| Fix a typo in a doc you are already editing | Inline | Same file, zero risk |
| Add a cross-reference from skill A to skill B | Inline | One-line edit, no design needed |
| Remove dead code discovered during implementation | Inline | Small, reduces complexity |
| Refactor a shared utility used by 4 other modules | Separate issue | Cross-boundary, risk-elevating |
| Add a new validation layer the chair recommended | Separate issue | Design-required, new tests needed |
| Migrate a config format across all commands | Separate issue | Cross-boundary, design-required |

#### Process

1. **Scan the plan** for language like "deferred", "follow-up", "future work", "out of scope (was in original plan)"
2. **For each deferral**, apply the threshold:
   - **Below threshold**: Do the work in the current PR
   - **Above threshold**: Create a follow-up issue using `/coding-workflows:issue-writer` with title, rationale, trigger conditions, and parent issue link
3. **List in the PR description**:
   - "Included inline" items under a brief note
   - "Deferred Work" section with issue links for items above threshold

**No silent deferrals.** Planned work must either ship in the current PR or be tracked in a follow-up issue. The threshold determines which path -- not whether the work is acknowledged.

### Step 5: PR Creation

- [ ] Create PR with reference to issue: `Closes #[NUMBER]`
- [ ] Push branch

### Step 6: CI + Review Loop (MANDATORY)

**Do NOT stop after pushing. Enter the CI + review loop.**

> **Hook enforcement:** The `execute-issue-completion-gate` Stop hook enforces the CI portion of this loop automatically. Review verdict enforcement requires `review_gate: true` in workflow.yaml (under `hooks.execute_issue_completion_gate`).

<!-- SYNC: keep identical in execute-issue.md and issue-workflow SKILL.md Step 6 -->
```
LOOP (max 3 iterations)

  1. Wait for CI: gh pr checks [PR_NUMBER] --watch
  2. If CI fails -> fix, commit, push, restart loop
  3. Wait for review: gh pr view [PR_NUMBER] --comments
  4. Check review verdict:
     - "Ready to merge" -> EXIT LOOP (success)
     - MUST FIX items -> fix ALL, push, restart loop
     - FIX NOW items -> fix ALL, push, restart loop
     - NEW ISSUE items -> note them, continue
  5. After 3 iterations with unresolved blocking items -> STOP
```

**DO NOT STOP UNTIL one of these conditions is met:**
1. Review says "Ready to merge" with zero blocking items
2. 3 iterations completed with unresolved blocking items (escalate to human)
3. Explicit human instruction to stop

**Stopping early is a workflow violation.**

#### Two Distinct Signals

This loop evaluates two categorically different signals. Do not conflate them.

| Signal | Source | Mechanism | What It Proves |
|--------|--------|-----------|----------------|
| CI status | Machine | `gh pr checks` exit code | Code compiles, tests pass, linter passes |
| Review verdict | Human or review agent | Structured PR comment content | Code is correct, complete, meets quality bar |

CI passing is NECESSARY but NOT SUFFICIENT for merge readiness. A review bot's CI check passing means the bot ran successfully -- not that it found zero issues. The exit code tells you the job ran; the PR comment tells you the verdict.

> **CRITICAL**: CI pass means proceed to review. It does NOT mean the PR is approved.

#### Step 6a: Wait for CI

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

#### Step 6b: Wait for Review

After CI passes, poll for review comments on the PR:

```bash
gh pr view [PR_NUMBER] --repo "{org}/{repo}" --comments --json comments
```

Look for comments containing review verdicts ("Ready to merge", MUST FIX, FIX NOW, or NEW ISSUE). Ignore CI bot status comments -- these are CI signals, not review verdicts (see Two Distinct Signals above).

**Silence is not approval.** If no review comment has been posted yet, the review is still pending. Do not interpret the absence of review comments as implicit approval. Wait and re-poll.

#### Step 6c: Process Review Findings

| Finding | Action |
|---------|--------|
| "Ready to merge" (unqualified) | **EXIT LOOP** |
| MUST FIX items | Fix ALL, commit, push, restart |
| FIX NOW items | Fix ALL, commit, push, restart |
| NEW ISSUE items | Note them, continue |

**BEWARE QUALIFIED APPROVALS:**
- "Ready to merge once items are addressed" is NOT approval
- "LGTM with minor changes" is NOT approval
- "Approved pending X" is NOT approval

The ONLY valid exit is "Ready to merge" with ZERO blocking items.

> Review verdicts follow the severity tiers and exit criteria defined in the
> `coding-workflows:pr-review` skill. That skill is the single source of truth
> for what "Ready to merge", MUST FIX, and FIX NOW mean.

#### Step 6d: Iteration Limit

After **3 full iterations**, if blocking items still exist, stop and escalate to human.

### Step 7: Await Merge Decision

**ALWAYS STOP HERE** - Never auto-merge.

The human will either merge, request changes, or provide further instructions. **Only merge if explicitly instructed.**

---

## Anti-Patterns to Avoid

### During Planning

- **Skipping research**: Always research, even briefly
- **Vague plans**: Be specific about components, files, and approach
- **Premature implementation**: Finish the plan, get approval, then code

### Over-Engineering (Unplanned Additions)

Over-engineering means adding complexity **nobody asked for**. It does NOT mean cutting planned deliverables that lack immediate consumers.

Red flags when not in the plan: circuit breakers before you have traffic, feature flags when one implementation suffices, database models for static config, separate classes when a parameter would suffice.

**The test**: Was this in the plan or a chair decision? If yes, implement it. If no, would you mass-delete this code in a month? If yes, it's too much.

**Important distinction**:
- **Unplanned addition** (over-engineering): "While I'm here, let me also add X" — don't do this
- **Planned deliverable, no consumer yet** (phased delivery): Implement it, or defer per the Follow-Up Issue Threshold in Step 4.7. Don't silently drop it. Minor items (below threshold) should be done inline; significant items (above threshold) get a follow-up issue.

Reviewers SHOULD NOT overrule chair decisions or plan items based on "no consumer yet." Defer with a tracking issue if the item meets the threshold; otherwise, include it in the current PR.

### During Execution

- **Stopping after push**: Complete the CI + review loop
- **Lint blame-shifting**: Own it or prove pre-existing with evidence
- **Accepting qualified approvals**: Read carefully for conditions
- **CI/Review conflation**: Treating CI pass as review approval (see [CI/Review Conflation](#cireview-conflation-the-exit-early-trap) below)
- **Deviating silently**: Comment on issue when plan changes
- **Silent deferrals / micro-issue sprawl**: Apply the Follow-Up Issue Threshold (see below)
- **Merging without instruction**: Always wait for human

### Deferred Work: Two Failure Modes

The correct behavior sits between two anti-patterns:

| Anti-Pattern | Signal | Cost |
|--------------|--------|------|
| **Silent deferral** | Planned work disappears without tracking | Lost work, broken traceability |
| **Micro-issue sprawl** | Every small fix gets its own GitHub issue | Noise, triage overhead, slower delivery |

**The correct approach: Apply the Follow-Up Issue Threshold** (defined in Step 4.7). Significant deferrals get tracked as issues. Small fixes discovered during work get done inline.

**Do NOT create issues for these (micro-issue sprawl):**
- Fixing a typo in a file you are already editing
- Adding a missing cross-reference between two docs
- Removing dead code you discovered while implementing
- Aligning a description string with its source of truth

**DO create issues for these (silent deferral risk):**
- Refactoring a shared module that multiple services depend on
- Adding a feature the chair recommended but that needs its own design
- Migrating a data format that affects the entire codebase

### CI/Review Conflation (The Exit-Early Trap)

The correct behavior separates two gates: CI must pass (machine gate), THEN review must approve (human/agent gate).

| Anti-Pattern | Signal | Cost |
|--------------|--------|------|
| **Exit on CI pass** | Agent sees `gh pr checks` exit 0, declares "all checks passing" and stops | Review findings ignored, bugs ship, review loop never entered |
| **CI-as-approval** | Agent treats review bot's CI check "pass" as implicit approval | Bot ran successfully but posted MUST FIX findings in comments |

**How it happens**: `gh pr checks --watch` returns exit code 0. The agent interprets this as "all checks passed, PR is ready" and either exits the loop or posts "Ready for merge" without reading review comments.

**Why it's wrong**: A review bot runs as a CI job. Its CI status ("pass") means the bot executed without crashing -- not that it approved the code. The bot's VERDICT lives in the PR comment it posted, which may contain MUST FIX items despite the CI job reporting success.

**The rule**: CI pass means proceed to review. Review verdict means proceed to merge decision. These are two separate gates — never skip the second because the first passed. See the Two Distinct Signals table in Step 6 for the full conceptual model.

**Correct sequence**:
1. `gh pr checks --watch` -> exit 0 -> CI gate passed
2. Fetch PR comments -> find review comment -> parse verdict
3. Verdict says "Ready to merge" with zero blocking items -> review gate passed
4. BOTH gates passed -> post "Ready for merge. Awaiting human decision."

**Wrong sequence**:
1. `gh pr checks --watch` -> exit 0 -> "All checks passed!"
2. Skip to "Ready for merge" (WRONG -- review verdict was never checked)

### Agent Team Pitfalls

- Assign **non-overlapping files** to avoid conflicts
- Lead **coordinates** during parallel phase, agents implement
- **Mandatory full suite gate** after all agents complete

---

## Checklist

### Planning Checklist

- [ ] Requirements extracted and verified
- [ ] Build vs buy research completed
- [ ] Existing solutions evaluated with clear recommendation
- [ ] Codebase explored for related code and patterns
- [ ] Implementation plan drafted
- [ ] Plan posted to issue as comment (checked for duplicates first)
- [ ] **STOPPED** to wait for review (unless autonomous mode)

### Execution Checklist

- [ ] Project context resolved (Step 0)
- [ ] Issue and comments read
- [ ] Implementation plan found
- [ ] Feature branch created
- [ ] Implementation follows plan (or plan updated if changed)
- [ ] Tests written and passing
- [ ] Linter passing
- [ ] **Verification gate passed** (fresh evidence, not "should work")
- [ ] **Spec compliance checked** (nothing missing, nothing extra)
- [ ] **Deferred work tracked** (inline fixes completed, follow-up issues created for above-threshold deferrals)
- [ ] PR created with issue reference
- [ ] **ENTERED CI + REVIEW LOOP** (do NOT stop after push)
- [ ] CI passing
- [ ] **CI pass is not review approval** -- continued to review step (not stopped here)
- [ ] Lint failures fixed
- [ ] Review received
- [ ] All blocking items addressed
- [ ] **Verified unqualified approval** (no conditions attached)
- [ ] Loop repeated until clean approval OR 3 iterations
- [ ] **STOPPED** to await merge decision
- [ ] Merged only when explicitly instructed

### Agent Team Additions

- [ ] Non-overlapping file assignments per agent
- [ ] All agent tasks completed and integration tests pass
- [ ] All agents shut down and team cleaned up

---

## Integration with Commands

This skill is invoked by:

- `/coding-workflows:plan-issue [issue]` - Runs Planning phase, stops after Step 5
- `/coding-workflows:execute-issue [issue]` - Runs Execution phase (assumes plan exists)
- `/coding-workflows:review-plan [issue]` - Reviews plan, posts revised plan addressing all issues raised

## Research Tools Available

When researching existing solutions:

- **Web search**: Search for libraries and patterns
- **Context7 MCP**: Look up library documentation
- **GitHub search**: Find similar implementations
- **Package registries**: Check package maintenance status

### Version Discovery (REQUIRED for new dependencies)

Before specifying any dependency version in a plan, verify the current stable version. Never rely on training data.

**Lookup Methods (in order of preference):**

1. **Context7** (fastest, includes docs):
   ```
   mcp__context7__resolve-library-id libraryName="package-name"
   ```

2. **Package Registry APIs** (reliable):
   ```bash
   # Python (PyPI)
   curl -s "https://pypi.org/pypi/PACKAGE/json" | jq -r '.info.version'

   # JavaScript (npm)
   curl -s "https://registry.npmjs.org/PACKAGE/latest" | jq -r '.version'

   # Ruby (RubyGems)
   curl -s "https://rubygems.org/api/v1/gems/GEM.json" | jq -r '.version'

   # Rust (crates.io)
   curl -s "https://crates.io/api/v1/crates/CRATE" | jq -r '.crate.max_stable_version'

   # Go
   go list -m -versions MODULE
   ```

3. **WebSearch** (fallback):
   ```
   WebSearch "PACKAGE latest stable version [current year]"
   ```

4. **If all fail**: Document "version unverified - using [version] from [source], recommend human verification"

**When to use older versions (always document rationale):**
- Newer version has known breaking bugs
- Compatibility matrix requires it
- Production system already uses it and upgrade is out of scope
- Pre-release is latest but you need stable
