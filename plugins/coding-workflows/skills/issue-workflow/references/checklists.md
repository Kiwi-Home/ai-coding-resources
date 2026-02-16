# Checklists

Quick-reference checklists for planning and execution phases. See the core issue-workflow skill for the full workflow rules and decision criteria.

---

## Planning Checklist

- [ ] Requirements extracted and verified
- [ ] Build vs buy research completed
- [ ] Existing solutions evaluated with clear recommendation
- [ ] Codebase explored for related code and patterns
- [ ] Implementation plan drafted
- [ ] Plan posted to issue as comment (checked for duplicates first)
- [ ] **STOPPED** to wait for review (unless autonomous mode)

## Execution Checklist

- [ ] Project context resolved (Step 0)
- [ ] Issue and comments read
- [ ] Implementation plan found
- [ ] Feature branch created
- [ ] Implementation follows plan (or plan updated if changed)
- [ ] Tests written and passing
- [ ] Linter passing
- [ ] **Verification gate passed** (fresh evidence, not "should work")
- [ ] **Spec compliance checked** (nothing missing, nothing extra)
- [ ] **Deferred work tracked** (inline fixes completed, follow-up issues created for above-threshold deferrals)
- [ ] PR created with issue reference
- [ ] **ENTERED CI + REVIEW LOOP** (do NOT stop after push)
- [ ] CI passing
- [ ] **CI pass is not review approval** -- continued to review step (not stopped here)
- [ ] Lint failures fixed
- [ ] Review received
- [ ] All blocking items addressed
- [ ] **Verified unqualified approval** (no conditions attached)
- [ ] Loop repeated until clean approval OR 3 iterations
- [ ] **STOPPED** to await merge decision
- [ ] Merged only when explicitly instructed

## Agent Team Additions

- [ ] Non-overlapping file assignments per agent
- [ ] All agent tasks completed and integration tests pass
- [ ] All agents shut down and team cleaned up
