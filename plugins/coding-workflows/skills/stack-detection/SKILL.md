---
name: stack-detection
description: |
  Technology stack detection reference tables and per-stack analysis guidance.
  Maps project files to languages, dependencies to frameworks, and directory
  structures to domains. Includes deeper analysis criteria for LLM-driven
  codebase understanding. Use when detecting a project's technology stack,
  scanning for languages, or identifying frameworks.
domains: [detection, stack, language, framework, domain]
---

# Stack Detection Reference Tables

Declarative mappings for identifying a project's technology stack. Commands reference these tables rather than maintaining their own detection logic.

## Language Detection

| File | Language | Package Manager |
|------|----------|-----------------|
| `pyproject.toml` | Python | uv / pip |
| `package.json` | JavaScript/TypeScript | npm / yarn / pnpm |
| `Cargo.toml` | Rust | cargo |
| `go.mod` | Go | go |
| `Gemfile` | Ruby | bundler |
| `build.gradle` or `pom.xml` | Java/Kotlin | gradle / maven |
| `mix.exs` | Elixir | mix |

## Framework Detection

| Language | Dependency | Framework |
|----------|-----------|-----------|
| Python | `fastapi` | FastAPI |
| Python | `django` | Django |
| Python | `flask` | Flask |
| TypeScript | `next` | Next.js |
| TypeScript | `express` | Express |
| TypeScript | `nestjs` | NestJS |
| Ruby | `rails` | Rails |
| Rust | `actix-web` | Actix |
| Rust | `axum` | Axum |
| Go | `gin-gonic` | Gin |
| Go | `echo` | Echo |
| Elixir | `phoenix` | Phoenix |

## Domain Detection

| Directory Pattern | Domain |
|-------------------|--------|
| `models/`, `schemas/`, `entities/` | Data models |
| `api/`, `routes/`, `controllers/`, `handlers/` | API layer |
| `services/`, `use_cases/`, `ops/` | Business logic |
| `storage/`, `db/`, `repositories/` | Data access |
| `auth/`, `security/` | Authentication/security |
| `tests/`, `spec/`, `__tests__/` | Testing |
| `Dockerfile`, `docker-compose.*`, `.github/workflows/`, `k8s/` | Infrastructure |
| _(detected via Framework Detection table above)_ | Framework-specific |

### Gating Rules

- **Infrastructure** requires **2 or more** signals. A single `.github/workflows/` directory alone is not sufficient — most projects have CI config without being infrastructure-focused.
- **Framework-specific** is detected via the Framework Detection table (dependency-based), not directory patterns. Only present if a framework was identified.

## Analysis Guidance (Beyond File Presence)

When performing LLM-driven codebase analysis (see `coding-workflows:codebase-analysis` skill), these per-stack guides indicate what to look for beyond file presence. Use these after identifying the stack via the tables above.

### Python / FastAPI

- **Dependency injection**: How `Depends()` is used -- shared session patterns, auth injection, config injection
- **Async patterns**: Consistent async/await usage, background tasks (Celery, Dramatiq, or native)
- **Pydantic models**: Request/response model organization, validation patterns, shared base models
- **Error handling**: Custom exception handlers, error response format consistency
- **Database patterns**: SQLAlchemy session management, Alembic migration conventions, repository vs direct query patterns

### TypeScript / Next.js

- **Component boundaries**: Server vs client component split, data fetching strategy (server actions, RSC, API routes)
- **State management**: React Context, Zustand, Redux, or server-side state
- **Route organization**: App router patterns, parallel routes, intercepting routes
- **Type safety**: Shared type definitions, Zod validation, end-to-end type safety

### Ruby / Rails

- **Service objects**: Thin controllers + service objects vs fat models, command/operation patterns
- **ActiveRecord patterns**: Scoping conventions, association patterns, callback usage
- **Background jobs**: Sidekiq/GoodJob organization, retry strategies, job base class patterns
- **Testing**: RSpec conventions (factories vs fixtures, shared examples, request spec patterns)

### Rust / Actix or Axum

- **Error handling**: thiserror/anyhow usage, error type hierarchy
- **State sharing**: Arc<Mutex<T>> patterns, app state extractors
- **Middleware and extractors**: Custom extractors, middleware chains
- **Async runtime**: tokio patterns, spawned tasks, channel usage

### Go

- **Interface design**: Interface segregation, dependency injection patterns
- **Context propagation**: Context usage across service boundaries, timeout patterns
- **Error wrapping**: fmt.Errorf with %w, sentinel errors, custom error types
- **Goroutine safety**: Mutex usage, channel patterns, sync.WaitGroup

### Generic (Unlisted Stacks)

- **Entry point organization**: Single vs multiple entry points, CLI vs server vs worker
- **Error handling approach**: Exceptions, result types, error codes
- **Testing framework**: Unit vs integration test organization, fixture patterns
- **Module boundaries**: How the codebase separates concerns

For TDD patterns and testing strategy guidance per stack, see `coding-workflows:tdd-patterns`.

See `references/framework-hints.md` for framework-specific convention hints used during skill generation.

---

## Polyglot Projects

When multiple language files are detected (e.g., `pyproject.toml` and `package.json`):

- Present all detected languages to the user
- Ask which is the primary language
- Framework detection runs against the selected primary language
- Domain detection is language-agnostic (directory-based) and applies to all languages

## When Detection Fails

If no project files are found or the technology stack cannot be determined, prompt the user for:

1. Primary language
2. Framework (if applicable)
3. Key domains in the codebase (e.g., API, storage, auth)
