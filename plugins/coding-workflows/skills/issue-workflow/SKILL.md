---
name: issue-workflow
description: |
  Structured workflow for planning and executing GitHub issues. Ensures thorough
  research, proper requirements analysis, and build-vs-buy evaluation before
  implementation. Use when: planning an issue, executing an issue, or reviewing
  a plan.
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

## CRITICAL: Plan Output Location

**NEVER create plan files locally** - not in `~/.claude/plans/`, not in the repo, not anywhere on disk.

**ALWAYS post plans directly to the GitHub issue:**
```bash
gh issue comment [NUMBER] --body "[plan content]"
```

This is non-negotiable. Plans belong on the issue for visibility and review, not in local files that get lost.

---

## Target Safety

**The target resolved in Step 0 is the only valid target for the session.** Once a target (repository, project, team, or workspace) has been resolved — whether from `workflow.yaml` or auto-detect with user confirmation — it is locked. If a CLI command or MCP tool call fails for any reason:

1. The workflow **stops** — no further creation attempts
2. The workflow **never re-resolves** the target using `git remote`, MCP defaults, or any other source
3. The workflow **presents diagnostic information** to the user (see individual command error handling)

This is distinct from Step 0's auto-detect path, which uses `git remote` for *initial* resolution when no config file exists. Initial resolution is allowed; post-failure substitution is not.

> **Why this exists:** Agents can improvise fallback behavior when instructions don't explicitly prohibit it. This principle makes the prohibition explicit. See #224.

---

## Phase 1: Planning

**CONDITIONAL MANDATORY:** Before drafting any planning section, MUST read `references/planning-templates.md` for the required output formats. Do not proceed with plan drafting until you have read it.

### Step 1: Requirements Analysis (MANDATORY)

Extract and verify understanding before anything else. Output: problem statement, must-have requirements, constraints, success criteria, dependencies, open questions. If requirements are unclear or conflicting, **STOP and ask** before proceeding.

### Step 2: Build vs Buy Research (MANDATORY)

**Always research before assuming you need to build.** Even if the issue doesn't mention libraries, check if solutions exist. Search for existing solutions, evaluate each option, and make a recommendation.

**Default to existing solutions** unless:
- No maintained solution exists
- Solutions don't fit 60%+ of requirements
- Integration complexity exceeds build complexity
- Licensing/security concerns

**CONDITIONAL MANDATORY:** Before specifying any dependency version, MUST read `references/version-discovery.md` for lookup methods and version verification.

### Step 3: Codebase Exploration (MANDATORY)

Before designing, understand what exists. Search for related code, existing patterns, and prior art in the repository.

### Step 3.5: Pre-Existing State Assessment

If codebase exploration reveals that acceptance criteria appear **already met**, do not declare "already resolved" without evidence of **when and how** they were met.

> **Observing that something is done is not the same as doing it.**
> The ticket's job is to produce verifiable evidence, not confirm vibes.

**Required before declaring any AC "already resolved":**
1. Identify the specific commit or PR that resolved it (hash + description)
2. If resolved outside this ticket (ad-hoc fix, prior work), the ticket still needs to produce verification evidence (grep output, test run, before/after)
3. If partially resolved, specify exactly which ACs are met and which remain
4. Document findings in the design session or plan — don't silently skip work

**Red flags — STOP if any apply:**
- "The field is absent so the requirement is met" (absence ≠ verified resolution)
- "A recent commit addressed this" without verifying it addressed ALL acceptance criteria
- Declaring multiple ACs resolved based on a single observation
- Extrapolating from one fix to assume all related fixes were also made

### Step 4: Implementation Plan

Only after Steps 1-3, draft the plan. Include approach, files to modify, integration points, testing strategy, and rollout considerations.

**Note**: Backwards compatibility is NOT required unless explicitly requested in the issue. Prefer clean implementations over compatibility shims for pre-production projects.

### Step 5: Post Plan to Issue

Check if a plan comment already exists (look for `## Implementation Plan`). If one exists, update rather than duplicate. Post via `gh issue comment [NUMBER] --body "## Implementation Plan ..."`. Include plan content and a footer noting it awaits review.

### Step 6: Invoke Plan Review

After posting, run `/coding-workflows:review-plan [NUMBER]`. It auto-selects depth, surfaces weaknesses, and **posts a revised plan** addressing issues (or confirms the plan if none found). **STOP HERE** - Wait for human approval before executing.

---

## Phase 2: Execution

Only proceed after plan is reviewed. **UNCONDITIONAL MANDATORY:** Before beginning execution, MUST read `references/execution-details.md` for Step 6a-6d procedural details and output format templates.

### Step 0: Resolve Project Context (MANDATORY)

Read `.claude/workflow.yaml`. If present, use `project.remote` (default: `origin`) as the identity remote for org/repo resolution. If missing, auto-detect from `git remote get-url origin` + project files and **CONFIRM with user**. Validate: `project.org` and `project.name` non-empty, `commands.test.full` exists (warn if missing), `git_provider` is `github`. **DO NOT GUESS configuration values.**

`project.remote` defines the identity remote (for `gh issue`/`gh pr` targets), not the git push target. See `setup.md` for the canonical explanation.

### Step 1: Load the Plan (MANDATORY)

```bash
gh issue view [NUMBER] --comments
```

Look for `## Implementation Plan`. This is your spec - follow it. If no plan exists, **STOP** and run Planning phase first.

### Step 2: Setup

- [ ] Create feature branch using the branch pattern from your resolved config
- [ ] Verify dependencies are available
- [ ] Confirm no blocking issues

### Step 3: Implement

Follow the plan. If you discover the plan is wrong: **STOP**, update the plan with findings, comment on issue, continue only after acknowledging the change.

#### Agent Team Variant

If agent teams are active, the lead coordinates per the `coding-workflows:agent-team-protocol` skill. Lead writes contract shells, shared files, integration tests -- NOT layer-specific implementation or unit tests.

### Step 4: Test

- [ ] Write tests FIRST (TDD) or alongside implementation
- [ ] Run full test suite and linter using commands from your resolved config
- [ ] Manual verification of acceptance criteria

### Step 4.5: Verification Gate (MANDATORY)

**Before claiming implementation is complete, verify with fresh evidence.**

> **Iron Law:** No completion claims without fresh verification evidence.
> If you haven't run the verification command in this message, you cannot claim it passes.

Run the full test suite and linter. Report with evidence (see `references/execution-details.md` for the output template).

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

See `references/execution-details.md` for the output template.

### Step 4.7: Deferred Work Tracking (MANDATORY)

**If the plan deferred any work**, evaluate each deferral against the threshold before creating issues.

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

**No silent deferrals.** Planned work must either ship in the current PR or be tracked in a follow-up issue.

### Step 5: PR Creation

- [ ] Create PR with reference to issue: `Closes #[NUMBER]`
- [ ] Push branch

### Step 6: CI + Review Loop (MANDATORY)

**Do NOT stop after pushing. Enter the CI + review loop.** The `execute-issue-completion-gate` Stop hook enforces CI automatically. Review verdict enforcement requires `review_gate: true` in workflow.yaml.

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
     - CREATE ISSUE items -> note them, continue
  5. After 3 iterations with unresolved blocking items -> STOP
```

**DO NOT STOP UNTIL one of these conditions is met:**
1. Review says "Ready to merge" with zero blocking items
2. 3 iterations completed with unresolved blocking items (escalate to human)
3. Explicit human instruction to stop

**Stopping early is a workflow violation.**

#### Two Distinct Signals

| Signal | Source | Mechanism | What It Proves |
|--------|--------|-----------|----------------|
| CI status | Machine | `gh pr checks` exit code | Code compiles, tests pass, linter passes |
| Review verdict | Human or review agent | Structured PR comment content | Code is correct, complete, meets quality bar |

CI passing is NECESSARY but NOT SUFFICIENT. **CI pass means proceed to review. It does NOT mean the PR is approved.**

**BEWARE QUALIFIED APPROVALS:**
- "Ready to merge once items are addressed" is NOT approval
- "LGTM with minor changes" is NOT approval
- "Approved pending X" is NOT approval

The ONLY valid exit is "Ready to merge" with ZERO blocking items. Review verdicts follow the severity tiers defined in `coding-workflows:pr-review`. See `references/execution-details.md` for Step 6a-6d procedural details.

### Step 7: Await Merge Decision

**ALWAYS STOP HERE** - Never auto-merge. Only merge if explicitly instructed.

---

## Anti-Patterns Summary

Three critical rules to always keep visible:

- **Over-engineering**: Only implement what's in the plan or chair decisions. "Was this in the plan? If no, would you mass-delete this code in a month?"
- **CI/Review conflation**: CI pass means proceed to review, NOT approval. Never skip the review gate because CI passed.
- **Silent deferrals**: Apply the Follow-Up Issue Threshold (Step 4.7) -- planned work must ship or be tracked. No exceptions.

**UNCONDITIONAL MANDATORY:** Before beginning any work phase, MUST read `references/anti-patterns.md` for the complete anti-pattern reference with examples.

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

## Cross-References

- `coding-workflows:knowledge-freshness` -- staleness triage framework for evaluating when to verify training data before using it
- `coding-workflows:pr-review` -- severity framework for classifying findings during plan and code review
- `coding-workflows:systematic-debugging` -- hypothesis-driven debugging methodology for stuck failure loops

---

## Integration with Commands

- `/coding-workflows:plan-issue [issue]` - Runs Planning phase, stops after Step 5
- `/coding-workflows:execute-issue [issue]` - Runs Execution phase (assumes plan exists)
- `/coding-workflows:review-plan [issue]` - Reviews plan, posts revised plan

See `references/version-discovery.md` for research tools and version lookup methods.
