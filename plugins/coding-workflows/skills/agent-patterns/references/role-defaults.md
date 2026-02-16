# Role-Based Defaults

Configuration defaults applied during agent generation based on the agent's `role` field.

## Frontmatter Defaults

| Field | `reviewer` | `architect` | `specialist` |
|-------|------------|-------------|--------------|
| `model` | `sonnet` | *(omit)* | *(omit)* |
| `permissionMode` | `default` | `default` | `default` |
| `maxTurns` | `50` | `75` | *(omit)* |
| `color` | `blue` | `purple` | `green` |

Apply these defaults when generating agent frontmatter based on the agent's `role`.
Fields marked *(omit)* should NOT be written to the generated file -- omission
inherits the parent context's value (for `model`) or leaves the agent unbounded
(for `maxTurns`).

**`permissionMode` note:** All roles use `default` per the `coding-workflows:agent-patterns`
spec (line 93: "Recommended for reviewers"). Read-only enforcement for reviewer agents
is achieved through the `tools` field (see Role-Based Tool Sets), not through
`permissionMode`. The `plan` mode is reserved for planning/research agents, not reviewers.

## Role Inference

During Step 3 proposals in `generate-assets`:
- Single domain with review focus -> `reviewer` (default)
- Cross-cutting or multi-domain -> `architect`
- Domain-specific implementation focus -> `specialist`
- Default when user doesn't specify -> `reviewer`

**Unknown role:** If `role` is not one of `specialist`, `reviewer`, or `architect`,
warn user ("Unknown role '{value}'. Valid values: specialist, reviewer, architect.
Defaulting to reviewer.") and apply `reviewer` defaults.

## Role-Based Tool Sets

| Role | `tools` value |
|------|---------------|
| `reviewer` | `Read, Grep, Glob, SendMessage, TaskUpdate, TaskList` |
| `architect` | `Read, Grep, Glob, Bash, SendMessage, TaskUpdate, TaskList` |
| `specialist` | `Read, Grep, Glob, Bash, Write, Edit, SendMessage, TaskUpdate, TaskList` |

**Trust boundary:** Reviewer agents intentionally omit `Bash`, `Write`, and `Edit`
to enforce read-only access. This is a trust boundary, not a convenience.
See `coding-workflows:agent-patterns` for tool configuration patterns.
