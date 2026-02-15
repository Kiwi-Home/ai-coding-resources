---
description: Run a technical design session on an issue, PR, file, or topic with dynamically discovered specialist agents
args:
  subject:
    description: "Issue (#228), PR (#239), cross-repo (other-repo#10), file path, or topic description"
    required: true
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Task
  - WebFetch
  - TeamCreate
  - TeamDelete
  - TaskCreate
  - TaskUpdate
  - TaskList
  - SendMessage
---

# Design Session

## Subject: **{{subject}}**

---

## Step 0: Resolve Project Context (MANDATORY)

1. **Read config:** Use the Read tool to read `.claude/workflow.yaml`.
   - If file exists: extract all fields. Also read `project.remote` (default: `origin` if field is absent or empty). Use this as the identity remote name for any `git remote get-url` or `gh --repo` resolution. Proceed to step 3.
   - If file does not exist: proceed to step 2.

2. **Auto-detect (zero-config fallback):**
   - Run `git remote get-url origin` to extract org and repo name
   - Scan for project files: `pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod`, `Gemfile`
   - **CONFIRM with user:** "I detected [language] project [org/repo]. Is this correct?" DO NOT proceed without confirmation.

3. **Validate resolved context:**
   - `project.org` and `project.name` must be non-empty (stop if missing)
   - `git_provider` must be `github` (stop with message if not)
   - If `project.remote` is set to a non-empty value but `git remote get-url {remote}` fails: stop with error: "Configured remote '{remote}' not found. Run `git remote -v` to see available remotes, or update project.remote in .claude/workflow.yaml." Do NOT silently fall back to origin.

**DO NOT GUESS configuration values.** If a value cannot be read from workflow.yaml or confirmed via auto-detection, ask the user.

---

## Step 1: Parse Subject and Gather Context

Determine what we're reviewing:

| Pattern | Type | Action |
|---------|------|--------|
| `#123` or `123` | Issue | `gh issue view 123 --repo {org}/{repo} --json title,body,comments` |
| `PR #123` or `pr:123` | Pull Request | `gh pr view 123 --repo {org}/{repo} --json title,body,files,diff` |
| `other-repo#10` | Cross-repo issue | `gh issue view 10 --repo {org}/other-repo --json title,body,comments` |
| `/path/to/file` | Document | Read the file |
| Free text | Topic | Use as problem statement |

**For PRs:** Also fetch the diff to understand what changed:
```bash
gh pr diff 123 --repo {org}/{repo}
```

---

## Step 2: Frame the Session

Before invoking specialists, clearly state:

```markdown
## Design Session: [Title]

**Type:** [Issue / PR Review / Architecture / Topic]
**Subject:** [reference]

**Problem/Question:**
[What are we deciding or reviewing?]

**Constraints:**
- [Non-negotiables]

**Success Criteria:**
- [How we'll know the design/review is complete]

**Specialists Needed:**
- [Who and why]
```

---

## Step 2a: Discover Available Specialists

Scan `.claude/agents/*.md` for agent definitions. Read ONLY the YAML frontmatter (between the opening and closing `---` markers) from each file to extract `name`, `description`, `domains`, and `role`. Do not read agent body content during this step — the agent's full definition is loaded at dispatch time.

Match agents to the session subject:
- Compare subject keywords against agent `domains` arrays (fuzzy matching)
- Prioritize agents with `role: architect` for design sessions
- If `planning.always_include` is configured in workflow.yaml, always include those agents

**When no agents found:**
> "No specialist agents configured. Operating as sole reviewer. Run `/coding-workflows:generate-assets agents` to create project-specific specialists."

Select 2-4 specialists based on relevance to the subject.

---

## Step 2b: Multi-Round Dispatch Check

Before dispatching specialists, evaluate:

1. **Specialist count**: Are 2+ specialists being dispatched?
2. **Conflict potential**: Check `deliberation.conflict_overrides` in workflow.yaml. If ANY specialist pair has a HIGH conflict override, this condition is true.

If BOTH conditions are true, use multi-round dispatch protocol:

**Check**: Is `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` set to `1`?
- **Yes**: Use agent-team dispatch (TeamCreate, SendMessage, persistent context)
  - If TeamCreate fails: log warning, fall back to Task-based dispatch
- **No**: Use Task-based multi-round dispatch (sequential Task calls with context bridging)

If EITHER condition is false (single specialist, or no conflict potential):
- Use single-round Task dispatch

**When using multi-round dispatch**: Follow the deliberation protocol for Steps 3-5. Resume at Step 6 after the protocol completes.

> **Deferred read:** Do not read `coding-workflows:deliberation-protocol` during pre-dispatch. Read it only after Round 1 responses are collected AND conflicts are detected in Step 4.

---

## Step 2c: Specialist Context Budget

Each specialist dispatch is subject to these constraints:

- **Scope**: Only files and sections matching the specialist's `domains` metadata
- **Budget**: ~200 lines max of subject context per specialist
- **Overflow**: When source material exceeds budget, include the most relevant sections and list full file paths for omitted content
- **Tracking**: Record scoping decisions for the Context Budget summary in Step 6

---

## Step 3: Dispatch to Specialists

**Note:** If multi-round dispatch was activated in Step 2b, skip Steps 3-5 -- the deliberation protocol handles all dispatch rounds. Resume at Step 6.

Invoke 2-4 specialists with **focused questions** (not "what do you think?").

**Dispatch Template:**

For each specialist, use the Task tool with `subagent_type` set to the agent name from frontmatter. The agent definition provides domain expertise, review checklists, and project context. Your prompt should focus on the specific question:

```
**Subject:** [SUBJECT]

**Context:**
[Domain-scoped excerpt from Step 2c — files/sections matching this specialist's domains, ~200 lines max]

**Question:**
[Specific question for this specialist]

**Evaluate against:**
- Project patterns and conventions
- [Specific concern for this domain]

End your response with:

### Confidence Assessment
- **Confidence:** [High/Medium/Low]
- **Reasoning:** [1 sentence]
- **Key concern:** [Most important issue, or "None"]
```

---

## Step 4: Collect and Detect Conflicts

After specialist responses:

1. **Extract key findings** (don't just paste responses)
2. **Note consensus** - where specialists agree
3. **Flag conflicts** - where they disagree
4. **Identify gaps** - what wasn't addressed

```markdown
## Emerging Picture

### Consensus
- [Point specialists agree on]

### Conflicts
- [Specialist A] says X, [Specialist B] says Y

### Gaps
- [What hasn't been addressed]
```

---

## Step 5: Resolve Conflicts

| Conflict Type | Resolution |
|---------------|------------|
| Security vs. convenience | Security wins; escalate if blocking |
| Performance vs. maintainability | Favor maintainability unless perf is critical path |
| Architecture vs. speed | Architect role has higher authority on cross-cutting concerns |
| Stylistic | Chair decides, cite existing patterns |

**Confidence-weighted resolution:**
- High vs Low -> High wins
- High vs High -> Ask for rebuttal, then decide
- Low vs Low -> Conservative choice or escalate to human

**Escalate to human when:**
- Security implications that can't be fully assessed
- Major architecture affecting multiple systems
- All specialists express low confidence
- Any specialist flags "needs human judgment"

---

## Step 6: Synthesize Output

Produce ONE coherent output (not a transcript).

**Note:** If multi-round dispatch was used (Step 2b), conflicts may already be resolved. Reference the resolution path rather than presenting them as open conflicts.

**For Issue/Topic sessions:**
```markdown
## Design Session: [Title]

### Decision
[What we decided]

### Rationale
[Why, including trade-offs]

### Specialist Input
| Specialist | Finding | Confidence |
|------------|---------|------------|
| ... | ... | High/Med/Low |

### Conflicts Resolved
[How disagreements were handled]

### Action Items (Inline)
Items small enough to include in the current PR. Default for minor fixes and self-contained adjustments.
- [ ] [Specific next step]

### Action Items (Separate Issue Required)
Items that cross module/service/repo boundaries, require their own design, or are risk-elevating.
- [ ] [Specific next step] -- Reason: [cross-boundary / design-required / risk-elevating]

*When classification is unclear, default to inline.*

### Open Questions
[Anything needing human input]

### Context Budget
- [Specialist A]: [N files, ~M lines] — [what was dispatched]
- [Specialist B]: [N files, ~M lines] — [what was dispatched]
- Solo session *(use when no specialists were dispatched)*
```

**For PR Review sessions:**
```markdown
## PR Review: [Title]

### Verdict: [Approve / Changes Requested / Needs Discussion]

### What's Good
- [Positive findings]

### Concerns
| Concern | Severity | Specialist | Suggestion |
|---------|----------|------------|------------|
| ... | Critical/Important/Minor | ... | ... |

### Recommendations (Inline)
Changes to make in this PR.
- [Specific change]

### Recommendations (Separate Issue Required)
Follow-up work that crosses module/service/repo boundaries, requires its own design, or is risk-elevating.
- [Follow-up work] -- Reason: [cross-boundary / design-required / risk-elevating]

*When classification is unclear, default to inline.*

### Context Budget
- [Specialist A]: [N files, ~M lines] — [what was dispatched]
- [Specialist B]: [N files, ~M lines] — [what was dispatched]
```

---

## Step 7: Post to Issue (When Subject is an Issue)

**If the subject was an issue reference**, post the session output as a comment:

```bash
gh issue comment [NUMBER] --repo "{org}/{repo}" --body "OUTPUT"
```

**Header for issue comments:**
```markdown
## Design Session

[Rest of output...]

---
*Design session via `/coding-workflows:design-session [subject]`*
```

---

## My Role as Chair

I am a **facilitator**, not the sole expert:

1. **Frame** - Define problem, constraints, success criteria
2. **Dispatch** - Focused questions to 2-4 specialists (parallel when possible)
3. **Collect** - Gather findings, detect conflicts
4. **Resolve** - Apply resolution mechanisms
5. **Synthesize** - ONE coherent output with decision log

### Rules I Follow

- Specialists work **independently** in round 1
- Each gets **ONE focused question**
- I track **confidence levels**
- Maximum **2-3 rounds** before deciding
- **Majority quorum** sufficient, not unanimity
- Produce **ADR** for significant architecture decisions

---

**Beginning session for: {{subject}}**
