# Evidence Hierarchy

Not all diagnostic evidence is equal. Prioritize gathering high-signal evidence before acting on lower-signal information.

| Quality | Evidence Type | Example |
|---------|--------------|---------|
| **High-signal** | Exact error message + stack trace | `TypeError: Cannot read property 'id' of undefined at UserService.js:42` |
| **High-signal** | Minimal reproduction | "Fails when input array is empty, passes for any non-empty array" |
| **High-signal** | Git bisect result | "First failure introduced in commit `abc123` which changed the auth middleware" |
| **Medium-signal** | Logs showing state at failure point | "Request payload was `{user: null}` at the point of failure" |
| **Medium-signal** | Related test results | "All user tests pass but all admin tests fail -- suggests permission layer issue" |
| **Low-signal** | "It works on my machine" | Environment difference, not a diagnosis |
| **Low-signal** | "I think it might be..." | Hypothesis without evidence |
| **Low-signal** | "I'm confident this will fix it" | Confidence is not evidence |

## Combining Signals

Individual signals are useful; combined signals are diagnostic. Look for convergent evidence:

- **Error message + related test results** = localized vs systemic classification
- **Stack trace + git log** = regression identification (did the failing frame change recently?)
- **Expected/actual output + data trace** = pinpoint the divergence step
- **CI environment + local environment** = environment class confirmation

When two high-signal items point to the same cause, that hypothesis should rank first. When signals conflict, gather more evidence before hypothesizing.
