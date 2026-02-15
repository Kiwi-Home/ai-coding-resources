---
description: Draft a specialist-reviewed implementation plan (honors prior design-session decisions), then auto-chain into adversarial review
args:
  issue:
    description: "Issue number (e.g., 228) or full reference (e.g., other-repo#10)"
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

# Plan Issue: {{issue}}

## Step 0: Resolve Project Context (MANDATORY)

1. **Read config:** Use the Read tool to read `.claude/workflow.yaml`.
   - If file exists: extract all fields. Also read `project.remote` (default: `origin` if field is absent or empty). Use this as the identity remote name for any `git remote get-url` or `gh --repo` resolution. Proceed to step 3.
   - If file does not exist: proceed to step 2.

2. **Auto-detect (zero-config fallback):**
   - Run `git remote get-url origin` to extract org and repo name
   - Scan for project files: `pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod`, `Gemfile`
   - Infer test/lint commands from detected ecosystem
   - **CONFIRM with user:** "I detected [language] project [org/repo] with test command `[inferred]`. Is this correct?" DO NOT proceed without confirmation.

3. **Validate resolved context:**
   - `project.org` and `project.name` must be non-empty (stop if missing)
   - `git_provider` must be `github` (stop with message if not)
   - If `project.remote` is set to a non-empty value but `git remote get-url {remote}` fails: stop with error: "Configured remote '{remote}' not found. Run `git remote -v` to see available remotes, or update project.remote in .claude/workflow.yaml." Do NOT silently fall back to origin.

**DO NOT GUESS configuration values.** If a value cannot be read from workflow.yaml or confirmed via auto-detection, ask the user.

---

## Step 1: Read the Skill (MANDATORY)

Use the Read tool to read the `coding-workflows:issue-workflow` skill bundled with this plugin. If the skill file doesn't exist, proceed without it and note the missing skill.

Do not proceed until you have read it (or confirmed it's missing).

---

## Step 2: Fetch and Analyze Issue

Parse `{{issue}}`:
- Plain number (e.g., `228`) -> use the default repo from resolved config
- With repo (e.g., `other-repo#10`) -> use as-is with the org from resolved config

```bash
gh issue view [NUMBER] --repo "{org}/{repo}" --json title,body,labels,comments
```

### Check for Prior Chair Session

Look for comments starting with `## Design Session`.

**If design session exists:**
- Extract decisions, constraints, and action items
- These are **binding** - the plan must align with design session decisions
- Note any ADRs referenced

**If no design session:**
- Proceed normally
- Consider recommending `/coding-workflows:design-session` if design decisions are unclear

---

## Step 3: Select Specialists

Scan `.claude/agents/*.md` for agent definitions. Read frontmatter to extract `name`, `description`, `domains`, `role`.

Match agents to the issue content:
- Compare issue keywords and labels against agent `domains` arrays (fuzzy matching)
- If `planning.always_include` is configured in workflow.yaml, include those agents
- If no agents found, proceed without specialist input

**Selection rules:**
- Include the most relevant domain specialist
- Add an architect-role agent for features touching multiple components
- Max 2 specialists for planning (save deeper review for `/coding-workflows:design-session`)

---

## Step 4: Draft Plan with Specialist Input

### 4a. Draft Initial Plan

Create a rough implementation plan covering:
- Approach summary
- Key components/files to change
- Integration points
- Testing strategy

### 4b. Multi-Round Dispatch Check

Before dispatching specialists, evaluate:

1. **Specialist count**: Are 2+ specialists being dispatched?
2. **Conflict potential**: Check `deliberation.conflict_overrides` in workflow.yaml. If ANY specialist pair has HIGH conflict, this condition is true.

If BOTH conditions are true, use multi-round dispatch:

**Check**: Is `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` set to `1`?
- **Yes**: Use agent-team dispatch (TeamCreate, SendMessage, persistent context)
  - If TeamCreate fails: log warning, fall back to Task-based dispatch
- **No**: Use Task-based multi-round dispatch (sequential Task calls with context bridging)

If EITHER condition is false:
- Use single-round Task dispatch

**When using multi-round dispatch**: Read the `coding-workflows:deliberation-protocol` skill and follow its protocol. When `plan-issue` auto-chains to `review-plan` in Step 8, the review phase evaluates its own guard clause independently.

### 4c. Invoke Specialists

For each selected specialist, use the Task tool with `subagent_type` set to the agent name from frontmatter. Your prompt should focus on the plan review:

**Template:**
```
Review this implementation plan for issue #[NUM]: [TITLE]

**Requirements:**
[From issue body]

**Proposed Approach:**
[Your draft plan]

**Your Focus:** [Domain-specific focus based on agent's domains]

Please evaluate:
1. Does this approach fit the project's patterns?
2. What edge cases or failure modes should we handle?
3. Any simpler alternatives?
4. Testing considerations for your domain?

End with:
### Assessment
- **Recommendation:** [Approve / Suggest changes / Flag concerns]
- **Key risks:** [1-2 sentences]
```

### 4d. Incorporate Feedback

Revise plan based on specialist input:
- Address any `Flag concerns` immediately
- Incorporate `Suggest changes` where sensible
- Note any trade-offs in the plan

---

## Step 5: Format Final Plan

```markdown
## Implementation Plan

{{#if design_session_found}}
### Prior Design Decisions
*From [design session comment link]*
- [Key decision 1]
- [Key decision 2]
{{/if}}

### Specialist Review
| Specialist | Recommendation | Key Input |
|------------|----------------|-----------|
| [name] | [Approve/Changes/Concerns] | [1-line summary] |

### Approach
[High-level description - must align with design session decisions if present]

### Components
1. **[Component]**: [What and why]
2. **[Component]**: [What and why]

### Files to Modify
- `path/to/file` - [change description]

### Testing Strategy
- Unit: [what to test]
- Integration: [what to test]
- Edge cases: [from specialist input]

### Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| [from specialist input] | [how addressed] |

---
*Plan created with specialist input via `/coding-workflows:plan-issue`*
```

---

## Step 6: Post to GitHub Issue

Before posting, check if a plan comment already exists (look for `## Implementation Plan` header). If one exists, consider updating rather than duplicating.

```bash
gh issue comment [NUMBER] --repo "{org}/{repo}" --body "PLAN"
```

---

## Step 7: Transition to Review

After posting the plan:

```
Implementation plan complete for {{issue}}

Specialists consulted: [list]
Plan posted to issue.

Clearing context before adversarial review...
```

**Execute:** `/clear`

---

## Step 8: Invoke Adversarial Review

After clearing context, execute the full `/coding-workflows:review-plan` workflow for `{{issue}}`:

This will:
1. Fetch the issue and find the plan we just posted
2. Select adversarial reviewers
3. Dispatch with adversarial prompts
4. Post review to issue
5. Post revised plan if issues found

**Do not stop between planning and review** - the pipeline should flow automatically.

---

## When to Escalate to /coding-workflows:design-session INSTEAD

Use `/coding-workflows:design-session` instead of `/coding-workflows:plan-issue` when:
- Multiple valid approaches with real trade-offs
- Specialists flagged concerns they couldn't resolve
- Architecture decisions needed (not just implementation)
- Reviewing existing work (PRs, merged code)
- Issue lacks clear requirements

`/coding-workflows:plan-issue` = "How do we build this?"
`/coding-workflows:design-session` = "What should we build?" or "Is this right?"

---

## Final Report (After Review Completes)

```
Planning and review complete for {{issue}}

**Completed:**
- [x] Implementation plan with specialist input
- [x] Adversarial review
- [x] Revised plan (if needed)

**Ready for:** `/coding-workflows:execute-issue {{issue}}`
```

**STOP** - Wait for human approval before execution.
