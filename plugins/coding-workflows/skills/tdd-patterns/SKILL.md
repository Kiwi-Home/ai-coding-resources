---
name: tdd-patterns
description: |
  Stack-aware TDD patterns, anti-patterns, and quality heuristics for
  test-driven development. Provides framework-agnostic testing knowledge
  that adapts guidance based on detected technology stack. Targets
  AI-specific testing failure modes.
triggers:
  - /coding-workflows:execute-issue
  - reviewing test quality
domains: [testing, tdd, quality]
---

# TDD Patterns

## When to Use

Consult this skill when writing tests during TDD loops, planning testing strategy, or reviewing test quality. It provides patterns that address common AI-assisted TDD failure modes: happy-path-only testing, over-mocking, weak assertions, and integration tests disguised as unit tests.

This skill does not replace the procedural TDD loop in `execute-issue` (RED/GREEN/REFACTOR cycle, exit code gates, full suite gate). It provides the testing **knowledge** that makes those tests meaningful.

Stack-specific sections below are navigable without `coding-workflows:stack-detection` -- jump directly to your stack's heading.

---

## Universal TDD Patterns

### Test Selection

Test behavior through the public API, not implementation details.

**Corrective**: Claude tends to test whatever is easiest to access -- private helpers, internal state, intermediate variables. These tests break on every refactor and prove nothing about behavior.

| Test This | Not This |
|-----------|----------|
| Return values from public methods | Internal helper function calls |
| Observable side effects (DB writes, API calls, events) | Private state mutations |
| Error messages/codes returned to callers | Internal exception handling paths |
| User-facing output (rendered HTML, API response shape) | Component internal DOM structure |

**Rule**: If you must access a private member to write the test, you are testing the wrong thing. Find the public boundary where the behavior is observable.

### Assertion Quality

Assert behavior, not existence.

| Weak (proves little) | Strong (proves behavior) |
|----------------------|-------------------------|
| `assert result is not None` | `assert result.status == "completed"` |
| `expect(component).toBeDefined()` | `expect(component).toHaveTextContent("Success")` |
| `assert len(errors) > 0` | `assert errors[0].code == "VALIDATION_FAILED"` |

**Decision rule**: If the assertion would still pass with a completely wrong implementation, it is too weak. Each assertion should fail if the behavior it tests is broken.

### Test Isolation

Mock at system boundaries only. Use real objects for everything else.

**Corrective**: Claude defaults to mocking because mocks are easier to generate. Resist. Mock at system boundaries (external APIs, databases, network, file system, clock). Use real objects for in-process dependencies.

| Mock This (system boundary) | Do NOT Mock This (in-process) |
|-----------------------------|-------------------------------|
| HTTP clients / API calls | Service classes your code owns |
| Database connections | Data models / value objects |
| File system operations | Pure utility functions |
| Time / clock | Configuration objects |
| Message queues / external services | In-memory caches |

**Why over-mocking hurts**: When you mock an in-process dependency, your test verifies that you called the mock correctly -- not that your code works. Change the dependency's interface and your tests still pass while production breaks.

### Layer-Appropriate Testing

Not textbook definitions -- project-aware heuristics for what to test at each layer.

**Corrective**: Claude writes integration tests disguised as unit tests. A unit test exercises one function with controlled inputs. If your test requires a running server, database connection, or multi-service setup, it is an integration test -- label and organize it accordingly.

| Layer | Unit Test Focus | Integration Test Focus |
|-------|----------------|----------------------|
| Models / Types | Validation rules, computed properties, serialization | N/A (pure data) |
| Services / Logic | Business rules with injected dependencies | Cross-service workflows |
| API / Routes | Request parsing, response shape, error codes | Full request lifecycle |
| Storage / Data Access | Query construction (if applicable) | Actual database operations |

**Heuristic**: Count your test's dependencies. 0-1 real dependencies = unit test. 2+ real dependencies or any I/O = integration test. This classification determines where the test lives and when it runs.

---

## Anti-Patterns

| Anti-Pattern | Why It's Harmful | Do This Instead |
|-------------|-----------------|-----------------|
| **Testing implementation details** | Tests break on every refactor even when behavior is unchanged. Maintenance cost grows linearly with codebase size. | Test through the public API. Verify outputs and side effects, not internal call sequences. |
| **Over-mocking** | Tests verify mock call sequences, not actual behavior. Interface changes go undetected -- mocks still conform to the old interface. | Mock only at system boundaries. Use real objects for in-process dependencies. Prefer fakes over mocks when the boundary is complex. |
| **Testing the framework** | Verifying that Rails validates presence, FastAPI parses JSON, or React renders a div wastes test budget on code you did not write. | Test YOUR logic that uses the framework. Test that your validation rule rejects bad input, not that validation exists. |
| **Tautological assertions** | Tests that always pass prove nothing. `assert add(2, 3) == add(2, 3)` or `expect(mock).toHaveBeenCalledWith(mock.calls[0])` are self-referential. | Each assertion must have a concrete expected value. If you cannot state the expected value without calling the code under test, the assertion is tautological. |
| **Write-all-then-test** | Defers test writing until after all implementation is complete. Tests become afterthoughts that verify the existing code rather than driving its design. The `execute-issue` command enforces against this via the TDD loop -- this entry explains **why**. | Follow RED/GREEN/REFACTOR per component. Write the test first, see it fail, then implement. |

---

## Test Quality Heuristics

### Boundary Coverage

Test the edges, not just the middle.

| Boundary Type | Test Cases |
|--------------|------------|
| Empty / zero / null | Empty string, zero value, null/None/nil, empty collection |
| Single element | One-item list, single character, minimum valid input |
| Boundary values | Max int, max length, off-by-one (n-1, n, n+1) |
| Invalid input | Wrong type, negative where positive expected, malformed format |

**Check**: For each parameter in the function under test, can you identify at least one boundary test? If not, your coverage is incomplete.

### Error Path Coverage

Happy paths are easy to test. Error paths catch production bugs.

| Operation Type | Required Error Tests |
|---------------|---------------------|
| External API call | Timeout, 4xx, 5xx, malformed response, network failure |
| Database operation | Connection failure, constraint violation, not found |
| User input processing | Missing required field, invalid format, exceeds limits |
| File operations | Not found, permission denied, corrupted content |

**Ratio guidance**: At least 1 error-path test for every 2 happy-path tests. If your test file has 10 happy-path tests and 0 error-path tests, your coverage is dangerously lopsided.

**Check**: Count error-path tests vs happy-path tests. If the ratio is below 1:2, add error tests before proceeding.

### Assertion Specificity

Five levels, from weakest to strongest:

| Level | Example | Proves |
|-------|---------|--------|
| 1. Existence | `assert result is not None` | Something was returned |
| 2. Type | `assert isinstance(result, User)` | Correct type was returned |
| 3. Shape | `assert "email" in result` | Expected fields exist |
| 4. Value | `assert result["email"] == "test@example.com"` | Correct data |
| 5. Behavior | `assert result.is_active` after calling `activate()` | Correct state transition |

**Target level 4-5 for business logic.** Levels 1-3 are acceptable only for smoke tests or infrastructure checks.

**Check**: Remove the implementation (replace with `pass`, `return null`, or `throw`). Do your tests still pass? If yes, they test nothing meaningful.

### Test Independence

Each test must pass in isolation, in any order, at any time.

**Red flags:**
- Tests share mutable state (class variables, global config, database rows without cleanup)
- Test B depends on Test A running first (sequential coupling)
- Tests fail when run individually but pass in the full suite (or vice versa)
- Tests fail on different dates/times (time coupling)

**Check**: Run a single test file in isolation. Does every test pass? Run the full suite in reverse order. Same results?

---

## Stack-Specific Testing Strategies

These sections provide testing idioms specific to each ecosystem. For stack identification, see `coding-workflows:stack-detection`. Each section covers 3-4 patterns and 2 stack-specific anti-patterns.

### JavaScript / TypeScript (Frontend)

**Component testing**: Render the component and assert on output, not internal state. Use `screen.getByRole()` or `screen.getByText()` over `container.querySelector()`. Testing Library's queries enforce accessible patterns.

**Hook testing**: Test hooks through a component that uses them, not by calling the hook directly. If the hook is complex enough to test in isolation, use `renderHook()` and assert on returned values -- never on internal state.

**Async UI**: Use `waitFor()` for assertions that depend on async state updates. Never use `setTimeout` or `sleep` in tests -- these create flaky timing dependencies.

**Event testing**: Fire events through `userEvent` (simulates real browser behavior) rather than `fireEvent` (synthetic, skips intermediate browser events).

Stack-specific anti-patterns:
- **Snapshot overuse**: Snapshot tests are change detectors, not behavior tests. They pass when wrong and fail when right (after intentional UI changes). Use snapshots only for serialization formats, never for UI behavior.
- **Testing CSS/styling**: Assert on behavior and accessibility, not on class names or computed styles. `expect(element).toHaveClass('active')` tests implementation; `expect(element).toHaveAttribute('aria-selected', 'true')` tests behavior.

### Python (Backend)

**Pytest fixtures**: Use fixture scoping deliberately. `function` scope (default) for test isolation. `session` scope only for expensive, read-only resources (database engines, API clients). Mutable fixtures must be `function`-scoped.

**Async endpoint testing**: Use `httpx.AsyncClient` with `ASGITransport` for FastAPI, or `pytest-django`'s `async_client` for Django. Test the full request-response cycle, not the handler function directly.

**Parametrize for boundary coverage**: Use `@pytest.mark.parametrize` for boundary testing instead of duplicating test functions. Group related boundary cases in a single parametrize decorator.

**Factory patterns**: Use `factory_boy` or simple factory functions for test data. Avoid creating test data with raw constructors -- factories centralize defaults and make tests resilient to model changes.

Stack-specific anti-patterns:
- **Fixture chains**: Deep fixture dependency chains (`fixture_a` -> `fixture_b` -> `fixture_c`) make test setup opaque. If you cannot understand a test's setup without tracing 3+ fixtures, flatten the chain.
- **Monkeypatching internals**: `monkeypatch.setattr` on internal module functions couples tests to implementation. Inject dependencies at construction time instead.

### Ruby (Backend)

**RSpec context nesting**: Use `context` blocks to group tests by scenario. Keep nesting to 3 levels maximum (`describe` -> `context` -> `it`). Deeper nesting signals the unit under test does too much.

**factory_bot vs fixtures**: Use `factory_bot` for unit tests (explicit setup, no hidden state). Use fixtures for integration/system tests where performance matters and setup complexity is tolerable.

**Request specs for APIs**: Test API endpoints through request specs (`get`, `post`, etc.), not controller specs. Request specs exercise middleware, routing, and serialization -- controller specs skip all of these.

**Shared examples for common behaviors**: Extract common behavior tests into `shared_examples`. Use when 3+ models/controllers share identical behavior (e.g., soft-deletable, auditable).

Stack-specific anti-patterns:
- **`allow_any_instance_of`**: Mocks every instance of a class -- overly broad and hides which instance matters. Inject the dependency and mock the specific instance.
- **`before(:all)` with mutable state**: Shared mutable state across examples creates order-dependent failures. Use `before(:each)` or `let` for mutable setup.

### Go (Backend)

**Table-driven tests**: Use the `[]struct{name, input, expected}` pattern for parameterized testing. Include boundary cases in the table rather than as separate test functions.

**Interface-based test doubles**: Define narrow interfaces (`Reader`, `Notifier`) at the consumer, not the provider. Test doubles implement only the interface methods needed. This avoids importing production dependencies in tests.

**httptest for handlers**: Use `httptest.NewRequest` + `httptest.NewRecorder` for handler unit tests. Use `httptest.NewServer` for integration tests that need a running server.

**Test helpers with t.Helper()**: Mark helper functions with `t.Helper()` so test failures report the caller's line number, not the helper's.

Stack-specific anti-patterns:
- **Init functions in test files**: `init()` in test files runs before all tests and creates hidden global state. Use `TestMain(m *testing.M)` for controlled setup/teardown.
- **Goroutine leaks in tests**: Tests that spawn goroutines without waiting for completion leak resources and cause flaky failures. Use `sync.WaitGroup` or `t.Cleanup()` to ensure all goroutines complete.

### Other Stacks

If your stack is not listed above, apply the universal patterns from the preceding sections. The principles -- test behavior not implementation, assert with specificity, cover boundaries and error paths, maintain test independence -- are stack-agnostic. Adapt the concrete examples to your ecosystem's testing framework and idioms.

---

## Cross-References

- `coding-workflows:execute-issue` -- procedural TDD enforcement (RED/GREEN/REFACTOR loop, exit code gates)
- `coding-workflows:agent-team-protocol` -- TDD workflow for parallel agent teams
- `coding-workflows:stack-detection` -- technology stack identification tables
- `coding-workflows:issue-workflow` -- testing strategy during planning phase
