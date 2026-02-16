# Input Validation Patterns

Read when: reviewing diffs that handle user input, URL construction, or database queries.

Covers attacks exploiting insufficient validation of **data content** -- what the bytes are. Basic variants (obvious `innerHTML` assignment, string-concat SQL, plaintext `eval()`) are excluded; Claude catches these unprompted. Patterns below focus on advanced variants with specific failure modes Claude misses.

## Table of Contents

- [XSS Variants](#xss-variants)
- [SQL Injection Variants](#sql-injection-variants)
- [Server-Side Request Forgery](#server-side-request-forgery)
- [Open Redirect](#open-redirect)
- [Template Injection](#template-injection)
- [Excluded Basic Variants](#excluded-basic-variants)

---

## XSS Variants

### DOM Clobbering

| Aspect | Detail |
|--------|--------|
| **Signal** | Code reads named DOM properties (`document.getElementById` result used without null check, or `window[name]` access) alongside user-controlled HTML attributes (`id`, `name`) |
| **Attack** | Attacker injects HTML elements whose `id`/`name` attributes shadow global variables or DOM API properties, redirecting control flow |
| **Anti-Pattern** | Checking only for `<script>` tags or `on*` event handlers in sanitization |
| **Stack Notes** | React: immune in JSX (no raw HTML insertion by default); vulnerable if using `dangerouslySetInnerHTML` with user content. Angular: `DomSanitizer` blocks this unless `bypassSecurityTrustHtml` is used. Vanilla JS: fully exposed. |
| **Why Missed** | Claude validates script injection and event handlers but does not trace DOM property shadowing via `id`/`name` attribute collisions |

### Mutation XSS (mXSS)

| Aspect | Detail |
|--------|--------|
| **Signal** | HTML sanitizer output re-parsed by browser (e.g., sanitized content inserted into `<template>`, `<textarea>`, `<noscript>`, or SVG/MathML contexts) |
| **Attack** | Browser re-parses sanitized HTML in a different parsing context, reconstructing executable content from fragments the sanitizer considered safe |
| **Anti-Pattern** | Trusting DOMPurify or equivalent output without considering re-parsing context |
| **Stack Notes** | DOMPurify: safe if output is inserted once into a standard context; vulnerable if re-serialized or placed in foreign content contexts. Server-side sanitizers: higher risk because they cannot account for client-side re-parsing. |
| **Why Missed** | Claude validates that a sanitizer is used but does not trace whether sanitized output enters a context where re-parsing changes its meaning |

### Prototype Pollution to XSS

| Aspect | Detail |
|--------|--------|
| **Signal** | Deep merge, recursive assign, or `lodash.merge`/`lodash.defaultsDeep` on user-controlled objects; combined with template rendering or DOM manipulation downstream |
| **Attack** | Attacker pollutes `Object.prototype` with properties that are later read by template engines or DOM APIs, achieving code execution |
| **Anti-Pattern** | Validating user input shape but allowing `__proto__`, `constructor`, or `prototype` keys |
| **Stack Notes** | Node.js/Express: common via body parsers accepting nested objects. React: rare (JSX doesn't read prototype chain for rendering). Server-side template engines (EJS, Pug, Handlebars): high risk. |
| **Why Missed** | Claude checks for direct XSS sinks but does not trace prototype pollution chains that reach those sinks indirectly |

---

## SQL Injection Variants

### Second-Order SQL Injection

| Aspect | Detail |
|--------|--------|
| **Signal** | Data retrieved from database used directly in a subsequent query without re-parameterization (e.g., `user.name` from one query used in string interpolation of another) |
| **Attack** | Attacker stores malicious SQL in a properly-parameterized write; the payload executes when the stored value is used unsafely in a later query |
| **Anti-Pattern** | Assuming data from the database is "trusted" because it was parameterized on write |
| **Stack Notes** | ORMs: Rails `find_by_sql`, Django `.raw()`, SQLAlchemy `text()` are common re-injection points. Stored procedures that build dynamic SQL from table data are also vulnerable. |
| **Why Missed** | Claude validates parameterization at write time but does not trace stored data through retrieval into subsequent queries |

### ORM Escape Hatches

| Aspect | Detail |
|--------|--------|
| **Signal** | ORM query with raw SQL fragment: `.where("name = '#{params[:name]}'")`, `Sequelize.literal()`, `knex.raw()`, Django `.extra()`, SQLAlchemy `text()` with string formatting |
| **Attack** | Developer uses ORM escape hatch for a query the ORM API can't express; the raw fragment bypasses ORM parameterization |
| **Anti-Pattern** | Trusting that "we use an ORM" means all queries are parameterized |
| **Stack Notes** | Rails: `.where(string)` vs `.where(hash)` -- only hash form is parameterized. Django: `.extra()` is deprecated precisely for this reason; `.raw()` requires explicit params. Node: Sequelize `Op` vs `Sequelize.literal()`. |
| **Why Missed** | Claude trusts ORM usage as safe by default and does not distinguish parameterized vs raw API surface |

### NoSQL Injection

| Aspect | Detail |
|--------|--------|
| **Signal** | MongoDB query with user input in query operator position: `{username: req.body.username}` where `req.body.username` could be `{"$gt": ""}` |
| **Attack** | Attacker sends JSON object instead of string, injecting MongoDB query operators (`$gt`, `$ne`, `$regex`, `$where`) |
| **Anti-Pattern** | Assuming NoSQL databases are immune to injection because they don't use SQL |
| **Stack Notes** | Mongoose: `schema.path().validate()` does not prevent operator injection in query context. Express: `express.json()` parses nested objects by default. |
| **Why Missed** | Claude validates SQL injection patterns but does not apply equivalent scrutiny to NoSQL query construction |

---

## Server-Side Request Forgery

### DNS Rebinding SSRF

| Aspect | Detail |
|--------|--------|
| **Signal** | URL validated at request time (e.g., DNS resolution check) but fetched later, or URL fetched with standard HTTP client that follows redirects |
| **Attack** | Attacker's DNS returns a public IP for validation, then rebinds to an internal IP (169.254.169.254, 10.x, 127.x) before the actual fetch |
| **Anti-Pattern** | Validating URL's resolved IP once, then using the URL (not the resolved IP) for the actual request |
| **Stack Notes** | All languages: standard HTTP clients resolve DNS independently from validation code. Cloud metadata endpoints (AWS `169.254.169.254`, GCP, Azure) are primary targets. |
| **Why Missed** | Claude validates that URL allowlisting exists but does not check for TOCTOU between DNS validation and request execution |

### Blind SSRF

| Aspect | Detail |
|--------|--------|
| **Signal** | Server fetches user-provided URL but does not return the response body to the user (e.g., webhook URL, avatar URL fetch, link preview that only extracts metadata) |
| **Attack** | Attacker probes internal network topology by observing response timing, error codes, or side effects (e.g., triggering internal webhooks, writing to internal queues) |
| **Anti-Pattern** | Assuming SSRF requires response body exfiltration to be exploitable |
| **Stack Notes** | Webhook handlers: common in Slack/Discord integrations, payment processors, CI/CD triggers. Image processors: ImageMagick, Pillow with URL fetch. |
| **Why Missed** | Claude checks for response data exposure but does not flag the request itself as a side-effect attack vector |

### Cloud Metadata SSRF

| Aspect | Detail |
|--------|--------|
| **Signal** | Any server-side HTTP request using user-controlled URL in cloud-deployed application without explicit deny for metadata IPs |
| **Attack** | Attacker targets cloud metadata endpoints (AWS `169.254.169.254/latest/meta-data/`, GCP `metadata.google.internal`, Azure `169.254.169.254/metadata/`) to obtain IAM credentials |
| **Anti-Pattern** | Relying on URL format validation (can be bypassed with IP encoding, DNS rebinding, or redirect chains) |
| **Stack Notes** | AWS IMDSv2 requires `X-aws-ec2-metadata-token` header (mitigates if enforced). GCP/Azure: similar metadata services with their own header requirements. |
| **Why Missed** | Claude validates URL format but does not specifically check for cloud metadata endpoint deny rules in SSRF-prone contexts |

---

## Open Redirect

| Aspect | Detail |
|--------|--------|
| **Signal** | Redirect destination constructed from user input: query parameter, form field, or stored URL used in `redirect()`, `302 Location`, or `window.location` |
| **Attack** | Attacker crafts URL that passes validation but redirects to malicious site (path-relative: `//evil.com`, protocol-relative: `javascript:`, backslash: `\/\/evil.com`) |
| **Anti-Pattern** | Checking only that the URL starts with `/` (can be bypassed with `//evil.com` or `/\evil.com`) |
| **Stack Notes** | Rails: `redirect_to` with user params. Express: `res.redirect(req.query.next)`. Django: `HttpResponseRedirect` with `next` parameter (built-in `is_safe_url` helper exists but must be called explicitly). |
| **Why Missed** | Claude validates against full URL injection (`https://evil.com`) but not protocol-relative or path-based redirect manipulation |

---

## Template Injection

### Server-Side Template Injection (SSTI)

| Aspect | Detail |
|--------|--------|
| **Signal** | User input passed to template engine's render/compile function as part of the template string (not as a template variable) |
| **Attack** | Attacker injects template syntax (`{{7*7}}` Jinja2, `${7*7}` Freemarker, `<%= 7*7 %>` ERB) to achieve server-side code execution |
| **Anti-Pattern** | Using string concatenation to build templates dynamically rather than passing user input as template variables |
| **Stack Notes** | Jinja2: `Template(user_input).render()` is vulnerable; `render_template(file, var=user_input)` is safe. ERB: `ERB.new(user_input).result` is vulnerable. Pug/Handlebars: less common but possible via `compile()` with user input. |
| **Why Missed** | Claude validates output escaping in template rendering but does not check whether user input is used to construct the template itself |

---

## Excluded Basic Variants

The following are excluded because Claude catches them unprompted during standard review:

| Pattern | Why Excluded |
|---------|-------------|
| Direct `innerHTML = userInput` | Claude flags any direct `innerHTML` assignment with user-controlled data |
| `eval(userInput)` or `new Function(userInput)` | Claude flags `eval`-family functions with user input consistently |
| `"SELECT * FROM users WHERE id = " + userId` | Claude flags string-concatenated SQL in all contexts |
| `<img src="x" onerror="alert(1)">` in user content | Claude checks for event handler injection in user-facing HTML |
| `os.system(user_input)` / `exec(user_input)` | Claude flags command injection via shell execution with user input |
