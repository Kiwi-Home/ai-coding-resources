# Framework-Specific Hints

Convention hints injected into the `## Conventions` section of generated skills when using the fallback path (Step 1b in `generate-assets`).

## FastAPI

| Domain | Hints |
|--------|-------|
| API | Dependency injection patterns (Depends()), Pydantic request/response models, async handler patterns, error response format, router organization |
| Data | SQLAlchemy patterns, Alembic migration conventions, session management |
| Testing | pytest fixtures, httpx.AsyncClient usage, factory patterns |

## Rails

| Domain | Hints |
|--------|-------|
| API | Controller conventions (thin controllers, service objects), strong parameters, concerns, error response format, route organization |
| Data | ActiveRecord patterns, migration conventions, query scoping, association patterns |
| Testing | RSpec factories, request specs, shared examples, fixture strategies |

## Next.js

| Domain | Hints |
|--------|-------|
| API | App router patterns, API routes, middleware, server actions, data fetching |
| Data | Prisma patterns, server actions, data access layer conventions |
| Testing | Jest + React Testing Library, component testing, mock patterns |

## Express

| Domain | Hints |
|--------|-------|
| API | Router patterns, middleware chains, error handlers, validation middleware |
| Data | Sequelize/Knex patterns, migration management, connection pooling |
| Testing | Supertest, Jest, integration test patterns |

## Generic (Unlisted Frameworks)

```markdown
## Conventions
# TODO: List your team's conventions for {domain}
# NOTE: Focus on YOUR project's specific conventions, not generic framework
# knowledge. Claude already knows general {framework} patterns.
```

**Polyglot projects:** Ask which language's framework to use for hints. Domain detection is directory-based and applies to all languages.
