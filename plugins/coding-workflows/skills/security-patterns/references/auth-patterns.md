# Authentication and Authorization Patterns

Read when: reviewing diffs that touch authentication, authorization, or session handling.

Covers attacks exploiting insufficient verification of **identity and permission** -- who is making the request and what they are allowed to do. Basic variants (missing login check, plaintext password storage) are excluded; Claude catches these unprompted.

## Table of Contents

- [Insecure Direct Object Reference (IDOR)](#insecure-direct-object-reference-idor)
- [Cross-Site Request Forgery (CSRF)](#cross-site-request-forgery-csrf)
- [Session Management](#session-management)
- [Authorization Bypass](#authorization-bypass)
- [JWT Vulnerabilities](#jwt-vulnerabilities)
- [Time-of-Check to Time-of-Use (TOCTOU)](#time-of-check-to-time-of-use-toctou)
- [Mass Assignment](#mass-assignment)
- [Excluded Basic Variants](#excluded-basic-variants)

---

## Insecure Direct Object Reference (IDOR)

### Horizontal Privilege Escalation

| Aspect | Detail |
|--------|--------|
| **Signal** | Route parameter or query parameter used directly as database lookup key: `/api/users/:id/profile`, `Order.find(params[:id])`, `SELECT * FROM orders WHERE id = ?` without `AND user_id = ?` |
| **Attack** | Authenticated user changes the ID parameter to access another user's resource |
| **Anti-Pattern** | Validating that the ID is a valid format (integer, UUID) without checking ownership |
| **Stack Notes** | Rails: `current_user.orders.find(params[:id])` is safe; `Order.find(params[:id])` is not. Django: `get_object_or_404(Order, pk=pk, user=request.user)`. Express: must add ownership check manually. |
| **Why Missed** | Claude validates parameter type and existence but does not trace whether ownership scoping is applied to the query |

### Vertical Privilege Escalation

| Aspect | Detail |
|--------|--------|
| **Signal** | Admin-only action accessible via direct API call without role check; role stored in client-accessible location (cookie, JWT claims) without server verification |
| **Attack** | Regular user calls admin endpoint directly or modifies their role claim to escalate privileges |
| **Anti-Pattern** | Hiding admin UI elements without protecting admin API endpoints; trusting client-side role claims |
| **Stack Notes** | React+API: hiding admin buttons is UI-only; API must enforce role checks independently. JWT: role claims in payload are readable and modifiable if server only validates signature (not claim values). |
| **Why Missed** | Claude checks that auth middleware exists but does not verify that role-based authorization is enforced at the API layer separately from UI visibility |

---

## Cross-Site Request Forgery (CSRF)

### Token Validation Bypass

| Aspect | Detail |
|--------|--------|
| **Signal** | State-changing endpoint (POST/PUT/DELETE) with CSRF token check that accepts empty token, missing token header, or token from a different session |
| **Attack** | Attacker crafts a form or XHR that omits the CSRF token or reuses a token obtained from the attacker's own session |
| **Anti-Pattern** | Checking token presence but not binding it to the user's session; accepting requests without the token header when the body token is missing |
| **Stack Notes** | Rails: CSRF protection is on by default but `skip_before_action :verify_authenticity_token` disables it. Django: `@csrf_exempt` decorator. Express: `csurf` middleware (deprecated; use `csrf-csrf` or `lusca`). SPA: double-submit cookie pattern requires `SameSite` attribute coordination. |
| **Why Missed** | Claude validates that CSRF middleware is present but does not check for exemption decorators on state-changing endpoints or verify token-session binding |

### SameSite Cookie Gaps

| Aspect | Detail |
|--------|--------|
| **Signal** | Authentication cookie set without explicit `SameSite` attribute, or set to `SameSite=None` without `Secure` flag |
| **Attack** | Cross-origin requests carry the session cookie, enabling CSRF even without a traditional CSRF token bypass |
| **Anti-Pattern** | Relying entirely on `SameSite=Lax` (default in modern browsers) without realizing it permits top-level GET navigations that may trigger state changes |
| **Stack Notes** | Express: `cookie-session` and `express-session` do not set `SameSite` by default. Rails 6.1+: sets `SameSite=Lax` by default. Django 2.1+: `CSRF_COOKIE_SAMESITE = 'Lax'` by default. |
| **Why Missed** | Claude checks for cookie `Secure` and `HttpOnly` flags but does not verify `SameSite` attribute alignment with the application's cross-origin requirements |

---

## Session Management

### Session Fixation

| Aspect | Detail |
|--------|--------|
| **Signal** | Session ID not regenerated after authentication state change (login, privilege escalation, password change) |
| **Attack** | Attacker sets a known session ID before victim authenticates; after authentication, attacker uses the same session ID to hijack the authenticated session |
| **Anti-Pattern** | Regenerating the session ID only on login but not on privilege escalation or role change |
| **Stack Notes** | Rails: `reset_session` must be called explicitly on login. Express: `req.session.regenerate()`. Django: `request.session.cycle_key()` (called automatically on `login()` but not on privilege changes). PHP: `session_regenerate_id(true)`. |
| **Why Missed** | Claude verifies session creation on login but does not check for regeneration on all authentication state transitions |

### Concurrent Session Management

| Aspect | Detail |
|--------|--------|
| **Signal** | Password change or account recovery flow that does not invalidate existing sessions |
| **Attack** | Attacker who has stolen a session token retains access even after the legitimate user changes their password |
| **Anti-Pattern** | Changing the password in the database without invalidating the session store or rotating session-bound tokens |
| **Stack Notes** | Most frameworks do NOT automatically invalidate other sessions on password change. Requires explicit session store cleanup or token rotation. Django: `update_session_auth_hash()` prevents current session logout but doesn't invalidate others. |
| **Why Missed** | Claude validates password change logic (hashing, validation) but does not check for downstream session invalidation |

---

## Authorization Bypass

### Missing Middleware on New Routes

| Aspect | Detail |
|--------|--------|
| **Signal** | New route/endpoint added without auth middleware that peer routes in the same resource have; route group or controller has auth but individual action skips it |
| **Attack** | Unauthenticated or unauthorized access to the new endpoint while all other endpoints are protected |
| **Anti-Pattern** | Adding a route to an authenticated controller but forgetting to apply the auth decorator/middleware; using route-level auth that doesn't cascade to child routes |
| **Stack Notes** | Express: middleware order matters; adding a route before `app.use(authMiddleware)` bypasses it. Rails: `before_action` with `except:` or `only:` can miss new actions. Django: `@login_required` must be added per-view unless using a mixin. FastAPI: `Depends(get_current_user)` must be added per-route or via router dependency. |
| **Why Missed** | Claude reviews existing middleware chains but does not verify coverage of newly added routes by comparing against peer route protection |

### Route Parameter Confusion

| Aspect | Detail |
|--------|--------|
| **Signal** | Nested route where parent resource ID and child resource ID are both parameters, but only the child ID is validated for ownership |
| **Attack** | Attacker accesses `/users/123/orders/456` where order 456 belongs to user 123 but the attacker is user 789; system checks attacker owns order 456 (which they might via a different user association) but not that it belongs to user 123 |
| **Anti-Pattern** | Validating child resource ownership without enforcing parent-child relationship |
| **Stack Notes** | Rails nested resources: `resources :users { resources :orders }` does not automatically scope the child lookup. Express: `/users/:userId/orders/:orderId` requires manual scoping. |
| **Why Missed** | Claude validates parameter types and ownership for individual resources but does not trace parent-child relationship enforcement in nested routes |

---

## JWT Vulnerabilities

### Algorithm Confusion (alg:none / RS256->HS256)

| Aspect | Detail |
|--------|--------|
| **Signal** | JWT library configured to accept algorithm from token header rather than server-side configuration; verification function accepts algorithm as parameter derived from the token |
| **Attack** | Attacker changes JWT `alg` header to `none` (skipping verification) or switches from RS256 to HS256 (using the public key as HMAC secret) |
| **Anti-Pattern** | `jwt.verify(token, publicKey)` without specifying `algorithms: ['RS256']` -- library may accept the algorithm from the token header |
| **Stack Notes** | Node `jsonwebtoken`: vulnerable if `algorithms` option is not explicitly set. Python `PyJWT`: requires explicit `algorithms` parameter since v2.x. Ruby `ruby-jwt`: requires `algorithms` parameter. Go `golang-jwt`: type-safe key validation prevents HS256/RS256 confusion. |
| **Why Missed** | Claude validates JWT parsing and signature verification but does not check whether the algorithm is server-enforced or token-derived |

### JWT Claim Validation

| Aspect | Detail |
|--------|--------|
| **Signal** | JWT verified for signature but claims (`exp`, `iss`, `aud`, `nbf`) not validated; or claims validated but used before verification completes |
| **Attack** | Attacker uses an expired token, a token issued for a different service, or a token not yet valid |
| **Anti-Pattern** | Checking `jwt.verify()` succeeds but not configuring `issuer`, `audience`, or `clockTolerance` options |
| **Stack Notes** | Node `jsonwebtoken`: `verify(token, key, {issuer, audience})` -- options are not required. Python `PyJWT`: `decode(token, key, algorithms, options={})` -- expiration check is on by default but audience/issuer are not. |
| **Why Missed** | Claude validates that JWT verification is called but does not check completeness of claim validation options |

---

## Time-of-Check to Time-of-Use (TOCTOU)

| Aspect | Detail |
|--------|--------|
| **Signal** | Permission check (database query, role lookup, feature flag) followed by a separate operation (resource access, mutation) with no transactional or locking guarantee |
| **Attack** | Permission is revoked or resource state changes between the check and the use; concurrent request exploits the gap |
| **Anti-Pattern** | `if (user.hasPermission('delete')) { await deleteResource(id); }` -- permission could be revoked between check and delete |
| **Stack Notes** | Database: use `SELECT ... FOR UPDATE` or transaction isolation. Redis: use `WATCH`/`MULTI`/`EXEC` for atomic check-and-act. Application-level: minimize window between check and use; prefer single-query authorization patterns (e.g., `DELETE FROM resources WHERE id = ? AND user_id = ?`). |
| **Why Missed** | Claude reviews permission checks and resource operations independently but does not evaluate the temporal gap and concurrency exposure between them |

---

## Mass Assignment

| Aspect | Detail |
|--------|--------|
| **Signal** | Request body or params passed directly to model create/update without allowlisting fields: `User.create(req.body)`, `user.update(params)`, `serializer.save()` without explicit `fields` |
| **Attack** | Attacker adds unexpected fields (`is_admin: true`, `role: 'superuser'`, `balance: 999999`) to the request body |
| **Anti-Pattern** | Using a denylist (`except: [:is_admin]`) instead of an allowlist (`only: [:name, :email]`) -- new sensitive fields are unprotected by default |
| **Stack Notes** | Rails: strong parameters (`params.require(:user).permit(:name, :email)`) is the standard protection. Django: `ModelForm` `fields` attribute (allowlist) vs `exclude` (denylist). Express/Mongoose: no built-in protection; must destructure or validate explicitly. |
| **Why Missed** | Claude validates that input is used in a model operation but does not verify that field-level allowlisting is applied, especially when frameworks don't enforce it by default |

---

## Excluded Basic Variants

The following are excluded because Claude catches them unprompted during standard review:

| Pattern | Why Excluded |
|---------|-------------|
| Missing authentication check on sensitive route | Claude flags routes handling sensitive data without any auth middleware |
| Plaintext password storage | Claude flags any password storage without hashing |
| Hardcoded admin credentials | Claude flags hardcoded credentials in authentication logic |
| Missing `HttpOnly` flag on session cookies | Claude checks cookie security attributes consistently |
| `Access-Control-Allow-Origin: *` on authenticated endpoints | Claude flags permissive CORS on authenticated routes |
