# OWASP Top 10 (2021) Crosswalk

Read when: performing comprehensive security audit or verifying OWASP coverage.

Maps each OWASP Top 10 2021 category to skill sections and reference file patterns. Use for coverage verification, not as primary navigation during PR review.

## Crosswalk Table

| OWASP ID | Category | Skill Coverage | Reference |
|----------|----------|---------------|-----------|
| A01:2021 | Broken Access Control | Quick Reference (IDOR, missing auth), Severity Graduation (IDOR, missing auth on route) | `auth-patterns.md`: IDOR, authorization bypass, CSRF, missing middleware |
| A02:2021 | Cryptographic Failures | Secret Management Patterns (hardcoded credentials, encoded secrets) | `auth-patterns.md`: JWT algorithm confusion |
| A03:2021 | Injection | Quick Reference (SQLi, XSS), Severity Graduation (XSS, SQLi) | `input-validation-patterns.md`: XSS variants, SQLi variants, template injection |
| A04:2021 | Insecure Design | Not directly covered (design-level, not diff-level) | N/A -- design reviews are out of scope for diff-based security review |
| A05:2021 | Security Misconfiguration | Activation Criteria (config files), Secret Management Patterns (env validation) | `auth-patterns.md`: permissive CORS, disabled security headers |
| A06:2021 | Vulnerable and Outdated Components | Dependency Audit Signals (all rows) | `input-validation-patterns.md`: dependency-related signals |
| A07:2021 | Identification and Authentication Failures | Quick Reference (JWT, auth bypass), Severity Graduation (missing auth) | `auth-patterns.md`: session fixation, JWT confusion, auth bypass |
| A08:2021 | Software and Data Integrity Failures | Dependency Audit Signals (lockfile injection, lifecycle scripts) | N/A -- CI/CD pipeline security is partially covered via Activation Criteria |
| A09:2021 | Security Logging and Monitoring Failures | Not directly covered (operational concern, rarely visible in PR diffs) | N/A -- recommend project-specific `review-config.yaml` compliance rules |
| A10:2021 | Server-Side Request Forgery | Quick Reference (SSRF), Severity Graduation (SSRF by context) | `input-validation-patterns.md`: DNS rebinding, blind SSRF, cloud metadata |

## Coverage Notes

**Fully covered (diff-detectable):** A01, A02, A03, A05, A06, A07, A08, A10

**Partially covered:** A04 (design-level concerns surface only when implementation contradicts stated security requirements), A09 (logging patterns visible in diffs but monitoring is operational)

**Coverage gaps by design:** This skill covers diff-level detection patterns only. OWASP categories focused on operational concerns (A09) or design-level decisions (A04) require different review mechanisms:
- A04: Address during design sessions (`/coding-workflows:design-session`)
- A09: Address via project-specific compliance rules in `.claude/review-config.yaml`
