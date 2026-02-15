# Agent File Structure

A well-defined agent file has these sections:

```markdown
---
name: api-reviewer
description: "Reviews API patterns, async code, and request handling"
tools: Read, Grep, Glob, Bash, SendMessage, TaskUpdate, TaskList
# disallowedTools: Write     # Optional: remove specific tools from available set
# model: sonnet              # Optional: model override (default: inherit)
# permissionMode: default    # Optional: permission control
# maxTurns: 20               # Optional: limit turns (prevents runaway execution)
# skills: []                 # Optional: skills injected at startup (full content)
domains: [api, routes, async, http, endpoints, middleware]
role: reviewer
---

# API Reviewer

## Your Role
Review API code for correctness, performance, and consistency with project patterns.

## Project Conventions
- [Framework]-specific patterns to enforce
- Error handling conventions
- Authentication/authorization patterns

## Settled Decisions
Decisions that are NOT up for debate:
- [Decision 1]: [rationale]
- [Decision 2]: [rationale]

## Review Checklist
- [ ] Endpoints follow naming convention
- [ ] Error responses use standard format
- [ ] Input validation on all external inputs
- [ ] Tests cover happy path and error cases

## Skills You Should Reference
- [Relevant skill names from project]
```
