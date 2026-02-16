# Skill Generation Template

Template and examples for generating project-specific skill files via `generate-assets`. For manual skill creation, see `creation-process.md` and the core SKILL.md instead.

> **Co-maintained with `generate-assets` command.** Changes to the scaffold structure should be reflected in both this file and the command's Step 4a guidance.

## Pre-population Sources

| Section | Analysis Path | Fallback Path | Minimal Context |
|---------|---------------|---------------|-----------------|
| `name` | Domain-specific from analysis | Generic from `coding-workflows:stack-detection` table | Generic from `coding-workflows:stack-detection` table |
| Purpose | From project analysis with evidence | TODO | TODO |
| Conventions | Observed patterns with file citations | Framework-specific hints (see `stack-detection/references/framework-hints.md`) | Framework-specific hints |
| Patterns | Repeating patterns from code sampling | TODO | TODO |
| Anti-Patterns | Common mistakes inferred from codebase | TODO | TODO |
| Validation Checklist | Domain-specific checks from analysis | TODO | TODO |

TODOs only for: edge cases requiring human judgment, production-specific knowledge not visible in code, areas where research was declined.

## Evidence Citations

When pre-populating conventions, cite evidence:
- File paths: `src/billing/webhooks.py`
- Pattern coverage: `app/services/*.rb (8 files matching pattern)`
- Always include at least one concrete file path per convention -- never just counts

## Frontmatter Scaffold

**Spec fields:** See `frontmatter-reference.md` for the complete field table. The `domains`, `generated_by`, and `generated_at` fields are internal provenance tracking for staleness detection, used by `coding-workflows:asset-discovery` -- not part of the Anthropic spec (validators accept these fields).

**Description quality:** Generated descriptions must discriminate THIS skill from others -- generic triggers that differ only by domain noun are non-discriminating. Interpolate analysis-derived specifics whenever available.

### Analysis Path

```yaml
---
name: {domain}-patterns
description: "{Domain} conventions and patterns for {framework} projects. Encodes {specific_conventions_from_analysis}. Use when: {analysis_trigger_1}, {analysis_trigger_2}, or {analysis_trigger_3}."
domains: [{domain keywords}]
generated_by: generate-assets
generated_at: "{YYYY-MM-DD}"
---
```

Example: If analysis found custom error wrapper + response envelope + auth middleware:
```yaml
description: "API conventions and patterns for FastAPI projects. Encodes error wrapper pattern, standard response envelope, and dependency-injection auth. Use when: implementing new API endpoints, reviewing request/response handling, or debugging middleware chains."
```

### Fallback Path (Limited Context)

```yaml
---
name: {domain}-patterns
description: "{Domain} conventions and patterns for {framework} projects. TODO: Replace with project-specific description per coding-workflows:skill-creator guidance. Use when: reviewing {domain} code, implementing new {domain} features, or onboarding to {domain} patterns."
domains: [{domain keywords}]
generated_by: generate-assets
generated_at: "{YYYY-MM-DD}"
---
```

## Body Scaffold

```markdown
# {Domain} Patterns

## Purpose
{analysis_path: 1-2 sentences from analysis with evidence}
{fallback_path: TODO block}

## Conventions
{analysis_path: observed patterns with file citations}
{fallback_path: framework-specific hints from stack-detection/references/framework-hints.md}

## Patterns
### {Pattern Category}
{analysis_path: repeating patterns from code sampling}
{fallback_path: TODO block}

## Anti-Patterns
{analysis_path: common mistakes inferred from codebase}
{fallback_path: TODO block}

## Validation Checklist
{analysis_path: domain-specific checks}
{fallback_path: TODO block}

## Reference
# TODO: Links to internal docs, ADRs, or external resources
```

**Note:** The template does NOT include a "When to Use" body section. Per the skill-creator spec, "when to use" information belongs in the `description` field -- the body loads only after triggering, so body-level usage guidance wastes tokens.
