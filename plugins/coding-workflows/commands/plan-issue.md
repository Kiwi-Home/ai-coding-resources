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

## Steps 0-1: Resolve Context and Read Skill (parallel)

<!-- SYNC: preamble-check — keep identical in plan-issue.md, review-plan.md, design-session.md -->
**Pipeline preamble (optimization cache):** Check if `/tmp/.coding-workflows-preamble-{issue}.yaml`
exists (where `{issue}` is `{{issue}}` with `#` replaced by `-`). If found, read and validate:
YAML must parse, `version` must equal `1`, `created_at` must be within 30 minutes, all required
fields present (`version`, `created_at`, `issue`, `issue_repo`, `project.org`, `project.name`,
`project.git_provider`, `config_source`), and `preamble.issue` matches `{{issue}}`. If valid,
adopt resolved values and skip to structural validation: confirm `project.org`/`project.name`
non-empty, `git_provider` is `github`, and `git remote get-url {project.remote}` succeeds.
If file not found, parse error, stale, or any validation fails, continue with full protocol below.
<!-- /SYNC: preamble-check -->

**Run the following two reads in parallel** (both are unconditional and independent):

1. **Resolve Project Context (MANDATORY):** Read the `coding-workflows:project-context` skill and follow its protocol for resolving project context (reads workflow.yaml, auto-detects project settings, validates configuration). **If the skill file does not exist, STOP:** "Required skill `coding-workflows:project-context` not found. Ensure the coding-workflows plugin is installed."

2. **Read the Skill (MANDATORY):** Use the Read tool to read the `coding-workflows:issue-workflow` skill bundled with this plugin. If the skill file doesn't exist, proceed without it and note the missing skill.

**DO NOT GUESS configuration values.** If a value cannot be read from workflow.yaml or confirmed via auto-detection, ask the user.

Do not proceed until both reads are complete (or confirmed missing).

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

> For token cost and trade-off comparison between dispatch modes, see the **Dispatch Mode Comparison** section in `coding-workflows:deliberation-protocol`.

If EITHER condition is false:
- Use single-round Task dispatch

**When using multi-round dispatch**: Read `coding-workflows:deliberation-protocol` and follow its phases (Setup through Shutdown) in place of Steps 4c-4d. Resume at Step 5 after the protocol completes. If the skill file does not exist, fall back to single-round Task dispatch.

### 4c. Invoke Specialists

**Note:** If multi-round dispatch was activated in Step 4b, the deliberation protocol replaces Steps 4c-4d. Do not execute them -- resume at Step 5.

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

### Preamble Emission (optimization cache)

Write resolved project context to `/tmp/.coding-workflows-preamble-{issue}.yaml` (where `{issue}` is `{{issue}}` with `#` replaced by `-`) so that `review-plan` can skip redundant context resolution after `/clear`. **If the write fails** (permissions, disk full, etc.), **log a warning and continue** — `review-plan` falls back to full protocol.

```bash
cat > /tmp/.coding-workflows-preamble-{issue}.yaml <<'EOF'
# --- project-context-preamble v1 ---
version: 1
created_at: "{ISO-8601 timestamp}"
issue: "{raw {{issue}} value}"
issue_repo: "{resolved repo name}"
project:
  org: "{resolved org}"
  name: "{resolved repo name}"
  remote: "{resolved remote, default: origin}"
  language: "{resolved language}"
  git_provider: "github"
branch_pattern: "{resolved branch pattern}"
config_source: "{workflow.yaml or auto-detect}"
# --- end preamble ---
EOF
```

### Transition

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

> **Note:** The review phase evaluates its own multi-round dispatch guard clause independently. Multi-round dispatch in `plan-issue` does not imply multi-round dispatch in `review-plan`.

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
