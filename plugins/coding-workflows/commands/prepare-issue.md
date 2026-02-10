---
description: Full preparation pipeline - design session, plan, review, revised plan
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

# Prepare Issue for Execution: {{issue}}

Complete preparation pipeline that takes an issue from requirements to execution-ready plan.

**Pipeline:**
```
/coding-workflows:design-session {{issue}}  ->  /clear  ->  /coding-workflows:plan-issue {{issue}} (includes review)
```

By the end, the issue will have:
1. Design session with architectural decisions
2. Implementation plan with specialist input
3. Adversarial review of the plan
4. Revised plan addressing review feedback

---

## Step 0: Resolve Project Context (MANDATORY)

1. **Read config:** Use the Read tool to read `.claude/workflow.yaml`.
   - If file exists: extract all fields. Proceed to step 3.
   - If file does not exist: proceed to step 2.

2. **Auto-detect (zero-config fallback):**
   - Run `git remote get-url origin` to extract org and repo name
   - Scan for project files to detect ecosystem
   - **CONFIRM with user:** "I detected [language] project [org/repo]. Is this correct?" DO NOT proceed without confirmation.

3. **Validate resolved context:**
   - `project.org` and `project.name` must be non-empty (stop if missing)
   - `git_provider` must be `github` (stop with message if not)

**DO NOT GUESS configuration values.**

---

## Pre-flight Check

Parse `{{issue}}`:
- Plain number (e.g., `228`) -> use the default repo from resolved config
- With repo (e.g., `other-repo#10`) -> use as-is with the org from resolved config

```bash
gh issue view [NUMBER] --repo "{org}/{repo}" --json title,body,labels,state
```

**Stop if:**
- Issue is closed
- Issue already has `## Implementation Plan (Revised)` (already prepared)
- Issue lacks clear requirements (recommend writing requirements first)

---

## Phase 1: Design Session

Execute the full `/coding-workflows:design-session` workflow for `{{issue}}`:

1. Parse and gather context
2. Frame the session
3. Discover and dispatch 2-4 specialists based on issue domain
4. Collect findings and detect conflicts
5. Resolve conflicts using confidence-weighted resolution
6. Synthesize output
7. **Post to issue** with `## Design Session` header

**Completion signal:** Design session comment posted to issue.

---

## Phase 1-2 Transition

```
Design session complete for {{issue}}

Posted architectural decisions to issue.

Clearing context before planning phase...
```

**Execute:** `/clear`

---

## Phase 2: Implementation Planning + Review

Execute the full `/coding-workflows:plan-issue` workflow for `{{issue}}`.

**Note:** `/coding-workflows:plan-issue` automatically chains into `/coding-workflows:review-plan`, so this phase covers:

### Planning
1. Read the `coding-workflows:issue-workflow` skill
2. Fetch issue (will see chair session in comments)
3. Extract chair decisions as binding constraints
4. Select 1-2 specialists for planning input
5. Draft plan aligned with chair decisions
6. Invoke specialists for feedback
7. Incorporate feedback
8. Format final plan
9. **Post to issue** with `## Implementation Plan` header

### Auto-transition
10. Clear context

### Review
11. Fetch issue and find the plan
12. Select 1-2 adversarial reviewers
13. Dispatch with adversarial prompts
14. Synthesize findings by severity
15. **Post review to issue** with `## Plan Review` header
16. If issues found: **Post revised plan** with `## Implementation Plan (Revised)`
17. If approved: **Post confirmation**

**Completion signal:** Review and (if needed) revised plan posted to issue.

---

## Final Report

```
Issue {{issue}} prepared for execution

**Pipeline completed:**
- [x] Design session
- [x] Implementation plan
- [x] Adversarial review
- [x] Revised plan (if needed)

**Issue now has:**
- Architectural decisions documented
- Specialist-reviewed implementation plan
- Known risks and mitigations

**Ready for:** `/coding-workflows:execute-issue {{issue}}`

**Execution will require:**
- Verification gate (fresh test/linter evidence before commit)
- Spec compliance check (nothing missing, nothing extra)
- CI + review loop (up to 3 iterations)
```

---

## Error Handling

| Error | Action |
|-------|--------|
| Chair session fails to post | Stop, report error, don't proceed to planning |
| Plan fails to post | Stop, report error, don't proceed to review |
| Review fails to post | Report partial completion, note what's missing |
| Issue closed mid-pipeline | Stop, report that issue was closed |

**Recovery:** If pipeline fails partway, check what's already posted to the issue and resume from there:
- Has design session but no plan? -> `/coding-workflows:plan-issue {{issue}}`
- Has plan but no review? -> `/coding-workflows:review-plan {{issue}}`

---

## Calling Individual Steps

If you need finer control or to resume partway:

| Command | When to Use |
|---------|-------------|
| `/coding-workflows:design-session {{issue}}` | Just design discussion, no plan |
| `/coding-workflows:plan-issue {{issue}}` | Plan + review (skips chair) |
| `/coding-workflows:review-plan {{issue}}` | Just review existing plan |

---

## Notes

- Each phase fetches the issue fresh, so `/clear` between phases is safe
- Chair decisions are binding on the plan
- Review critiques are addressed in the revised plan
- Context is cleared to prevent token exhaustion on complex issues
