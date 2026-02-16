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
[Complexity Triage]  ->  Design Session (solo | lightweight | full)
                              |
                        [if solo + guard rails pass]
                              |-> Solo Plan Derivation -> DONE
                              |
                        [otherwise]
                              |-> /clear -> /coding-workflows:plan-issue {{issue}} (includes review)
```

By the end, the issue will have:
1. Design session with architectural decisions (depth matches complexity)
2. Implementation plan (specialist-reviewed, or derived from design session for solo shortcut)
3. Adversarial review of the plan (or plan confirmation for solo shortcut)
4. Revised plan addressing review feedback (if applicable)

---

## Step 0: Resolve Project Context (MANDATORY)

Read the `coding-workflows:project-context` skill and follow its protocol for resolving project context (reads workflow.yaml, auto-detects project settings, validates configuration). **If the skill file does not exist, STOP:** "Required skill `coding-workflows:project-context` not found. Ensure the coding-workflows plugin is installed."

**Command-specific overrides:**
- Use **Lightweight** auto-detect mode (no test/lint inference)

**DO NOT GUESS configuration values.** If a value cannot be read from workflow.yaml or confirmed via auto-detection, ask the user.

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
- Issue already has a `## Plan Confirmed` comment (already prepared -- stop entirely)
- Issue already has `## Implementation Plan (Revised)` (already prepared)
- Issue lacks clear requirements (recommend writing requirements first)

**Also skip Phase 1 if:**
- Issue already has a `## Design Session` comment (design phase already complete -- skip to Phase 2)

### Complexity Assessment

1. Read the `coding-workflows:complexity-triage` skill. If the skill file doesn't exist, proceed without it and note the missing skill.
2. **If `mode` arg is `solo`, `lightweight`, or `full`**: use it directly, skip auto-assessment. Report:
   ```
   Mode override: [MODE] (user-specified)
   Mode source: user-override
   ```
3. **If `mode` is `auto` or omitted**: evaluate issue against triage signals from the skill using ONLY the already-fetched issue data (no additional codebase scans). Check `planning.triage.default_mode` in workflow.yaml (if set and not `auto`, use as project default).
4. **If mode arg has an invalid value**: warn "Invalid mode '[value]'. Valid: auto, solo, lightweight, full." Default to auto and continue assessment.
5. Report the triage decision (informational, non-blocking):
   ```
   Complexity assessment: [SOLO | LIGHTWEIGHT | FULL]
   Signals: [1-line summary of key signals]
   Mode source: auto-triage
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
     Conflicts Resolved (N/A), Action Items, Files to Modify,
     Testing Strategy, Open Questions
3. Post to issue via `gh issue comment`

#### Solo Shortcut Evaluation

After posting the design session, evaluate whether the solo shortcut applies.

**Eligibility:** The shortcut is ONLY available when `Mode source:` is `auto-triage`.
It does NOT activate when:
- The user overrode mode to `solo` (the user chose a lighter design session,
  not necessarily lighter planning)
- Lightweight mode degraded to solo due to missing agents

**Guard rails (all must pass):**
1. `Mode source:` label from triage report output (Complexity Assessment or lightweight degradation message) is `auto-triage` (not `user-override`, not `degraded`)
2. Open Questions section contains only "None." (no unresolved questions)
3. Action Items (Separate Issue Required) contains only "None identified."
4. Specialist Input confidence is not "Low"
5. Files to Modify and Testing Strategy sections are non-empty
   (not blank, not "TBD", not "TODO", not "N/A", not template placeholder text
   like `[change description]` or `[Testing approach...]`)

**If ALL pass:** Proceed to Solo Plan Derivation below.
**If ANY fail:** Continue to Phase 1-2 Transition (standard path).
When guard rails fail, the standard prepare-issue flow continues from the
next section as if the shortcut did not exist.

Note: Guard rails 2-5 are checked against the lead's own output
(self-certification). This is an accepted trade-off for solo-tier issues:
the triage iron rule ("when uncertain, choose higher process") and signal
precedence rule ("any Full-tier signal overrides Solo") prevent solo
classification of non-trivial issues. For issues where the design session
reveals unexpected complexity, the lead should write open questions or
low-confidence assessments, which will naturally fail the guard rails.

#### Solo Plan Derivation

After the Design Session comment, generate a second comment containing both
the derived `## Implementation Plan` and the `## Plan Confirmed` marker.
Post as ONE `gh issue comment` call to eliminate partial-failure risk.

**Derived plan template:**

~~~markdown
## Implementation Plan

*Derived from solo design session (shortcut). See Design Session comment
for full rationale.*

### Approach
[Copied from Decision section of design session]

### Files to Modify

| File | Change |
|------|--------|
[Copied from Files to Modify section of design session, using table format
without Layer column — ensures execute-issue defaults to sequential execution]

### Testing Strategy
[Copied from Testing Strategy section of design session]

### Action Items
[Copied from Action Items (Inline) section of design session]

---
*Solo plan derivation via `/coding-workflows:prepare-issue` — specialist
planning and adversarial review skipped per complexity triage.*

---

## Plan Confirmed

Plan confirmed (solo shortcut). Derived from solo design session — no specialist
planning or adversarial review required for this complexity level.

Ready for: `/coding-workflows:execute-issue {{issue}}`
~~~

Post via `gh issue comment`. Skip Phase 1-2 Transition and Phase 2.
Proceed directly to Solo Final Report.

**Completion signal:** `## Implementation Plan` + `## Plan Confirmed`
posted to issue in a single comment.

### If Lightweight Mode

<!-- SYNC: lightweight dispatch mirrors design-session.md Steps 2a, 3, 6 -->

1. Discover agents per `coding-workflows:agent-patterns` skill
   (scan `.claude/agents/*.md`, read frontmatter, match domains)
2. Select the single most relevant specialist (best domain match)
3. **If no agents available:** degrade to solo mode with warning:
   ```
   No specialist agents found in .claude/agents/. Degrading from lightweight to solo mode.
   Mode source: degraded
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

### Preamble Emission (optimization cache)

Write resolved project context to `/tmp/.coding-workflows-preamble-{issue}.yaml` (where `{issue}` is `{{issue}}` with `#` replaced by `-`) so that `plan-issue` can skip redundant context resolution after `/clear`. **If the write fails** (permissions, disk full, etc.), **log a warning and continue** — `plan-issue` falls back to full protocol.

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

### Preamble Cleanup

Remove the optimization cache file (if it exists). This is a no-op if the file was never written or was already cleaned up by `review-plan`.

```bash
rm -f /tmp/.coding-workflows-preamble-{issue}.yaml
```

Where `{issue}` is `{{issue}}` with `#` replaced by `-`.

### Report

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

### Solo Final Report

If solo shortcut was used, report instead of the standard Final Report:

```
Issue {{issue}} prepared for execution (solo shortcut)

**Pipeline completed:**
- [x] Design session (solo assessment)
- [x] Implementation plan (derived from design session)
- [x] Plan confirmed (no adversarial review needed)
- [ ] ~~Specialist planning~~ (skipped — solo shortcut)
- [ ] ~~Adversarial review~~ (skipped — solo shortcut)

**Issue now has:**
- Solo design session with architectural decisions
- Derived implementation plan (files, testing strategy, action items)
- Plan confirmation marker

**Ready for:** `/coding-workflows:execute-issue {{issue}}`

**Note:** Solo shortcut used. If execution reveals unexpected complexity,
re-prepare with: `/coding-workflows:prepare-issue {{issue}} full`
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
| Solo shortcut guard rail fails | Continue to Phase 1-2 Transition (standard path). Note: "Solo shortcut bypassed — proceeding to full planning." |
| Solo plan derivation fails to post | Stop, report error. Design session is already posted; issue is in "Phase 1 complete, Phase 2 pending" state. User can resume with `/coding-workflows:plan-issue {{issue}}` |
| Solo mode via user override (not auto-triage) | Shortcut does not activate. Continue to Phase 1-2 Transition. |
| Lightweight degraded to solo | Shortcut does not activate (`Mode source: degraded`). Continue to Phase 1-2 Transition. |

**Recovery:** If pipeline fails partway, check what's already posted to the issue and resume from there:
- Has design session but no plan? -> `/coding-workflows:plan-issue {{issue}}`
- Has plan but no review? -> `/coding-workflows:review-plan {{issue}}`
- Solo/lightweight proved insufficient? -> Delete the `## Design Session` comment on the issue and re-run with explicit mode: `/coding-workflows:prepare-issue {{issue}} full`
- Has solo-derived plan + Plan Confirmed but execution revealed unexpected
  complexity? -> Delete both comments (Design Session, and the combined
  Implementation Plan + Plan Confirmed comment) and re-run:
  `/coding-workflows:prepare-issue {{issue}} full`

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
