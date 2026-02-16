---
description: Adversarial review of an implementation plan; posts revised plan if blocking issues found
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

# Review Plan: {{issue}}

Adversarial critique of an existing plan. Goal: surface problems BEFORE implementation.

---

## Step 0: Resolve Project Context (MANDATORY)

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

Read the `coding-workflows:project-context` skill and follow its protocol for resolving project context (reads workflow.yaml, auto-detects project settings, validates configuration). **If the skill file does not exist, STOP:** "Required skill `coding-workflows:project-context` not found. Ensure the coding-workflows plugin is installed."

**Command-specific overrides:**
- Use **Lightweight** auto-detect mode (no test/lint inference)

**DO NOT GUESS configuration values.** If a value cannot be read from workflow.yaml or confirmed via auto-detection, ask the user.

---

## Step 1: Fetch Issue and Plan

Parse `{{issue}}`:
- Plain number (e.g., `228`) -> use the default repo from resolved config
- With repo (e.g., `other-repo#10`) -> use as-is with the org from resolved config

```bash
gh issue view [NUMBER] --repo "{org}/{repo}" --json title,body,comments \
  --jq '{title, body, comments: [.comments[]? | select((.body // "") | test("## (Implementation Plan|Design Session|Plan Review|Plan Confirmed)"))]}'
```

> **Why `--jq`?** Later pipeline phases accumulate large comment histories. This filter keeps only comments containing pipeline-relevant headers, reducing payload size. The `(.body // "")` null-coalescing prevents crashes on bot-generated comments with null bodies. The `[]?` optional operator handles zero-comment issues gracefully.

**Find the plan:** Look for `## Implementation Plan` in comments.

**If no plan exists:** Stop and recommend `/coding-workflows:plan-issue {{issue}}` first.

---

## Step 2: Select Adversarial Reviewers

Scan `.claude/agents/*.md` for agent definitions. Read frontmatter to extract `name`, `description`, `domains`, `role`.

Match agents to what the plan touches:
- Compare plan content (files, components, domains) against agent `domains` arrays
- Prioritize agents with `role: reviewer` for adversarial dispatch
- If no agents found, proceed with a single adversarial review pass

**Always include the primary domain specialist + one cross-cutting reviewer** when agents are available.

---

## Step 2b: Multi-Round Dispatch Check

Before dispatching reviewers, evaluate:

1. **Reviewer count**: Are 2+ reviewers being dispatched?
2. **Conflict potential**: Check `deliberation.conflict_overrides` in workflow.yaml. If ANY reviewer pair has HIGH conflict, this condition is true.

If BOTH conditions are true, use multi-round dispatch:

**Check**: Is `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` set to `1`?
- **Yes**: Use agent-team dispatch (TeamCreate, SendMessage, persistent context)
  - If TeamCreate fails: log warning, fall back to Task-based dispatch
- **No**: Use Task-based multi-round dispatch (sequential Task calls with context bridging)

> For token cost and trade-off comparison between dispatch modes, see the **Dispatch Mode Comparison** section in `coding-workflows:deliberation-protocol`.

If EITHER condition is false:
- Use single-round Task dispatch

**When using multi-round dispatch**: Read `coding-workflows:deliberation-protocol` and follow its phases (Setup through Shutdown) in place of Steps 3-4. Resume at Step 5 after the protocol completes. If the skill file does not exist, fall back to single-round Task dispatch.

---

## Step 3: Adversarial Dispatch

**Note:** If multi-round dispatch was activated in Step 2b, the deliberation protocol replaces Steps 3-4. Do not execute them -- resume at Step 5.

> Adversarial reviewers CAN challenge each other's findings through the chair's cross-pollination in Round 2+.

If the plan involves security-relevant changes (authentication, authorization, input handling, dependency changes, secret management), include the `coding-workflows:security-patterns` skill as context for adversarial reviewers.

Invoke each specialist using the Task tool with `subagent_type` set to the agent name from frontmatter. Frame the prompt as adversarial critique:

```
Review this implementation plan as a CRITIC. Your job is to find problems.

**Issue:** [title]
**Requirements:** [from issue body]
**Plan:** [plan content]

Find problems:
1. What's missing or underspecified?
2. What edge cases will break this?
3. What happens when [X] fails? (pick 2-3 failure modes)
4. Any simpler approach that wasn't considered?
5. Will this actually meet the requirements?
6. Testing gaps?

Be constructively harsh. Better to find problems now than in code review.

End with:
### Verdict
- **Recommendation:** [Approve / Revise / Redesign]
- **Blocking issues:** [List, or "None"]
- **Important issues:** [List, or "None"]
```

---

## Step 4: Synthesize Findings

Collect specialist critiques and categorize:

| Severity | Meaning | Action |
|----------|---------|--------|
| **Blocking** | Plan will fail or miss requirements | Must fix before execute |
| **Important** | Significant gap or risk | Should fix |
| **Minor** | Nice-to-have improvement | Note for implementation |

---

## Step 5: Format Review Output

```markdown
## Plan Review

### Reviewers
| Specialist | Verdict | Key Concern |
|------------|---------|-------------|
| [name] | [Approve/Revise/Redesign] | [1-line summary] |

### Blocking Issues
- [ ] [Issue description] -- *raised by [specialist]*

### Important Issues
- [ ] [Issue description] -- *raised by [specialist]*

### Minor Suggestions
- [Suggestion] -- *raised by [specialist]*

### Overall Verdict: [Ready / Needs Revision / Needs Redesign]

[If not ready, specific guidance on what to fix]

---
*Adversarial review via `/coding-workflows:review-plan`*
```

---

## Step 6: Post Review to Issue

Before posting, check if a review comment already exists (look for `## Plan Review` header). Update rather than duplicate.

```bash
gh issue comment [NUMBER] --repo "{org}/{repo}" --body "REVIEW_OUTPUT"
```

---

## Step 7: Post Revised Plan (If Issues Found)

**If any Blocking or Important issues were raised**, generate and post a revised plan:

1. Address each issue raised
2. Post as a NEW comment with `## Implementation Plan (Revised)` header
3. Include explicit mapping of how each issue was addressed

```markdown
## Implementation Plan (Revised)

### Issues Addressed

| Issue | Severity | Resolution |
|-------|----------|------------|
| [Issue from review] | Blocking | [How plan now handles this] |
| [Issue from review] | Important | [How plan now handles this] |

### Updated Approach
[High-level description incorporating resolutions]

### Components
1. **[Component]**: [What and why - note changes from original]

### Files to Modify
- `path/to/file` - [change description]

### Testing Strategy
- Unit: [what to test - include new edge cases from review]
- Integration: [what to test]
- Edge cases: [specifically address reviewer concerns]

### Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| [from review] | [how addressed] |

---
*Revised plan addressing review feedback*
*Review: [link to review comment]*
```

```bash
gh issue comment [NUMBER] --repo "{org}/{repo}" --body "REVISED_PLAN"
```

**If plan was approved with no Blocking/Important issues**, post confirmation instead:

```markdown
## Plan Confirmed

Review complete. Original plan stands - no revisions needed.

Ready for: `/coding-workflows:execute-issue {{issue}}`
```

---

## Step 8: Report and STOP

### Preamble Cleanup

Remove the optimization cache file (if it exists). Handles both standalone `plan-issue -> review-plan` runs and `prepare-issue` pipeline runs.

```bash
rm -f /tmp/.coding-workflows-preamble-{issue}.yaml
```

Where `{issue}` is `{{issue}}` with `#` replaced by `-`.

### Report

```
**Review complete for {{issue}}**

Verdict: [Ready / Needs Revision / Needs Redesign]
Blocking issues: [count]
Important issues: [count]

Actions taken:
- Review posted: [link to review comment]
- [If revised] Revised plan posted: [link to revised plan comment]
- [If approved] Plan confirmed: [link to confirmation comment]

**Next steps:**
- [If ready/revised] `/coding-workflows:execute-issue {{issue}}`
- [If needs redesign] `/coding-workflows:design-session {{issue}}` to revisit approach
```

**STOP** - Do not proceed to execution.
