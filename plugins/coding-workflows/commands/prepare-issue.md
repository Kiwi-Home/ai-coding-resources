---
description: Full preparation pipeline with complexity triage. Routes to solo, lightweight, or full design session based on issue complexity (or explicit mode), then plan + review. Stops for human approval before execution.
args:
  issue:
    description: "Issue number (e.g., 228) or full reference (e.g., other-repo#10)"
    required: true
  mode:
    description: "Triage override: auto (triage decides, default), solo (lead only), lightweight (one specialist), or full (multi-specialist deliberation)"
    required: false
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

Complete preparation pipeline that takes an issue from requirements to execution-ready plan. Assesses issue complexity before the design session phase and routes to the appropriate depth.

**Pipeline:**
```
[Complexity Triage]  ->  Design Session (solo | lightweight | full)  ->  /clear  ->  /coding-workflows:plan-issue {{issue}} (includes review)
```

By the end, the issue will have:
1. Design session with architectural decisions (depth matches complexity)
2. Implementation plan with specialist input
3. Adversarial review of the plan
4. Revised plan addressing review feedback

---

## Step 0: Resolve Project Context (MANDATORY)

1. **Read config:** Use the Read tool to read `.claude/workflow.yaml`.
   - If file exists: extract all fields. Also read `project.remote` (default: `origin` if field is absent or empty). Use this as the identity remote name for any `git remote get-url` or `gh --repo` resolution. Proceed to step 3.
   - If file does not exist: proceed to step 2.

2. **Auto-detect (zero-config fallback):**
   - Run `git remote get-url origin` to extract org and repo name
   - Scan for project files to detect ecosystem
   - **CONFIRM with user:** "I detected [language] project [org/repo]. Is this correct?" DO NOT proceed without confirmation.

3. **Validate resolved context:**
   - `project.org` and `project.name` must be non-empty (stop if missing)
   - `git_provider` must be `github` (stop with message if not)
   - If `project.remote` is set to a non-empty value but `git remote get-url {remote}` fails: stop with error: "Configured remote '{remote}' not found. Run `git remote -v` to see available remotes, or update project.remote in .claude/workflow.yaml." Do NOT silently fall back to origin.

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

**Also stop if:**
- Issue already has a `## Design Session` comment (design phase already complete -- skip to Phase 2)

### Complexity Assessment

1. Read the `coding-workflows:complexity-triage` skill. If the skill file doesn't exist, proceed without it and note the missing skill.
2. **If `mode` arg is `solo`, `lightweight`, or `full`**: use it directly, skip auto-assessment. Report:
   ```
   Mode override: [MODE] (user-specified)
   ```
3. **If `mode` is `auto` or omitted**: evaluate issue against triage signals from the skill using ONLY the already-fetched issue data (no additional codebase scans). Check `planning.triage.default_mode` in workflow.yaml (if set and not `auto`, use as project default).
4. **If mode arg has an invalid value**: warn "Invalid mode '[value]'. Valid: auto, solo, lightweight, full." Default to auto and continue assessment.
5. Report the triage decision (informational, non-blocking):
   ```
   Complexity assessment: [SOLO | LIGHTWEIGHT | FULL]
   Signals: [1-line summary of key signals]
   -> Proceeding in [mode] mode

   To override: re-run with `/coding-workflows:prepare-issue [issue] full`
   ```

---

## Phase 1: Design Session

**Mode:** Determined by Complexity Assessment (or user override).

### If Solo Mode

Lead produces design session output directly using the solo output template
from the `coding-workflows:complexity-triage` skill:

1. Analyze the issue requirements, constraints, and acceptance criteria
2. Produce a `## Design Session` comment with all required sections:
   - Decision, Rationale, Specialist Input (lead self-assessment),
     Conflicts Resolved (N/A), Action Items, Open Questions
3. Post to issue via `gh issue comment`

**Completion signal:** `## Design Session` comment posted to issue.

### If Lightweight Mode

<!-- SYNC: lightweight dispatch mirrors design-session.md Steps 2a, 3, 6 -->

1. Discover agents per `coding-workflows:agent-patterns` skill
   (scan `.claude/agents/*.md`, read frontmatter, match domains)
2. Select the single most relevant specialist (best domain match)
3. **If no agents available:** degrade to solo mode with warning:
   ```
   No specialist agents found in .claude/agents/. Degrading from lightweight to solo mode.
   To enable lightweight mode, run /coding-workflows:generate-assets agents
   ```
4. Dispatch via Task with focused question and confidence assessment format
   (same dispatch template as design-session.md Step 3, but one specialist)
5. Synthesize specialist response into `## Design Session` output using the
   lightweight output template from the `coding-workflows:complexity-triage` skill
6. Post to issue via `gh issue comment`

**Completion signal:** `## Design Session` comment posted to issue.

### If Full Deliberation

Execute `/coding-workflows:design-session {{issue}}` (unchanged from current behavior)

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
| Invalid mode value | Warn with valid options, default to auto |
| Lightweight but no agents | Degrade to solo with warning |
| Sparse issue body (< 3 sentences) in auto mode | Default to full (insufficient info to triage safely) |
| Triage signals ambiguous in auto mode | Default to lightweight (err toward more process) |
| Issue already has `## Design Session` | Skip Phase 1 entirely, proceed to Phase 2 |
| Design session fails to post | Stop, report error, don't proceed to planning |
| Plan fails to post | Stop, report error, don't proceed to review |
| Review fails to post | Report partial completion, note what's missing |
| Issue closed mid-pipeline | Stop, report that issue was closed |

**Recovery:** If pipeline fails partway, check what's already posted to the issue and resume from there:
- Has design session but no plan? -> `/coding-workflows:plan-issue {{issue}}`
- Has plan but no review? -> `/coding-workflows:review-plan {{issue}}`
- Solo/lightweight proved insufficient? -> Delete the `## Design Session` comment on the issue and re-run with explicit mode: `/coding-workflows:prepare-issue {{issue}} full`

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
- Chair decisions are binding on the plan regardless of design session mode
- Review critiques are addressed in the revised plan
- Context is cleared to prevent token exhaustion on complex issues
- Mode override bypasses auto-triage: `/coding-workflows:prepare-issue 228 solo`
