---
description: Implement a planned+reviewed issue using TDD; creates feature branch, opens PR, and manages review loop (up to 3 iterations)
args:
  issue:
    description: "Issue number (e.g., 10) or full reference (e.g., other-repo#10)"
    required: true
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Task
  - TeamCreate
  - TeamDelete
  - TaskCreate
  - TaskUpdate
  - TaskList
  - SendMessage
---

# Execute Issue: {{issue}}

## Step 0: Resolve Project Context (MANDATORY)

Read the `coding-workflows:project-context` skill and follow its protocol for resolving project context (reads workflow.yaml, auto-detects project settings, validates configuration). **If the skill file does not exist, STOP:** "Required skill `coding-workflows:project-context` not found. Ensure the coding-workflows plugin is installed."

**Command-specific overrides:**
- Additionally validate that `commands.test.full` exists (warn if missing, skip test steps)

**DO NOT GUESS configuration values.** If a value cannot be read from workflow.yaml or confirmed via auto-detection, ask the user.

---

## Agent Invocation

Scan `.claude/agents/*.md` for agent definitions. Match agents to the implementation:

| Phase | Selection Criteria |
|-------|--------------------|
| Implementation | Agents with TDD/testing in their `domains` |
| Domain patterns | Agents matching the plan's primary domain |
| Code review prep | Agents with `role: reviewer` |

**Before implementing**, if a TDD-focused agent exists, spawn it:
> "Guide this implementation with TDD - we should write tests first or alongside the code."

If no agents exist, proceed without specialist dispatch.

---

## Execution Topology

Check BOTH conditions before starting implementation:

1. Is `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` set?
2. Does the plan identify 3+ independent layers?

**Layer detection:**
- If plan has a Layer column in "Files to Modify": count distinct layer values
- If no Layer column: count distinct parent directories in the file list
- If count is ambiguous or unclear, default to sequential (false negative is safer than false positive file conflicts)

| Condition | Mode |
|-----------|------|
| Both true | Read the `coding-workflows:agent-team-protocol` skill and follow its protocol |
| Either false | Sequential TDD-First Completion Loop below |

Both modes share: TDD-First Completion Loop, Verification Gate, Session Checkpoint, PR creation.

---

## TDD-First Completion Loop (MANDATORY)

Strict red-green-refactor per component. Test exit code = 0 is the only proof of completion.

**Before starting the loop**, read the `coding-workflows:tdd-patterns` skill for stack-appropriate testing strategies and quality heuristics. If the skill file doesn't exist, proceed without it and note the missing skill.

### Per-Component Cycle

1. **RED**: Write the test for the next component using the patterns from the `coding-workflows:tdd-patterns` skill. Run it using the focused test command from your resolved config:
   ```
   {commands.test.focused} with the test file path
   ```
   Confirm it **fails** for the right reason (not an import error or syntax error).

2. **GREEN**: Write the minimum implementation to make the test pass. Run the focused test again.
   Exit code must be 0. If not, iterate until it is.

   **Stuck Loop Escalation:** If the same test fails after 2 fix attempts (per-phase counter), STOP iterating. Read the `coding-workflows:systematic-debugging` skill and follow its protocol before continuing. If the skill is not available, escalate to human with diagnostic evidence. If the debugging protocol does not resolve the failure within 2 additional structured attempts, escalate to human with the skill's escalation report. In agent team mode, this applies per-agent; if debugging does not resolve the failure, escalate to the team lead per the `coding-workflows:agent-team-protocol` skill.

3. **REFACTOR**: Clean up. Run the lint and typecheck commands from your resolved config (if configured). Confirm tests still pass.

4. **Move to next component.** Repeat.

### Full Suite Gate

After all components are implemented, run the full test suite using the command from your resolved config:
```
{commands.test.full}
```

**Exit code 0 = done.** Any other exit code = not done. Do not proceed to PR creation until exit code is 0.

**Integration failure escalation:** If the full suite fails after individual components passed individually, this indicates a cross-component issue. Read the `coding-workflows:systematic-debugging` skill and follow its protocol (per-phase counter). Note: no threshold applies here -- the first such failure IS the activation signal. If the skill is not available, escalate to human.

**Anti-pattern**: "I'll write all tests after implementing everything" -- this is the #1 cause of sessions ending with untested code.

---

## Session Checkpoint

After completing each major component (or when context is growing large), post a progress comment to the issue:

```bash
gh issue comment [NUMBER] --repo "{org}/{repo}" --body "## Session Checkpoint

**Branch:** \`feature/xxx\`
**Last commit:** \`$(git log --oneline -1)\`

**Completed:**
- [x] Component A -- tests passing
- [x] Component B -- tests passing

**Remaining:**
- [ ] Component C
- [ ] Integration tests
- [ ] PR creation"
```

### Session Checkpoint (Team Mode)

When using agent teams, extend the checkpoint:

```bash
gh issue comment [NUMBER] --repo "{org}/{repo}" --body "## Session Checkpoint

**Branch:** \`feature/xxx\`
**Last commit:** \`$(git log --oneline -1)\`
**Execution mode:** Agent team ([N] agents)

**Layer Status:**
- [x] Layer 1 (Agent 1) -- tests passing, committed
- [x] Layer 2 (Agent 2) -- tests passing, committed
- [ ] Layer 3 (Agent 3) -- incomplete (reason)

**Integration:** [pending / passing / failing]

**Remaining:**
- [ ] Integration tests
- [ ] PR creation"
```

---

## Step 1: Read the Skill (MANDATORY)

**Before doing anything else**, read the `coding-workflows:issue-workflow` skill bundled with this plugin. Do not proceed until you have read it.

## Step 2: Load the Plan from GitHub Issue

```bash
gh issue view {{issue}} --repo "{org}/{repo}" --comments
```

Look for a comment containing `## Implementation Plan` - this is your spec.

## Step 3: Verify Plan Has Been Reviewed (MANDATORY)

Check for a review comment containing `## Plan Review` or `## Plan Confirmed`.

**If no review found:**
1. STOP execution
2. Run `/coding-workflows:review-plan {{issue}}` first
3. After review is posted, resume with `/coding-workflows:execute-issue {{issue}}`

This ensures plans are challenged before implementation, not during code review.

## Instructions

1. **READ the skill file first** (Step 1 above) - this is non-negotiable
2. **Load the plan from GitHub** (Step 2 above) - look for `## Implementation Plan`
3. **Verify review exists** (Step 3 above) - look for review comments
4. Parse `{{issue}}` using the org/repo from your resolved config
5. If no plan found in comments, STOP and suggest `/coding-workflows:plan-issue {{issue}}`
6. If no review found in comments, STOP and run `/coding-workflows:review-plan {{issue}}`
7. Follow the Execution phase EXACTLY as defined in the skill
8. Create feature branch using the branch pattern from your resolved config
9. **Verification Gate**: Before committing, run the full test suite and linter with FRESH evidence
10. **Spec Compliance Check**: Verify you built exactly what was requested - nothing more, nothing less
11. **Deferred Work Tracking**: Scan plan for deferred work. Apply the Follow-Up Issue Threshold from the `coding-workflows:issue-workflow` skill to each deferral. Items below threshold are done inline in the current PR; items above threshold get a follow-up issue via `coding-workflows:issue-writer` linked to the parent issue. No silent deferrals -- every deferral must be either addressed inline or tracked as an issue.
12. Run tests with the commands from your resolved config
13. Create PR linking to issue with `gh pr create`

## Post-PR: CI + Review Loop (CRITICAL)

> **WARNING: "CI passed" is NOT "review approved."** CI is a prerequisite for
> reading review feedback, NOT an exit condition. Do NOT stop after CI passes.

After PR creation, you MUST enter the following loop. Do NOT stop after pushing.

> **Note:** The `execute-issue-completion-gate` Stop hook enforces the CI portion of this loop automatically. Review verdict enforcement requires `review_gate: true` in workflow.yaml (under `hooks.execute_issue_completion_gate`).

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

**Valid exit conditions (exhaustive list -- stopping for any other reason is a workflow violation):**
1. Review says "Ready to merge" with zero blocking items
2. 3 iterations completed with unresolved blocking items (escalate to human)
3. Explicit human instruction to stop

**CI Failure Escalation:** If CI fails on the same error after 2 fix-and-push cycles, see Step 6a in `references/execution-details.md` of the `coding-workflows:issue-workflow` skill for the full escalation protocol.

**NEVER auto-merge.** After loop exit, post "Ready for merge. Awaiting human decision. After approval, run `/coding-workflows:merge-issue {{issue}}` to merge and clean up." and stop. Wait for explicit merge instruction.

For detailed verdict parsing, lint blame-shifting rules, and qualified-approval detection, follow Step 6 in the `coding-workflows:issue-workflow` skill.

---

## Cross-References

- `/coding-workflows:merge-issue` -- merges PR and cleans up after execution completes and PR is approved
- `/coding-workflows:execute-issue-worktree` -- worktree variant of this command
- `/coding-workflows:cleanup-worktree` -- standalone worktree cleanup for abandoned work
- `coding-workflows:issue-workflow` -- the skill defining the full issue lifecycle
