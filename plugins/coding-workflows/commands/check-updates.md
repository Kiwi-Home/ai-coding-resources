---
description: Check upstream dependencies for new releases and changelog updates; produces a local markdown digest with change tiers
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - WebFetch
  - Write
args:
  sources:
    description: "Path to sources config (default: .claude/upstream-sources.yaml)"
    required: false
---

# Check Updates

Check upstream dependencies for new releases and changelog updates. Produces a markdown digest classifying changes by tier (major, minor, changed) and suggests potentially affected skills and agents.

This is a utility command -- no agent discovery, no GitHub posting. It reads a standalone config, fetches upstream state, compares against persisted state, and reports.

**Terminology:** "Change tiers" (major/minor/changed) are distinct from `coding-workflows:pr-review` severity tiers (MUST FIX / FIX NOW / CREATE ISSUE). Change tiers classify upstream dependency movement; severity tiers classify PR review findings.

---

## Step 0: Load Sources Configuration

Read the sources config file at `{{sources}}` (default: `.claude/upstream-sources.yaml`).

**If missing:** Stop with guidance:
```
No sources config found at {path}.

Create one from the template:
  cp plugins/coding-workflows/templates/upstream-sources.yaml .claude/upstream-sources.yaml

Then edit to add your upstream dependencies.
```

**Validate each source entry:**

| Check | Action |
|-------|--------|
| Missing `name` | Skip with warning: "Source entry missing `name` field. Skipping." |
| Missing `type` | Skip with warning: "Source `{name}` missing `type` field. Skipping." |
| Unknown `type` | Skip with warning: "Unknown source type `{type}` for `{name}`. Supported: github-release, npm, pypi, changelog-url." |
| Missing type-specific required field | Skip with warning: "Source `{name}` missing required field `{field}`." |

**Required fields per type:**

| Type | Required | Optional |
|------|----------|----------|
| `github-release` | `name`, `type`, `repo` | `relevance`, `affects` |
| `npm` | `name`, `type`, `package` | `relevance`, `affects` |
| `pypi` | `name`, `type`, `package` | `relevance`, `affects` |
| `changelog-url` | `name`, `type`, `url` | `relevance`, `affects` |

**Not yet supported:** RSS/Atom feeds. Feed parsing requires XML handling and entry-level change detection that adds complexity beyond the current scope. Can be added in a future iteration if demand materializes.

**`repo: self` resolution** (for `github-release` type only):
1. Read `.claude/workflow.yaml` -> extract `project.org` / `project.name`. Also read `project.remote` (default: `origin` if field is absent or empty).
2. If workflow.yaml missing: run `git remote get-url origin` -> parse org/repo
3. If both fail: ask user for org/repo
4. Substitute resolved `{org}/{name}` into the source entry

If `project.remote` is set to a non-empty value but `git remote get-url {remote}` fails in the fallback path (step 2): stop with error: "Configured remote '{remote}' not found. Run `git remote -v` to see available remotes, or update project.remote in .claude/workflow.yaml." Do NOT silently fall back to origin.

**`affects` field** (optional, all types): Array of asset names for guaranteed matching in Step 4. Bypasses keyword-bag heuristic for this source.

```yaml
- name: pydantic
  type: pypi
  package: pydantic
  relevance: "Data validation across all services"
  affects: [api-patterns, lora-training-mlx, api-reviewer]
```

---

## Step 1: Load Persisted State

Read `.claude/upstream-state.json`.

| Condition | Action |
|-----------|--------|
| File missing | "No existing state found. Will create initial baseline after fetching." -> empty state, set `first_run = true` |
| Invalid JSON | "State file corrupted. Treating as first run." -> empty state, set `first_run = true` |
| `state_version` mismatch (not `1`) | "State file from older schema. Resetting." -> empty state, set `first_run = true` |
| Valid, individual source malformed | Preserve valid sources, drop malformed ones, warn per source |
| Valid | Load state, set `first_run = false` |

**State file schema:**

```json
{
  "state_version": 1,
  "last_run": "2026-02-14T10:30:00Z",
  "sources": {
    "mlx-lm": {
      "last_version": "v0.35.0",
      "last_checked": "2026-02-14T10:30:00Z",
      "content_hash": null,
      "release_url": "https://github.com/ml-explore/mlx-lm/releases/tag/v0.35.0"
    },
    "claude-code-docs": {
      "last_version": null,
      "last_checked": "2026-02-14T10:30:00Z",
      "content_hash": "sha256:abc123...",
      "release_url": "https://docs.anthropic.com/en/docs/claude-code/changelog"
    }
  }
}
```

---

## Step 2: Fetch Updates

Process each validated source sequentially.

| Type | Endpoint | Extract |
|------|----------|---------|
| `github-release` | `curl -s "https://api.github.com/repos/{owner}/{repo}/releases/latest"` | `.tag_name`, `.body` (first 200 chars), `.html_url` |
| `npm` | `curl -s "https://registry.npmjs.org/{package}"` | `.["dist-tags"].latest`, `.description`, URL: `https://www.npmjs.com/package/{package}` |
| `pypi` | `curl -s "https://pypi.org/pypi/{package}/json"` | `.info.version`, `.info.summary`, URL: `https://pypi.org/project/{package}/` |
| `changelog-url` | `WebFetch` the URL (fallback: `curl -sL`); compute SHA-256 of content | content hash, URL itself as link |

**Per-source error handling:**

| Error | Action |
|-------|--------|
| Timeout (>10s) | Mark `status: failed`, reason: "Timed out" |
| HTTP 404 (`github-release`) | Mark `status: failed`, reason: "No releases found. Repo may use tags only." |
| HTTP 403 with rate limit headers | Report `X-RateLimit-Remaining` and reset time. Mark `status: failed`. **Stop processing further github-release sources** (fail fast on rate limit). |
| HTTP 404 (`pypi`) | Mark `status: failed`, reason: "Package not found on PyPI." |
| HTTP 404 (`npm`) | Mark `status: failed`, reason: "Package not found on npm registry." |
| Non-JSON response (API types) | Mark `status: failed`, reason: "Unexpected response format." |
| WebFetch failure | Fall back to `curl -sL {url}`. If curl also fails: mark `status: failed`. |
| WebFetch returns minimal content (<100 chars) | Mark `status: failed`, reason: "Content may require JavaScript rendering. Try a direct changelog URL." |
| **All other sources** | Continue processing regardless of individual failures |

---

## Step 3: Classify Changes

Two separate dimensions:

**Fetch Status** (from Step 2):
- `success` -- fetched without error
- `failed` -- fetch error (with reason)

**Change Tier** (for successful fetches only):

| Condition | Tier | Label |
|-----------|------|-------|
| Semver major bump (1.x -> 2.x) | `major` | "Major -- may require action" |
| Semver minor/patch bump | `minor` | "Minor update" |
| Non-semver version string changed | `changed` | "Changed (review recommended)" |
| Content hash changed (`changelog-url`) | `changed` | "Content changed (review recommended)" |
| Version/hash identical to stored | `unchanged` | "No changes" |
| No stored state (first time seen) | `new` | "New (first check)" |

**Semver parsing:** Strip leading `v`, extract `major.minor.patch`. If not parseable as semver, classify any string change as `changed`.

---

## Step 4: Scan for Affected Assets

For sources with tier `major`, `minor`, or `changed`:

1. **Manual matches first:** If source has `affects` field, include those assets unconditionally.

2. **Keyword-bag matching** (per `coding-workflows:asset-discovery` approach):
   - Build keyword bag for source: split `name` on hyphens, add `relevance` keywords (stripped of stop words)
   - Build keyword bag for each asset: from `name` (split on hyphens, exclude structural suffixes: `patterns`, `conventions`, `reviewer`, `specialist`, `architect`), `domains` array, `description` keywords
   - Compute overlap ratio: `|intersection| / min(|source_bag|, |asset_bag|)`
   - Threshold: >= 0.4 (matching `coding-workflows:asset-discovery` WARN threshold)

3. **Scan locations:**
   - `.claude/agents/*.md` frontmatter
   - `.claude/skills/*/SKILL.md` frontmatter
   - `plugins/*/skills/*/SKILL.md` frontmatter (if accessible)

4. **Limit:** Max 5 matched assets per source to keep digest focused.

---

## Step 5: Produce Digest

**Primary output: stdout** (always displayed to user).

**Secondary output:** Write to `.claude/upstream-digest.md` (overwritten each run).

**Digest template:**

````markdown
# Upstream Changes -- {date}

## Major -- May Require Action

### {source_name}: {old_version} -> {new_version}
{release_body_excerpt (first 200 chars)}
- Link: {release_url}
- Relevance: {relevance}
- Affected assets:
  - {asset_name} ({asset_type})

## Minor Updates

### {source_name}: {old_version} -> {new_version}
- Link: {release_url}
- Relevance: {relevance}

## Changed (Review Recommended)

### {source_name}: {old_version} -> {new_version}
- Non-semver source -- manual review recommended
- Link: {release_url}
- Relevance: {relevance}

## New Sources (First Check)
- {source_name} ({current_version}) -- {relevance}

## No Changes
- {source_name} ({current_version})

## Fetch Errors
- {source_name}: {error_reason}

---
Last checked: {previous_run_date}
Sources monitored: {total_count}

For staleness evaluation criteria, see `coding-workflows:knowledge-freshness`.
````

Sections with no entries are omitted entirely.

---

## Step 6: Persist Updated State

**First-run gate** (if `first_run = true`):
```
This is the first run. The following baseline will be stored:

{table of source_name | current_version/hash | status}

This baseline defines "current" for future change detection.
Confirm to save initial state?
```

If user confirms: write state. If user declines: display digest but do not persist state.

**Subsequent runs:** Write state automatically (no confirmation needed).

**Write rules:**
- Only update entries for sources with `status: success`
- If ALL sources failed: skip state write, warn "No sources succeeded. State not updated."
- Write `.claude/upstream-state.json` with `state_version: 1`, `last_run` (ISO 8601), and per-source entries

**Gitignore check:** After writing, verify `.gitignore` contains entries for the state and digest files. If missing, suggest adding:

```
# Machine-generated state (do not commit)
.claude/upstream-state.json
.claude/upstream-digest.md
```

---

## Step 7: Summary

```
Sources checked: {total}
  Major changes: {count}
  Minor updates: {count}
  Changed (review needed): {count}
  New sources: {count}
  No changes: {count}
  Fetch errors: {count}

{if major_count + changed_count > 0}
Action suggested: Review affected assets listed above for staleness.
See `coding-workflows:knowledge-freshness` for evaluation criteria.
{/if}
```

---

## Error Handling

| Error | Action |
|-------|--------|
| Missing config file | Stop with guidance pointing to template |
| Malformed YAML in config | Stop with parse error |
| Unknown source `type` | Skip source with warning, continue |
| Missing required field per type | Skip source with warning, continue |
| Individual source fetch failure | Mark failed, continue with remaining sources |
| GitHub rate limit (403) | Report reset time from headers, fail-fast for remaining `github-release` sources |
| All sources failed | Show failure digest, do not update state |
| State file corrupt/missing | Treat as first run (self-healing) |
| `repo: self` unresolvable | Three-level fallback: workflow.yaml -> git remote -> ask user |

---

## Cross-References

- `coding-workflows:knowledge-freshness` -- Staleness evaluation criteria (the WHEN to this command's WHAT)
- `coding-workflows:asset-discovery` -- Keyword-bag matching heuristics used in Step 4
