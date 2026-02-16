---
name: skill-creator
description: >
  Guides creation of effective skills that extend Claude with specialized
  knowledge, workflows, or tool integrations. Covers skill anatomy, frontmatter
  fields, bundled resources, progressive disclosure, and the init/edit/package
  lifecycle. Use when: creating a new skill, updating an existing skill,
  understanding skill structure, or packaging skills for distribution.
---

# Skill Creator

This skill provides guidance for creating effective skills.

## About Skills

Skills are modular, self-contained packages that extend Claude's capabilities by providing
specialized knowledge, workflows, and tools. Think of them as "onboarding guides" for specific
domains or tasks—they transform Claude from a general-purpose agent into a specialized agent
equipped with procedural knowledge that no model can fully possess.

### What Skills Provide

1. Specialized workflows - Multi-step procedures for specific domains
2. Tool integrations - Instructions for working with specific file formats or APIs
3. Domain expertise - Company-specific knowledge, schemas, business logic
4. Bundled resources - Scripts, references, and assets for complex and repetitive tasks

## Core Principles

### Concise is Key

The context window is a public good. Skills share the context window with everything else Claude needs: system prompt, conversation history, other Skills' metadata, and the actual user request.

**Default assumption: Claude is already very smart.** Only add context Claude doesn't already have. Challenge each piece of information: "Does Claude really need this explanation?" and "Does this paragraph justify its token cost?"

Prefer concise examples over verbose explanations.

### Size Budget

Skills share the context window with system prompts, conversation history, and user requests. Every line costs tokens.

| Context | Target | Hard Limit | Rationale |
|---------|--------|------------|-----------|
| Standalone skill | < 300 lines | 500 lines | Split into `references/` beyond this |
| Agent-injected skill | < 150 lines | 300 lines | Full content loads at agent startup, competing with other injected skills |

**Decision criteria:** When SKILL.md exceeds 300 lines, identify sections that are referenced conditionally and move them to `references/`.

#### Before/After: Splitting a Bloated Skill

**Before** (420 lines in SKILL.md — everything inline):

```markdown
# Cloud Deploy
## Workflow
[50 lines of core workflow]
## AWS Deployment
[120 lines of AWS-specific patterns]
## GCP Deployment
[110 lines of GCP-specific patterns]
## Azure Deployment
[100 lines of Azure-specific patterns]
## Troubleshooting
[40 lines of troubleshooting]
```

**After** (90 lines in SKILL.md — conditionally loaded references):

```markdown
# Cloud Deploy
## Workflow
[50 lines of core workflow]
## Provider-Specific Patterns
- **AWS**: See references/aws.md for deployment patterns
- **GCP**: See references/gcp.md for deployment patterns
- **Azure**: See references/azure.md for deployment patterns
## Troubleshooting
[40 lines of troubleshooting]
```

Claude loads only the relevant provider file when the user specifies their cloud target.

### Set Appropriate Degrees of Freedom

Match the level of specificity to the task's fragility and variability:

**High freedom (text-based instructions)**: Use when multiple approaches are valid, decisions depend on context, or heuristics guide the approach.

**Medium freedom (pseudocode or scripts with parameters)**: Use when a preferred pattern exists, some variation is acceptable, or configuration affects behavior.

**Low freedom (specific scripts, few parameters)**: Use when operations are fragile and error-prone, consistency is critical, or a specific sequence must be followed.

Think of Claude as exploring a path: a narrow bridge with cliffs needs specific guardrails (low freedom), while an open field allows many routes (high freedom).

### Anatomy of a Skill

Every skill consists of a required SKILL.md file and optional bundled resources:

```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter (required)
│   │   ├── name: (recommended)
│   │   ├── description: (recommended)
│   │   └── [optional fields: allowed-tools, context, agent, hooks, etc.]
│   └── Markdown instructions (required)
└── Bundled Resources (optional)
    ├── scripts/          - Executable code (Python/Bash/etc.)
    ├── references/       - Documentation intended to be loaded into context as needed
    └── assets/           - Files used in output (templates, icons, fonts, etc.)
```

#### SKILL.md (required)

Every SKILL.md consists of:

- **Frontmatter** (YAML): `name` and `description` are used for discovery and triggering — Claude reads these to decide when to apply the skill. Optional fields (`allowed-tools`, `context`, `agent`, `hooks`, etc.) configure runtime behavior. Be clear and comprehensive in the description, as it determines when the skill gets used. See `references/frontmatter-reference.md` for the complete field table.
- **Body** (Markdown): Instructions and guidance for using the skill. Only loaded AFTER the skill triggers (if at all).

#### Bundled Resources (optional)

##### Scripts (`scripts/`)

Executable code (Python/Bash/etc.) for tasks that require deterministic reliability or are repeatedly rewritten.

- **When to include**: When the same code is being rewritten repeatedly or deterministic reliability is needed
- **Example**: `scripts/rotate_pdf.py` for PDF rotation tasks
- **Benefits**: Token efficient, deterministic, may be executed without reading into context
- **Note**: Scripts may still need to be read by Claude for patching or environment-specific adjustments

##### References (`references/`)

Documentation and reference material intended to be loaded as needed into context to inform Claude's process and thinking.

- **When to include**: For documentation that Claude should reference while working
- **Examples**: `references/finance.md` for financial schemas, `references/mnda.md` for company NDA template
- **Benefits**: Keeps SKILL.md lean, loaded only when Claude determines it's needed
- **Best practice**: If files are large (>10k words), include grep search patterns in SKILL.md
- **Avoid duplication**: Information should live in either SKILL.md or references files, not both. Prefer references files for detailed information unless it's truly core to the skill.

##### Assets (`assets/`)

Files not intended to be loaded into context, but rather used within the output Claude produces.

- **When to include**: When the skill needs files that will be used in the final output
- **Examples**: `assets/logo.png` for brand assets, `assets/slides.pptx` for PowerPoint templates
- **Benefits**: Separates output resources from documentation, enables Claude to use files without loading them into context

#### What to Not Include in a Skill

A skill should only contain essential files that directly support its functionality. Do NOT create extraneous documentation or auxiliary files, including:

- README.md
- INSTALLATION_GUIDE.md
- QUICK_REFERENCE.md
- CHANGELOG.md
- etc.

The skill should only contain the information needed for an AI agent to do the job at hand. It should not contain auxiliary context about the process that went into creating it, setup and testing procedures, user-facing documentation, etc.

#### Invocation and Visibility Controls

Two frontmatter fields control how skills are discovered and loaded:

| Control | User `/` menu | Claude auto-loads | Command reads via Read tool |
|---------|---------------|-------------------|-----------------------------|
| Neither set | visible | yes | yes |
| `user-invocable: false` | hidden | yes | yes |
| `disable-model-invocation: true` | visible | no | yes |
| Both set | hidden | no | yes |

**Key insight:** Commands load skills via the Read tool as reference material — this is the canonical pattern for command-to-skill consumption. The Read tool operates on files directly and is never affected by `user-invocable` or `disable-model-invocation`. Both controls only affect Claude's triggering/auto-loading behavior and the user's `/` menu.

**When to use each:**
- `user-invocable: false` — For internal protocol skills that commands read but users shouldn't invoke directly. Examples: `agent-team-protocol`, `deliberation-protocol`, `complexity-triage`.
- `disable-model-invocation: true` — For manual-only workflows where the skill should only trigger when the user explicitly requests it (e.g., `/deploy`, `/commit`).

#### Progressive Disclosure

Skills use a three-level loading system (metadata, body, references) to manage context efficiently. Keep only core workflow and selection guidance in SKILL.md; move variant-specific details into reference files with clear pointers.

See `references/progressive-disclosure.md` for patterns, examples, and guidelines.

#### Agent Integration

Skills can be preloaded into agents via the `skills:` field in agent frontmatter:

```yaml
# .claude/agents/my-agent.md frontmatter
skills:
  - my-skill
  - another-skill
```

When preloaded:
- The agent receives the **full SKILL.md content** at startup (not just the description)
- This directly consumes the agent's context budget
- Use the agent-injected size budget: target < 150 lines, hard limit 300 lines (see Size Budget section)

## Skill Creation Lifecycle

Skill creation follows a 6-step process: understand, plan, initialize, edit, package, iterate.

**Analysis pattern** (from Step 2): For each concrete usage example, consider how to execute from scratch and identify what reusable resources (scripts, references, assets) would help. Example: "Help me rotate this PDF" -> code is rewritten each time -> store `scripts/rotate_pdf.py`. "How many users logged in today?" -> schemas are re-discovered each time -> store `references/schema.md`.

See `references/creation-process.md` for the full 6-step lifecycle with detailed guidance for each step.

**Key references during creation:**
- `references/frontmatter-reference.md` — field table and description authoring guidance
- `references/output-patterns.md` — template and example patterns for output formats
- `references/workflows.md` — sequential workflows and conditional logic patterns
- `references/progressive-disclosure.md` — patterns for splitting content across files

## Cross-References

- `coding-workflows:agent-patterns` — agent frontmatter spec and agent creation patterns
- `coding-workflows:plugin-validation` — validates skill structure and metadata against spec
