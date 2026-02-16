# Frontmatter Field Reference

YAML frontmatter fields recognized in SKILL.md:

| Field | Description |
|-------|-------------|
| `name` | Skill identifier (lowercase, hyphens, max 64 chars). Defaults to directory name if omitted. |
| `description` | **What the skill does and when to use it** (max 1024 chars; full constraints per `plugin-validation`). Claude uses this to decide when to apply the skill. Include all "when to use" triggers here -- NOT in the body. |
| `allowed-tools` | Tools Claude can use without per-use approval when this skill is active. Example: `Read, Grep, Glob` |
| `context` | Set to `fork` to run in an isolated subagent context. Use for task-oriented skills that should run independently. |
| `agent` | Subagent type when `context: fork` is set. Options: `Explore`, `Plan`, `general-purpose`, or custom agent name. |
| `disable-model-invocation` | Set `true` to prevent Claude from auto-loading. Use for manual-only workflows (`/deploy`, `/commit`). |
| `user-invocable` | Set `false` to hide from the `/` menu. Use for background knowledge users shouldn't invoke directly. |
| `model` | Override the model for this skill's execution. |
| `argument-hint` | Autocomplete hint shown after skill name. Example: `[issue-number]` |
| `hooks` | Lifecycle hooks scoped to this skill. See Anthropic docs for format. |

Only these fields are recognized. Do not add custom or undocumented fields when creating skills manually. Automated tooling (e.g., `generate-assets`) may add internal provenance fields (`domains`, `generated_by`, `generated_at`) for staleness tracking -- these are not part of the Anthropic spec but are used by asset discovery workflows.

## Description Field Guidance

The `description` field is the primary triggering mechanism. Include both what the skill does and specific triggers/contexts:

- Example for a `docx` skill: "Comprehensive document creation, editing, and analysis with support for tracked changes, comments, formatting preservation, and text extraction. Use when Claude needs to work with professional documents (.docx files) for: (1) Creating new documents, (2) Modifying or editing content, (3) Working with tracked changes, (4) Adding comments, or any other document tasks"
