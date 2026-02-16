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

## Step 0: Resolve Project Context (MANDATORY)

Read the `coding-workflows:project-context` skill and follow its protocol for resolving project context (reads workflow.yaml, auto-detects project settings, validates configuration). **If the skill file does not exist, STOP:** "Required skill `coding-workflows:project-context` not found. Ensure the coding-workflows plugin is installed."

**Command-specific overrides:**
- Use **Ecosystem** auto-detect mode (reads `coding-workflows:stack-detection` for ecosystem detection)
- Store the resolved ecosystem identifier for use in Step 4 resource lookup

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

**Security review lens:**

Read the `coding-workflows:security-patterns` skill. If the skill file doesn't exist, proceed without it and note the missing skill.

If the skill was loaded, evaluate its Activation Criteria against the changed file list from Step 3. If criteria are met, apply the skill's Security Review Framework and Quick Reference alongside the universal review categories. Security findings use the skill's Severity Graduation Criteria to determine tier classification. If no activation criteria match, note "Security review: not activated (no security-relevant files in diff)" and proceed.

**Apply review focus by mode:**
- **COMPREHENSIVE mode**: All four universal categories (Correctness, Integrity, Compliance, Quality) + any project-specific focus from review config + security review lens (if activated)
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

Apply the Exit Criteria from the `coding-workflows:pr-review` skill (already read in Step 4). The skill defines the strict bright-line rules for merge readiness and the prohibition on qualified approval language.

---

## Step 7: CREATE ISSUE Protocol

If any CREATE ISSUE findings exist, follow the CREATE ISSUE Protocol per `coding-workflows:pr-review` (already read in Step 4). Use `{org}/{repo}` and `{pr}` from resolved context.

**Orchestration steps:**

1. **Deduplication check** (before creating anything):
   ```bash
   gh issue list --repo {org}/{repo} --label review-followup --state open --search "PR #{pr}" --json number,title,body
   ```
   - Matching issue found (body contains `PR #{pr_number}`): append as comment
   - No match: create new issue using template from skill
   - Query fails: skip dedup, create directly (add dedup failure note per skill)

2. **Ensure label:**
   ```bash
   gh label create review-followup --description "Non-trivial findings from content review" --color "D4A017" --repo {org}/{repo} 2>/dev/null || true
   ```

3. **Create/append** using issue body template from skill

4. **Reference** created issue number in review comment

**Failure modes:**
- Deduplication query fails -> skip dedup, create directly
- Label creation fails -> proceed without label
- Issue creation fails -> post review with error note listing findings inline
- Comment (append) fails -> create new issue (degraded dedup)

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
