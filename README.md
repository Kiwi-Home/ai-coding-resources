# AI Coding Resources

A Claude Code plugin marketplace for engineering workflows.

## coding-workflows

**Stop vibe-coding your issue tracking.** This plugin gives Claude Code a structured workflow for taking GitHub issues from idea to merged PR — with design sessions, adversarial plan review, and TDD execution built in.

<img width="1024" height="559" alt="The Process: From Issue to Merged PR with Claude Code Plugin" src="https://github.com/user-attachments/assets/51476839-c380-4c5c-912f-fec6ce4ba7b4" />

### Install

```bash
# In Claude Code:
/plugin marketplace add Kiwi-Home/ai-coding-resources
/plugin install coding-workflows@ai-coding-resources
```

### Try It

```bash
# Turn a vague idea into a structured issue with requirements and acceptance criteria
/coding-workflows:create-issue github "users can't reset their password if they signed up with SSO"

# The full pipeline: triage → design → plan → adversarial review
/coding-workflows:prepare-issue 42

# Implement with TDD, open PR, run review loop
/coding-workflows:execute-issue 42
```

That's it. Project settings are auto-detected from your git remote and project files.

### What It Does

**Issue creation** — `/create-issue` writes requirements-focused issues with acceptance criteria. Describes *what*, not *how*.

**Design sessions** — `/design-session` spawns 3-4 specialist agents that independently analyse the problem, then synthesises findings with explicit conflict resolution. No premature consensus.

**Implementation planning** — `/plan-issue` produces a specialist-reviewed implementation plan with mandatory codebase exploration and build-vs-buy research. Then `/review-plan` tears it apart before any code is written.

**TDD execution** — `/execute-issue` implements the reviewed plan using test-driven development with verification gates. Creates a feature branch, runs tests, opens a PR.

**PR review** — `/review-pr` reviews pull requests with severity-tiered findings (MUST FIX / FIX NOW / CREATE ISSUE). Works from CLI or as a GitHub Actions CI check.

**Complexity triage** — `/prepare-issue` assesses issue complexity and routes to the appropriate depth: solo mode for trivial fixes, lightweight for standard work, full deliberation for cross-cutting changes.

### What You Get

| | Count | Examples |
|---|---|---|
| **Commands** | 15 | `prepare-issue`, `execute-issue`, `review-pr`, `setup`, `create-issue` |
| **Skills** | 14 | TDD patterns, systematic debugging, issue writing, PR review framework |
| **Hooks** | 6 | Dependency version checks, test evidence logging, deferred work scanning |

### Three Tiers

**Zero config** — Install and run. Everything auto-detects.

**Configured** — Run `/init-config` to generate `.claude/workflow.yaml` with your test, lint, and branch settings.

**Full setup** — Run `/setup` for the complete experience: CLAUDE.md check, config, project-specific skills and specialist agents generated from your codebase.

### CI Review

Add automated PR review to your GitHub Actions pipeline:

```yaml
- name: Run PR Review
  uses: anthropics/claude-code-action@v1
  with:
    claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    prompt: |
      Run /coding-workflows:review-pr for PR ${{ github.event.pull_request.number }}.
```

See the [full CI setup guide](plugins/coding-workflows/README.md#ci-review-setup) for permissions, allowed tools, and customisation options.

### Documentation

The [plugin README](plugins/coding-workflows/README.md) has the full command reference, skill reference, hook configuration, FAQ, and troubleshooting guide.

### Requirements

- Claude Code with plugin support
- GitHub CLI (`gh`) installed and authenticated
- Git repository with a GitHub remote

### License

MIT
