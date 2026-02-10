---
description: Execute a planned issue (requires existing plan on issue)
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

### Per-Component Cycle

1. **RED**: Write the test for the next component. Run it using the focused test command from your resolved config:
   ```
   {commands.test.focused} with the test file path
   ```
   Confirm it **fails** for the right reason (not an import error or syntax error).

2. **GREEN**: Write the minimum implementation to make the test pass. Run the focused test again.
   Exit code must be 0. If not, iterate until it is.

3. **REFACTOR**: Clean up. Run the lint and typecheck commands from your resolved config (if configured). Confirm tests still pass.

4. **Move to next component.** Repeat.

### Full Suite Gate

After all components are implemented, run the full test suite using the command from your resolved config:
```
{commands.test.full}
```

**Exit code 0 = done.** Any other exit code = not done. Do not proceed to PR creation until exit code is 0.

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
11. **Deferred Work Tracking**: Scan plan for deferred work. Apply the Follow-Up Issue Threshold from the `coding-workflows:issue-workflow` skill to each deferral. Items below threshold are done inline in the current PR; items above threshold get a follow-up issue via `/coding-workflows:issue-writer` linked to the parent issue. No silent deferrals -- every deferral must be either addressed inline or tracked as an issue.
12. Run tests with the commands from your resolved config
13. Create PR linking to issue with `gh pr create`

## Post-PR: Review Loop (CRITICAL)

After PR creation, you MUST continue with the review loop:

### Wait for CI
```bash
gh pr checks --watch
```

### Request Review
```bash
gh issue comment [NUMBER] --repo "{org}/{repo}" --body "PR ready for review: [PR_URL]"
```

### Poll for Review Feedback
```bash
gh issue view [NUMBER] --repo "{org}/{repo}" --comments
```

**STOP and wait** for review comments. Check every few minutes if needed.

### Review Loop (up to 3 iterations)
For each review comment with feedback:
1. Address ALL feedback on the same PR branch
2. Push fixes, wait for CI
3. Comment on issue summarizing changes
4. **STOP and wait** for next review

After 3 iterations with unresolved feedback, escalate to human.

### Await Merge Decision
```bash
gh issue comment [NUMBER] --repo "{org}/{repo}" --body "Ready for merge. Awaiting human decision."
```

**NEVER auto-merge.** Stop and wait for explicit merge instruction.
