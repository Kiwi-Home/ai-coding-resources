---
name: security-patterns
description: |
  Security detection patterns, anti-patterns, and OWASP mapping for
  code review. Covers input validation, authentication/authorization,
  secret management, and dependency audit with diff-level detection
  heuristics. Use when: reviewing PRs with security-relevant changes,
  evaluating authentication flows, or assessing input handling and
  dependency risk.
domains: [security, review, validation]
user-invocable: false
---

# Security Patterns

Security review decision framework for PR review. Provides detection heuristics Claude would not apply unprompted, severity graduation for security findings, and activation criteria for conditional security review.

## Activation Criteria

Security-focused review activates when the changed file list matches ANY of these patterns. Evaluate against the file list, not file content.

**Filename patterns** (case-insensitive substring match):
- `auth`, `login`, `session`, `password`, `token`, `secret`, `permission`, `role`, `acl`, `oauth`, `saml`, `jwt`, `credential`, `apikey`

**Dependency files:**
- `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`
- `requirements.txt`, `Pipfile.lock`, `poetry.lock`, `pyproject.toml`
- `Gemfile`, `Gemfile.lock`
- `go.sum`, `go.mod`
- `Cargo.lock`, `Cargo.toml`
- `composer.lock`

**Config and secret files:**
- `.env*`, `docker-compose*`, `*secret*`, `*credential*`
- `*.pem`, `*.key`, `*.cert`
- CI config files (`.github/workflows/*`, `.gitlab-ci.yml`, `Jenkinsfile`)

If no patterns match, note "Security review: not activated (no security-relevant files in diff)" and proceed with standard review.

---

## Security Review Framework

When activated, apply the security lens alongside standard review categories. Security findings map to existing pr-review categories:

| pr-review Category | Security Application |
|--------------------|---------------------|
| **Correctness** | Vulnerable code produces exploitable behavior (XSS renders, SQLi executes, SSRF reaches internal network) |
| **Integrity** | Broken authentication contracts, authorization bypass, session management failures |
| **Compliance** | Violated security conventions (missing CSRF tokens, disabled security headers, permissive CORS) |

Security findings use the same severity tiers as pr-review. The Severity Graduation Criteria below provide security-specific nuance for tier assignment.

**Domain-spanning signals** (check regardless of which domain activated review):
- New dependency added in diff -> see Dependency Audit Signals section below
- Config file changed -> check Secret Management Patterns below
- Route or endpoint added/modified -> check both input validation and auth patterns
- Middleware chain modified -> check authorization bypass patterns in `references/auth-patterns.md`

---

## Quick Reference

Top detection heuristics per domain. Actionable without reading reference files.

| Domain | Signal in Diff | Check For | Why Missed |
|--------|---------------|-----------|------------|
| Input | `url.parse()` or URL constructor + fetch/request | SSRF via DNS rebinding or open redirect | Claude checks URL format but not resolution timing or redirect chains |
| Input | ORM `.where()` / `.find()` with string interpolation or raw fragment | Second-order SQLi through ORM escape hatch | Claude trusts ORM parameterization, misses raw SQL fragments |
| Input | Template literal or string concat assigned to `innerHTML`-equivalent | DOM clobbering / mutation XSS | Claude catches basic `innerHTML` but misses indirect assignment paths |
| Input | `redirect_to`, `Response.Redirect`, `res.redirect` with user-controlled path | Open redirect via path manipulation | Claude checks for full URL injection but not relative path abuse |
| Auth | Parameter used as record lookup without ownership check | IDOR via direct object reference | Claude validates input type but not authorization scope |
| Auth | Time gap between permission check and resource access | TOCTOU race condition | Claude reviews checks in isolation, not temporal ordering |
| Auth | Route-level auth decorator/middleware missing on new endpoint | Authorization bypass via unprotected route | Claude checks existing middleware but not absence on new routes |
| Auth | JWT `alg` header accepted from client without server-side constraint | JWT algorithm confusion (alg:none, RS256->HS256) | Claude validates JWT parsing but not algorithm enforcement |
| Secrets | New string matching `[A-Za-z0-9+/=]{40,}` or `ghp_`, `sk-`, `AKIA` | Hardcoded credential or API key | Claude catches obvious variable names but not raw token patterns |
| Deps | New dependency with <100 GitHub stars or <1 year old | Dependency confusion or typosquatting risk | Claude checks package name validity but not supply chain reputation |

---

## Severity Graduation Criteria

Security-specific nuance for pr-review's severity tiers. Cross-references pr-review definitions; does not redefine them.

| Pattern | User-Facing Context | Tier | Rationale |
|---------|-------------------|------|-----------|
| Stored XSS | User-generated content rendered to other users | MUST FIX | Persistent exploitation, affects all viewers |
| Stored XSS | Admin-only dashboard | CREATE ISSUE | Limited blast radius, still needs fix |
| Reflected XSS | Public-facing input | MUST FIX | Exploitable via crafted links |
| Reflected XSS | Internal/admin tool | CREATE ISSUE | Requires authenticated attacker |
| SQLi (any variant) | User-facing query path | MUST FIX | Data breach risk |
| SSRF | Server can reach internal network or cloud metadata | MUST FIX | Network pivot risk |
| SSRF | Server can only reach public URLs | FIX NOW | Limited but still unintended behavior |
| IDOR | User can access other users' data | MUST FIX | Direct data breach |
| IDOR | User can access own data via unintended path | FIX NOW | Authorization contract violation |
| Missing auth on new route | Route handles sensitive data or mutations | MUST FIX | Unprotected endpoint |
| Missing auth on new route | Route serves public/read-only data | FIX NOW | Convention violation, review intent |
| Hardcoded credential | Production or staging credential | MUST FIX | Credential exposure |
| Hardcoded credential | Test fixture with obviously fake value | Drop finding | False positive (verify value is non-functional) |

---

## Secret Management Patterns

Diff-level detection signals for credential and configuration exposure.

| Signal in Diff | Check For | Why Missed |
|----------------|-----------|------------|
| New environment variable read (`process.env`, `os.environ`, `ENV[]`) without validation | Missing validation allows empty/default credentials in production | Claude checks env var usage but not absence-handling |
| `.env` or `.env.*` added to tracked files | Secret file committed to repository | Claude checks `.gitignore` existence but not whether new env files bypass it |
| Base64-encoded string >40 chars in config or source | Obfuscated credential (not encrypted) | Claude recognizes plaintext secrets but not encoded ones |
| CI config referencing secrets with `${{ }}` in `run:` blocks | Secret exposure via shell expansion in logs | Claude validates secret reference syntax but not shell echo risk |
| Config file with connection string containing `://user:pass@` | Embedded credentials in connection URI | Claude checks for password variables but not URI-embedded credentials |
| Key rotation: new key added without old key removal | Stale credential accumulation | Claude validates new additions but not cleanup of replaced values |

---

## Dependency Audit Signals

Diff-level signals for dependency risk assessment.

| Signal in Diff | Check For | Why Missed |
|----------------|-----------|------------|
| New dependency with scope override (`@org/pkg` where org differs from project) | Dependency confusion attack via registry scope manipulation | Claude validates package name but not organizational scope alignment |
| Lockfile changes without corresponding manifest change | Supply chain attack via lockfile injection | Claude reviews manifest changes but not orphaned lockfile mutations |
| Pinned version replaced with range (`^`, `~`, `>=`) | Version unpinning weakens reproducibility and opens upgrade risk | Claude checks version format but not direction of constraint change |
| New dependency duplicating existing dependency's functionality | Unnecessary attack surface expansion | Claude evaluates new dependencies in isolation, not against existing capabilities |
| `postinstall`, `preinstall`, or lifecycle scripts in new dependency | Arbitrary code execution during install | Claude checks dependency code but not install-time hooks |
| Dependency added from GitHub URL or tarball instead of registry | Bypasses registry security scanning | Claude validates install succeeds but not installation source |

---

## Anti-Patterns

| Anti-Pattern | Description | Corrective |
|--------------|-------------|------------|
| Severity inflation | Classifying every security finding as MUST FIX regardless of context | Apply Severity Graduation Criteria; context determines tier |
| Framework trust failure | Flagging ORM-parameterized queries as SQLi or framework-sanitized output as XSS | Verify the finding exploits an actual bypass, not a protected path |
| Secret false positives | Flagging test fixtures, example configs, or documentation strings as credential leaks | Check whether the value is functional; test data with obviously fake values is not a finding |
| Auth review tunnel vision | Checking authentication (who are you?) but ignoring authorization (what can you do?) | Always check both authn AND authz when reviewing auth-related changes |
| Single-layer thinking | Checking input validation at the controller but not at the service or data layer | Trace data flow across layers; validation at one layer does not guarantee safety at another |
| Dependency panic | Flagging all new dependencies as security risks without evaluating actual exposure | Assess what the dependency accesses (network, filesystem, credentials) before raising findings |

---

## Review-Config Relationship

This skill provides universal security patterns. Project-specific security conventions (approved dependency sources, required auth middleware, secret management tooling) belong in `.claude/review-config.yaml` under the `compliance` key.

---

## Cross-References

- `coding-workflows:pr-review` -- severity tiers, finding disposition framework, exit criteria (this skill applies security nuance to those definitions)
- `coding-workflows:stack-detection` -- ecosystem detection for stack-specific security pattern selection
- `coding-workflows:knowledge-freshness` -- staleness triage for security library versions and vulnerability databases
