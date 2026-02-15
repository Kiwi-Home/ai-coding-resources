---
name: issue-writer
description: Writes requirements-focused issues that describe what needs to be done, not how to implement it. Works with any tracker (GitHub, Linear, Jira, Asana). Use when creating issues, updating requirements, or planning work.
domains: [issues, requirements]
---

# Issue Writer Skill

Write requirements-focused issues that describe **what** needs to be done, not **how** to implement it. Works with any tracker: GitHub, Linear, Jira, Asana, etc.

## Issue Structure

### Required Sections

```markdown
## Overview
[1-2 sentences describing the problem or need]

## Problem
[What's wrong or missing? Why does this matter?]

## Requirements
[What must the solution accomplish? Describe behaviors, not code.]

## Acceptance Criteria
- [ ] [Measurable outcome 1]
- [ ] [Measurable outcome 2]

## Constraints
[What limitations must the implementation respect?]

## Dependencies
[What other work must complete first? Link to issues.]

## Reference
[Links to docs, prior issues, or relevant context]
```

### Optional Sections

- **Research Notes**: Prior research, architectural decisions, or context from closed issues. Link to sources rather than duplicating content.
- **Non-Goals**: Explicitly out of scope
- **Open Questions**: Decisions needed before implementation
- **Security Considerations**: If relevant

## Anti-Patterns to Avoid

**Never include in issues:**

1. **Code blocks with implementation**
   - ❌ `class UserModel < ApplicationRecord`
   - ❌ `def process_data(input)`
   - ✅ "The system should validate user input"

2. **Specific class/method/file names**
   - ❌ "Add method `calculate_score` to `ScoreService`"
   - ✅ "Provide a way to calculate user scores"

3. **Numeric estimates**
   - ❌ "This should take 4-6 hours"
   - ❌ "Requires ~15 test files"
   - ✅ "Should have comprehensive test coverage"

4. **Implementation phases**
   - ❌ "Phase 1: Create models, Phase 2: Add API"
   - ✅ Describe the end-state requirements

5. **Hardcoded thresholds**
   - ❌ "Set timeout to 30 seconds"
   - ✅ "Timeout should be configurable"

## Why This Matters

- **Separation of concerns**: Requirements define "what", implementation defines "how"
- **Flexibility**: Implementer can research and choose the best approach
- **Longevity**: Requirements stay valid even if implementation changes
- **Clarity**: Reviewers can verify requirements are met without understanding implementation

## Validation Checklist

Before creating an issue, verify:

- [ ] No code blocks showing implementation
- [ ] No specific class/method/file names
- [ ] No time or effort estimates
- [ ] No implementation phases or steps
- [ ] Acceptance criteria are behavior-focused
- [ ] Could be implemented in any language/framework

## Examples

### ❌ Bad Issue

```markdown
## Add User Authentication

Create `AuthService` class with `login(email, password)` method.
Use bcrypt for password hashing. Add migration for users table
with email, password_digest columns. Estimated: 4 hours.

Phase 1: Models (2 hours)
Phase 2: Controllers (1.5 hours)
Phase 3: Tests (0.5 hours)
```

### ✅ Good Issue

```markdown
## Overview
Users need to authenticate to access protected features.

## Problem
Currently all features are publicly accessible. We need to
restrict certain actions to logged-in users.

## Requirements
- Users can create accounts with email and password
- Users can log in with valid credentials
- Invalid credentials are rejected with clear feedback
- Sessions persist across browser restarts
- Password storage follows security best practices

## Acceptance Criteria
- [ ] New users can register
- [ ] Existing users can log in
- [ ] Protected routes redirect to login
- [ ] Passwords are never stored in plaintext

## Constraints
- Must work with existing user data if any
- Should not require third-party auth services

## Reference
- OWASP Authentication Guidelines
```
