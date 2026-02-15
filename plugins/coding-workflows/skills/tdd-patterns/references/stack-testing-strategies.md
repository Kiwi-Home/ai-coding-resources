# Stack-Specific Testing Strategies

These sections provide testing idioms specific to each ecosystem. For stack identification, see `coding-workflows:stack-detection`. Each section covers 3-4 patterns and 2 stack-specific anti-patterns. Jump directly to your stack's heading.

## JavaScript / TypeScript (Frontend)

**Component testing**: Render the component and assert on output, not internal state. Use `screen.getByRole()` or `screen.getByText()` over `container.querySelector()`. Testing Library's queries enforce accessible patterns.

**Hook testing**: Test hooks through a component that uses them, not by calling the hook directly. If the hook is complex enough to test in isolation, use `renderHook()` and assert on returned values -- never on internal state.

**Async UI**: Use `waitFor()` for assertions that depend on async state updates. Never use `setTimeout` or `sleep` in tests -- these create flaky timing dependencies.

**Event testing**: Fire events through `userEvent` (simulates real browser behavior) rather than `fireEvent` (synthetic, skips intermediate browser events).

Stack-specific anti-patterns:
- **Snapshot overuse**: Snapshot tests are change detectors, not behavior tests. They pass when wrong and fail when right (after intentional UI changes). Use snapshots only for serialization formats, never for UI behavior.
- **Testing CSS/styling**: Assert on behavior and accessibility, not on class names or computed styles. `expect(element).toHaveClass('active')` tests implementation; `expect(element).toHaveAttribute('aria-selected', 'true')` tests behavior.

## Python (Backend)

**Pytest fixtures**: Use fixture scoping deliberately. `function` scope (default) for test isolation. `session` scope only for expensive, read-only resources (database engines, API clients). Mutable fixtures must be `function`-scoped.

**Async endpoint testing**: Use `httpx.AsyncClient` with `ASGITransport` for FastAPI, or `pytest-django`'s `async_client` for Django. Test the full request-response cycle, not the handler function directly.

**Parametrize for boundary coverage**: Use `@pytest.mark.parametrize` for boundary testing instead of duplicating test functions. Group related boundary cases in a single parametrize decorator.

**Factory patterns**: Use `factory_boy` or simple factory functions for test data. Avoid creating test data with raw constructors -- factories centralize defaults and make tests resilient to model changes.

Stack-specific anti-patterns:
- **Fixture chains**: Deep fixture dependency chains (`fixture_a` -> `fixture_b` -> `fixture_c`) make test setup opaque. If you cannot understand a test's setup without tracing 3+ fixtures, flatten the chain.
- **Monkeypatching internals**: `monkeypatch.setattr` on internal module functions couples tests to implementation. Inject dependencies at construction time instead.

## Ruby (Backend)

**RSpec context nesting**: Use `context` blocks to group tests by scenario. Keep nesting to 3 levels maximum (`describe` -> `context` -> `it`). Deeper nesting signals the unit under test does too much.

**factory_bot vs fixtures**: Use `factory_bot` for unit tests (explicit setup, no hidden state). Use fixtures for integration/system tests where performance matters and setup complexity is tolerable.

**Request specs for APIs**: Test API endpoints through request specs (`get`, `post`, etc.), not controller specs. Request specs exercise middleware, routing, and serialization -- controller specs skip all of these.

**Shared examples for common behaviors**: Extract common behavior tests into `shared_examples`. Use when 3+ models/controllers share identical behavior (e.g., soft-deletable, auditable).

Stack-specific anti-patterns:
- **`allow_any_instance_of`**: Mocks every instance of a class -- overly broad and hides which instance matters. Inject the dependency and mock the specific instance.
- **`before(:all)` with mutable state**: Shared mutable state across examples creates order-dependent failures. Use `before(:each)` or `let` for mutable setup.

## Go (Backend)

**Table-driven tests**: Use the `[]struct{name, input, expected}` pattern for parameterized testing. Include boundary cases in the table rather than as separate test functions.

**Interface-based test doubles**: Define narrow interfaces (`Reader`, `Notifier`) at the consumer, not the provider. Test doubles implement only the interface methods needed. This avoids importing production dependencies in tests.

**httptest for handlers**: Use `httptest.NewRequest` + `httptest.NewRecorder` for handler unit tests. Use `httptest.NewServer` for integration tests that need a running server.

**Test helpers with t.Helper()**: Mark helper functions with `t.Helper()` so test failures report the caller's line number, not the helper's.

Stack-specific anti-patterns:
- **Init functions in test files**: `init()` in test files runs before all tests and creates hidden global state. Use `TestMain(m *testing.M)` for controlled setup/teardown.
- **Goroutine leaks in tests**: Tests that spawn goroutines without waiting for completion leak resources and cause flaky failures. Use `sync.WaitGroup` or `t.Cleanup()` to ensure all goroutines complete.

## Other Stacks

If your stack is not listed above, apply the universal patterns from the other stack sections above. The principles -- test behavior not implementation, assert with specificity, cover boundaries and error paths, maintain test independence -- are stack-agnostic. Adapt the concrete examples to your ecosystem's testing framework and idioms.
