---
description: Review a pull request for quality, compliance, and merge readiness
args:
  pr:
    description: "PR number (e.g., 42) or full reference (e.g., other-repo#10)"
    required: true
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Task
---

# Review PR: {{pr}}

## Step 0: Resolve Project Context

1. Use the Read tool to read `.claude/workflow.yaml`.
   - If file exists: extract all fields. Proceed to validation.
   - If file does not exist: auto-detect below.

2. **Auto-detect (zero-config fallback):**
   - Run `git remote get-url origin` to extract org and repo name
   - Scan for project files: `pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod`, `Gemfile`
   - Read the `coding-workflows:stack-detection` skill to detect ecosystem (language + framework)
   - **CONFIRM with user:** "I detected [language] project [org/repo] with ecosystem `[detected]`. Is this correct?" DO NOT proceed without confirmation.

3. **Validate resolved context:**
   - `project.org` and `project.name` must be non-empty (stop if missing)
   - `git_provider` must be `github` (stop with message if not)

4. **Store resolved ecosystem identifier** for use in Step 4 resource lookup.

**DO NOT GUESS configuration values.** If a value cannot be read from workflow.yaml or confirmed via auto-detection, ask the user.

---

## Step 1: Fetch PR Metadata

Parse `{{pr}}` — if it contains `#`, split into `repo#number`; otherwise use resolved `{org}/{repo}` with `{{pr}}` as the number.

```bash
gh pr view {pr} --repo {org}/{repo} --json title,body,files,comments
gh pr diff {pr} --repo {org}/{repo}
```

Extract linked issue from body: match `Closes #N`, `Fixes #N`, or `Resolves #N` patterns. If multiple issues linked, use the first as primary.

**Error:** If PR does not exist or `gh pr view` fails after one retry, STOP with error message.

---

## Step 2: Determine Review Mode

Read the `coding-workflows:pr-review` skill to obtain the iteration mode threshold value.

**Count previous review comments:**

```bash
gh pr view {pr} --repo {org}/{repo} --json comments --jq '[.comments[] | select(.author.login == "claude[bot]" and (.body | contains("<!-- content-review-iteration:")))] | length'
```

Calculate iteration = count + 1.

**Threshold** (from skill): iterations 1-3 = COMPREHENSIVE, 4+ = VERIFICATION.

**Failure modes** (non-zero exit, empty output, non-numeric value): default to iteration 1.

**Emit header as a unit** (HTML comment marker + visible header):

Normal:
```
<!-- content-review-iteration:N -->
**[Content Review] Review iteration: N | Mode: COMPREHENSIVE**
```

Failure:
```
<!-- content-review-iteration:1 -->
**[Content Review] Review iteration: 1 | Mode: COMPREHENSIVE** _(iteration detection unavailable; defaulting to 1)_
```

Note: no space after the colon in the marker — `content-review-iteration:N`, not `content-review-iteration: N`.

---

## Step 3: Read Changed Files

For each changed file identified from the diff, read FULL content using the Read tool (not just the diff). Full-file reading is critical because a change to one line may contradict instructions elsewhere in the file.

**File-status handling** (reference patterns from skill):

| Condition | Action |
|-----------|--------|
| Deleted (all lines removed in diff, or Read fails with "not found") | Skip content review. Grep for orphaned references to the deleted filename. |
| Renamed (rename markers in diff) | Read at the new path. Verify cross-references in other changed files use the new name. |
| Binary ("Binary files differ" in diff, or Read returns non-text content) | Skip content review. Note the file in your review. |
| Added or modified | Read the complete file at its current path. |

**Edge cases:**
- No reviewable files (all deleted/binary) → post "No reviewable content in this PR" and STOP
- Large PR (50+ files) → warn in review header, proceed with best effort
- `gh pr diff` fails → use `gh pr view {pr} --repo {org}/{repo} --json files --jq '.files[].path'` as fallback. In fallback mode, determine file status from Read results (success = exists, failure = likely deleted).

---

## Step 4: Perform Review

Read the `coding-workflows:pr-review` skill for the universal review framework.

**Look for project-specific review config:**
- If `.claude/review-config.yaml` exists: apply project-specific focus areas, anti-patterns, and conventions alongside the universal framework
- If `.claude/review-config.yaml` is missing: apply the skill's universal category definitions only. Note in review header: "Project review config not found. Run `/coding-workflows:generate-assets review-config` for targeted review."

**Apply review focus by mode:**
- **COMPREHENSIVE mode**: All four universal categories (Correctness, Integrity, Compliance, Quality) + any project-specific focus from review config
- **VERIFICATION mode**: Only verify previous MUST FIX items are fixed + flag regressions in newly changed lines. Do NOT raise new editorial concerns.

**Categorize all findings** by severity tier (from skill): MUST FIX, FIX NOW, CREATE ISSUE.

**Apply trivial check** decision framework (from skill) for FIX NOW vs CREATE ISSUE classification.

---

## Step 5: Issue Compliance Check (COMPREHENSIVE mode only)

If in VERIFICATION mode, skip this step entirely.

If a linked issue was found in Step 1:

```bash
gh issue view {N} --repo {org}/{repo} --json body --jq '.body'
```

- Extract acceptance criteria from issue body
- Verify each is addressed in the PR changes
- Flag Missing as MUST FIX, Partial as FIX NOW
- If issue fetch fails → skip with note in review

If no linked issue found, skip this section entirely with a note.

---

## Step 6: Determine Exit Criteria

Apply strict exit rules from skill:
- Zero MUST FIX + zero FIX NOW + all CREATE ISSUE items filed → "Ready to merge"
- If ANY items remain unresolved → "Not ready to merge. [N] items remain: [list them]"

**NEVER use qualified approval language:**
- "Ready to merge once items are addressed" — NO
- "LGTM with minor changes" — NO
- "Approved pending X" — NO

---

## Step 7: CREATE ISSUE Protocol

If any CREATE ISSUE findings exist:

1. Ensure label exists:
   ```bash
   gh label create review-followup --description "Non-trivial findings from content review" --color "D4A017" --repo {org}/{repo} 2>/dev/null || true
   ```

2. Group ALL CREATE ISSUE findings from this review

3. Create ONE consolidated issue using template from skill:
   ```bash
   gh issue create --repo {org}/{repo} --title "[Content Review] <overall theme>" --label "review-followup" --body "<issue body>"
   ```

4. Reference the issue number in your review comment

**Failure modes:**
- Label creation fails → proceed without label
- Issue creation fails → post review with error note: "Failed to create follow-up issue — CREATE ISSUE findings listed below but not tracked"

**MANDATORY:** A review that lists CREATE ISSUE findings without creating the issue is incomplete.

---

## Step 8: Post Review Comment

Format review body with: iteration marker, mode header, findings by severity, issue compliance results (if applicable), exit determination, and CREATE ISSUE reference (if applicable).

```bash
gh pr comment {pr} --repo {org}/{repo} --body "{review}"
```

If posting fails: retry once after 5 seconds. If still fails: output review content to stdout and STOP with error.

**Error handling (systematic):** All `gh` commands in this workflow: if non-zero exit, retry once after 2 seconds. If still fails: fatal for PR fetch (Step 1), graceful degradation for all other steps.
