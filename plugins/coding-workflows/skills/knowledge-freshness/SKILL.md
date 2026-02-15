---
name: knowledge-freshness
description: |
  Staleness triage framework for evaluating when training data is reliable vs. when
  verification is required. Classifies knowledge domains by staleness risk and provides
  decision criteria for verification. Use when: writing code that depends on library
  versions, API patterns, CLI flags, or framework conventions.
domains: [freshness, versions, dependencies, staleness, verification]
---

# Knowledge Freshness

Evaluate whether training data is reliable before using it. This skill classifies knowledge domains by staleness risk and provides decision criteria -- not verification commands (see `coding-workflows:issue-workflow` references/version-discovery.md for lookup methods).

### Core Principle

**Verify before trusting.** Training data is 6-18 months stale. For domains that change frequently, always verify against current sources before writing code.

---

## Staleness Triage

| Risk | Domains | Action |
|------|---------|--------|
| **HIGH** -- ALWAYS verify | Library/package versions, API endpoint signatures, CLI flags and subcommands, framework migration patterns, cloud provider SDK methods, tool capability claims, config file schemas | Verify against current source before every use. Never trust training data. |
| **MEDIUM** -- verify when uncertain | Framework conventions and best practices, language feature availability, build tool config patterns, testing library APIs | Verify if you are not confident in the specific version. Check changelogs for recent major releases. |
| **LOW** -- training data sufficient | Algorithms and data structures, design patterns, language syntax and core stdlib, SQL fundamentals, git commands | Training data is reliable. No verification needed unless the question is version-specific. |

**Default rule:** When uncertain which tier applies, treat as HIGH.

---

## Verification Decisions

| Situation | Question to Ask | Action |
|-----------|----------------|--------|
| Adding a dependency | What is the latest stable version? | Check package registry. Never use version from training data. |
| Using a library API | Does this API exist in the installed version? | Read current docs or source for the installed version. |
| Writing framework patterns | Has the framework had a major release since training? | Search for changelog/migration guide. |
| Claiming tool capabilities | Can this tool actually do what I'm about to say? | Verify against current docs. "I'm confident" is not evidence. |
| Re-using earlier verification | Was the earlier check for this exact library and domain? | Re-verify independently. httpx version check says nothing about FastAPI patterns. |
| Already installed dependency | What version is actually in the lockfile? | Read lockfile/manifest directly. Don't assume. |

---

## Verification Methods

| Method | What It Proves | Tool Category |
|--------|----------------|---------------|
| Package registry lookup | Current stable version exists | `Bash` or Context7 MCP |
| Project lockfile/manifest | What version is actually installed | `Read` the lockfile directly |
| Current documentation | API patterns match installed version | `WebFetch` or Context7 MCP |
| Changelog / migration guide | What changed between versions | `WebSearch` for "[library] changelog [version]" |
| Library source code | Actual function signatures and behavior | `Read` source in installed package |

For specific lookup commands per language, see `coding-workflows:issue-workflow` references/version-discovery.md.

---

## Anti-Patterns

| Anti-Pattern | Why Harmful | Do This Instead |
|--------------|-------------|-----------------|
| "I'll use the version I remember" | Training data versions are 6-18 months stale. Working code today, tech debt tomorrow. | Look up the current stable version before specifying any dependency. |
| "This API pattern worked last time" | Libraries ship breaking changes. A pattern from v2 may not exist in v3. | Verify API patterns against the version actually installed in the project. |
| "I'm confident this tool supports X" | Confidence is not evidence. Tool capabilities change across versions. | Check current docs before claiming any tool capability. |
| Copying patterns from generated code | Generated code uses the generator's training data, which has the same staleness problem. | Verify the target library version independently, regardless of the pattern source. |
| Session-internal staleness drift | Verifying one domain does not verify another. Agent checks httpx version, then treats FastAPI knowledge as equally verified -- these are independent. | Each library/API/tool requires its own independent verification, even within the same session. |

---

## Cross-References

- `coding-workflows:issue-workflow` -- version-discovery.md provides specific lookup commands per language (the HOW to this skill's WHEN)
- `coding-workflows:stack-detection` -- identifies what technologies are installed in the project
- `coding-workflows:codebase-analysis` -- research triggers and familiarity signals for domain evaluation
