# Planning Templates

Output format templates for Phase 1 of the issue workflow.

> **Context:** See the core issue-workflow skill for workflow rules, step sequencing, and evaluation criteria.
> This file provides the markdown templates to use when drafting each planning section.

---

## Step 1: Requirements Extraction Template

```markdown
## Requirements Extracted

**Problem**: [1-2 sentences - what's broken or missing?]

**Must Have**:
- [ ] Requirement 1
- [ ] Requirement 2

**Constraints**:
- Constraint 1
- Constraint 2

**Success Criteria**:
- [ ] Acceptance criterion 1
- [ ] Acceptance criterion 2

**Dependencies**: [Issues that must complete first, or "None"]

**Open Questions**: [Ambiguities that need clarification before proceeding]
```

---

## Step 2: Research & Evaluation Templates

### 2a. Existing Solutions Table

```markdown
## Research: Existing Solutions

**Search queries used**:
- "[language] [problem domain] library"
- "[framework] [feature] package"

**Solutions Found**:

| Solution | Type | Maintenance | Compatibility | Fit |
|----------|------|-------------|---------------|-----|
| package-name | Library | Active/Stale | [runtime] | Good/Partial/Poor |

**Evaluation**:
- Option A: [library] - Pros: ... Cons: ...
- Option B: [different library] - Pros: ... Cons: ...
- Option C: Build native - Pros: ... Cons: ...
```

### 2b. Evaluation Criteria

For each potential solution, check:

- **Maintenance**: Last commit, open issues, release frequency
- **Compatibility**: Runtime version, dependency conflicts
- **Adoption**: GitHub stars, downloads, production usage
- **Fit**: Does it solve 80%+ of requirements? What's missing?
- **Complexity**: Setup burden, learning curve, operational overhead
- **Current Version**: Verify latest stable (see `references/version-discovery.md`)

> **IMPORTANT**: For EVERY new dependency you plan to add, verify the current stable version. Never rely on training data versions.

### 2c. Recommendation Format

```markdown
## Recommendation

**Approach**: [Use X / Build native / Hybrid]

**Rationale**: [Why this option over alternatives]

**Trade-offs accepted**: [What we're giving up]

**Risks**: [What could go wrong]
```

---

## Step 3: Codebase Context Template

```markdown
## Codebase Context

**Related code found**:
- `path/to/file` - Does X, could extend for Y

**Existing patterns to follow**:
- [Pattern name from project conventions]

**Code to modify vs create**:
- Modify: `existing_file` (add capability)
- Create: `new_file` (new responsibility)
```

---

## Step 4: Implementation Plan Template

```markdown
## Implementation Plan

### Approach
[High-level description of the solution]

### Files to Modify

| File | Change |
|------|--------|

> For plans with 3+ distinct layers, add Layer and Agent columns to enable parallel execution:
> | File | Change | Layer | Agent |
> |------|--------|-------|-------|

### Integration Points
- Integrates with: [existing code/systems]
- Affects: [other parts of codebase]

### Testing Strategy
- Unit tests for: [components]
- Integration tests for: [workflows]
- Edge cases: [specific scenarios]

### Rollout Considerations
- Migration needed: [yes/no, details]
- Feature flag: [yes/no]
```

> **Tip**: Reference `coding-workflows:tdd-patterns` for stack-appropriate testing strategies when filling in the Testing Strategy section.

**Note**: Backwards compatibility is NOT required unless explicitly requested in the issue.
Prefer clean implementations over compatibility shims for pre-production projects.
