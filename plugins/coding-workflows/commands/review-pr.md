---
description: Review a pull request for quality, compliance, and merge readiness using severity-tiered findings
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
   - If file exists: extract all fields. Also read `project.remote` (default: `origin` if field is absent or empty). Use this as the identity remote name for any `git remote get-url` or `gh --repo` resolution. Proceed to validation.
   - If file does not exist: auto-detect below.

2. **Auto-detect (zero-config fallback):**
   - Run `git remote get-url origin` to extract org and repo name
   - Scan for project files: `pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod`, `Gemfile`
   - Read the `coding-workflows:stack-detection` skill to detect ecosystem (language + framework)
   - **CONFIRM with user:** "I detected [language] project [org/repo] with ecosystem `[detected]`. Is this correct?" DO NOT proceed without confirmation.

3. **Validate resolved context:**
   - `project.org` and `project.name` must be non-empty (stop if missing)
   - `git_provider` must be `github` (stop with message if not)
   - If `project.remote` is set to a non-empty value but `git remote get-url {remote}` fails: stop with error: "Configured remote '{remote}' not found. Run `git remote -v` to see available remotes, or update project.remote in .claude/workflow.yaml." Do NOT silently fall back to origin.

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

Read the `coding-workflows:pr-review` skill to obtain the iteration mode threshold value. If the skill file doesn't exist, proceed without it and note the missing skill.

**Count previous review comments:**

```bash
gh pr view {pr} --repo {org}/{repo} --json comments --jq '[.comments[] | select(.author.login == "claude[bot]" and (.body | contains("<!-- content-review-iteration:")))] | length'
```

Calculate iteration = count + 1.

**Threshold** (from skill): iterations 1-3 = COMPREHENSIVE, 4+ = VERIFICATION.

**Failure handling** (non-zero exit, empty output, non-numeric value from the count query):

Do NOT silently default to iteration 1. Instead, run a simpler fallback query to check whether any `claude[bot]` comments exist at all:

```bash
gh pr view {pr} --repo {org}/{repo} --json comments --jq '[.comments[] | select(.author.login == "claude[bot]")] | length'
```

- If this fallback returns a non-zero count: previous reviews exist but iteration counting failed. Default to **VERIFICATION mode** (iteration = threshold value) to avoid duplicating a comprehensive review.
- If this fallback returns zero or also fails: no prior reviews detected. Default to iteration 1 (COMPREHENSIVE).

**Emit header as a unit** (HTML comment marker + visible header):

Normal:
```
<!-- content-review-iteration:N -->
**[Content Review] Review iteration: N | Mode: COMPREHENSIVE**
```

Failure (no prior reviews detected):
```
<!-- content-review-iteration:1 -->
**[Content Review] Review iteration: 1 | Mode: COMPREHENSIVE** _(iteration count unavailable; no prior reviews detected)_
```

Failure (prior reviews exist):
```
<!-- content-review-iteration:T -->
**[Content Review] Review iteration: T | Mode: VERIFICATION** _(iteration count unavailable; prior reviews detected, defaulting to VERIFICATION)_
```
Where T = the threshold value from the skill (currently 4).

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

Read the `coding-workflows:pr-review` skill for the universal review framework. If the skill file doesn't exist, proceed without it and note the missing skill.

**Look for project-specific review config:**
- If `.claude/review-config.yaml` exists: apply project-specific focus areas, anti-patterns, and conventions alongside the universal framework
- If `.claude/review-config.yaml` is missing: apply the skill's universal category definitions only. Note in review header: "Project review config not found. Run `/coding-workflows:generate-assets review-config` for targeted review."

**Apply review focus by mode:**
- **COMPREHENSIVE mode**: All four universal categories (Correctness, Integrity, Compliance, Quality) + any project-specific focus from review config
- **VERIFICATION mode**: Only verify previous MUST FIX items are fixed + flag regressions in newly changed lines. Do NOT raise new editorial concerns.

**Categorize all findings** by severity tier (from skill): MUST FIX, FIX NOW, CREATE ISSUE.

**CRITICAL: Do NOT create any GitHub issues during this step.** Collect and classify all findings. Issue creation happens exclusively in Step 7. Creating issues during review steps is a workflow violation.

**Apply finding disposition framework** (from skill) for FIX NOW vs CREATE ISSUE classification.

**Apply finding validation gate** (from skill) before classifying any finding as CREATE ISSUE.

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

1. **Deduplication check** (before creating anything):
   ```bash
   gh issue list --repo {org}/{repo} --label review-followup --state open --search "PR #{pr}" --json number,title,body
   ```
   - If result contains an issue whose body includes `PR #{pr_number}`: this PR already has a follow-up issue. Append new findings as a comment on that issue:
     ```bash
     gh issue comment {existing_issue_number} --repo {org}/{repo} --body "Additional findings from review iteration {N}:\n\n{new findings}"
     ```
     Skip to step 5 (reference in review comment).
   - If no matching issue found: proceed to step 2.
   - If query fails (non-zero exit after retry): skip dedup and proceed directly to step 2 (create issue). Add note in the issue body: "Created without dedup verification — may duplicate an existing follow-up issue for this PR. Check for duplicates and consolidate if needed." Add note in the review comment: "Follow-up issue created without dedup verification (query failed). Check for duplicate follow-up issues."

2. Ensure label exists:
   ```bash
   gh label create review-followup --description "Non-trivial findings from content review" --color "D4A017" --repo {org}/{repo} 2>/dev/null || true
   ```

3. Group ALL CREATE ISSUE findings from this review

4. Create ONE consolidated issue using template from skill:
   ```bash
   gh issue create --repo {org}/{repo} --title "[Content Review] <overall theme>" --label "review-followup" --body "<issue body>"
   ```

5. Reference the issue number (new or existing) in your review comment

**Failure modes:**
- Deduplication query fails → skip dedup, create issue directly (may duplicate; safe fallback)
- Label creation fails → proceed without label
- Issue creation fails → post review with error note listing findings inline
- Issue comment (append) fails → create a new issue instead (degraded dedup)

**MANDATORY:** A review that lists CREATE ISSUE findings without creating or appending to an issue is incomplete.

---

## Step 8: Post Review Comment

Format review body with: iteration marker, mode header, findings by severity, finding disposition summary, issue compliance results (if applicable), exit determination, and CREATE ISSUE reference (if applicable).

**Finding disposition summary** (include after findings by severity):
```markdown
### Finding Disposition
- **FIX NOW** ([N] findings): [brief list - these should be fixed in the current PR]
- **CREATE ISSUE** ([N] findings): [brief list - tracked in #{issue_number}]
```

```bash
gh pr comment {pr} --repo {org}/{repo} --body "{review}"
```

If posting fails: retry once after 5 seconds. If still fails: output review content to stdout and STOP with error.

**Error handling (systematic):** All `gh` commands in this workflow: if non-zero exit, retry once after 2 seconds. If still fails: fatal for PR fetch (Step 1), graceful degradation for all other steps.
