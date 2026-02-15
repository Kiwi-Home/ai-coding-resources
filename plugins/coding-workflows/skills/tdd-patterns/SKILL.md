---
name: tdd-patterns
description: |
  Stack-aware TDD patterns, anti-patterns, and quality heuristics for
  test-driven development. Provides framework-agnostic testing knowledge
  that adapts guidance based on detected technology stack. Targets
  AI-specific testing failure modes. Use when writing tests during TDD loops,
  reviewing test quality, or planning testing strategy.
domains: [testing, tdd, quality]
---

# TDD Patterns

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

See `references/stack-testing-strategies.md` for stack-specific testing idioms (JS/TS, Python, Ruby, Go). Read it when writing tests for a specific stack after applying the universal patterns above. Jump directly to your stack's heading.

---

## Cross-References

- `coding-workflows:execute-issue` -- procedural TDD enforcement (RED/GREEN/REFACTOR loop, exit code gates)
- `coding-workflows:agent-team-protocol` -- TDD workflow for parallel agent teams
- `coding-workflows:stack-detection` -- technology stack identification tables
- `coding-workflows:issue-workflow` -- testing strategy during planning phase
