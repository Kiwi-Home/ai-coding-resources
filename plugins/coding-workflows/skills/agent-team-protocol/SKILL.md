---
name: agent-team-protocol
description: >
  Governs parallel code execution teams with file ownership, TDD workflow,
  git coordination, and team lifecycle management. Defines spawn templates,
  timeout policies, and shutdown procedures. Referenced during parallel
  execution phases of issue implementation.
domains: [execution, agent-teams]
user-invocable: false
---

# Agent Team Protocol

This protocol governs parallel code execution teams (file ownership, TDD, git). For multi-round specialist deliberation, see the `coding-workflows:deliberation-protocol` skill.

Reference protocol for `execute-issue` when using parallel agent teams.
Invoked when Execution Topology guard clause routes here.

---

## Phase 0: Contract-First Handoff (~5 min)

Lead defines interface contracts on the feature branch:

1. Write model/type shells -- field names and types only, no validators or logic
2. Write interface/protocol method signatures -- return types, no logic
3. Add module exports for new modules
4. Commit to feature branch

**Guidance:** Write interface contracts in the project's type system. Examples:
- **Python**: Pydantic models, Protocol/ABC classes
- **TypeScript**: interfaces and type definitions
- **Rust**: trait definitions and struct shells
- **Go**: interface definitions
- **Ruby**: method signatures with YARD docs

Phase 0 should produce <20 lines per model. If writing more, you are over-specifying.

Optionally write integration test skeletons marked as skipped (e.g., `pytest.mark.skip`, `it.skip`, `#[ignore]`).

---

## Phase 1: Team Setup

1. TeamCreate with descriptive name (e.g., `"issue-42-feature-name"`)
2. TaskCreate per independent layer. One task per layer (not per TDD step). Description includes:
   - Plan excerpt for this layer
   - Exact files the agent owns
   - Test command (from resolved config)
   - "Follow TDD-First Completion Loop independently"
3. TaskUpdate with `addBlockedBy` for layer dependencies:
   - Models/types layer: no dependencies
   - Service/logic layer: blockedBy models if it imports model types
   - API/route layer: blockedBy models
   - Integration: blockedBy all layers (lead handles)
4. Spawn one `general-purpose` agent per task via Task with `team_name` and `name`
5. TaskUpdate to assign `owner` per agent

---

## Phase 2: Parallel Execution

Agents work independently:

- Run TDD-First Completion Loop on assigned layer
- Commit ONLY owned files (`git add` by specific filename, NEVER `git add .`)
- `git pull --rebase` before each commit
- **If push fails**: run `git pull --rebase` and retry up to 3 times
- **NEVER modify root-level test config or shared module exports** -- create layer-specific test fixtures in your test subdirectory
- Mark task completed via TaskUpdate when all layer tests pass
- If cannot resolve after 3 attempts: SendMessage to lead, do NOT mark completed

---

## Phase 3: Convergence Check

Wait for idle notifications (automatic, do NOT poll in tight loop).
Check TaskList to confirm all tasks completed.

1. `git pull --rebase`
2. Run the full test suite from resolved config
3. Run the typecheck command from resolved config (if configured) with cross-boundary checking
4. If failures: lead fixes interface mismatches directly

**Partial failure recovery:**
- If team times out (15-minute cap): run `git log` and the test suite to assess state
- If tests fail due to missing layers: identify which layers are incomplete
- Complete incomplete layers sequentially (lead implements)
- Do NOT discard completed agents' work -- it is already committed

---

## Phase 4: Integration

1. Fill in test skeletons with real assertions
2. Register routes/handlers in shared files (lead only)
3. Run integration tests from resolved config
4. Cross-layer refactoring happens here, not during Phase 2

**Lead role clarity:**
- Lead WRITES: contract shells (Phase 0), shared file modifications (Phase 4), integration tests (Phase 4), interface mismatch fixes (Phase 3)
- Lead does NOT WRITE: layer-specific implementation code or unit tests -- those belong to agents

---

## Phase 5: Shutdown

1. SendMessage(`type: shutdown_request`) to each agent, sequentially (not broadcast)
2. Wait 60 seconds for `shutdown_response` per agent
   - Approved: proceed to next
   - Rejected: address agent's concern first
   - No response: proceed (agent will timeout)
3. TeamDelete (retry up to 2x)
4. **Final cleanup**: If TeamDelete fails after 2 retries, remove team directories:
   ```bash
   [ -n "$TEAM_NAME" ] && rm -rf ~/.claude/teams/$TEAM_NAME ~/.claude/tasks/$TEAM_NAME
   ```
5. **Orphan check at startup**: Before creating a new team, check `ls ~/.claude/teams/` for orphans from previous sessions

---

## Spawn Prompt Template

Each agent receives (mandatory sections):

```
## Your Assignment
[Task subject]

## Plan Excerpt
[Layer-specific section from plan]

## File Ownership (CRITICAL)
You own ONLY these files:
- [file list]
Do NOT edit files outside this list.
NEVER modify root-level test config -- create your own in your test subdirectory.
If you need a file you don't own changed, message the lead.

## Git Workflow
Branch: {branch from resolved config branch_pattern}
Before every commit:
1. git pull --rebase
2. git add [your files by name -- NEVER git add .]
3. git commit
4. git push (if push fails, pull --rebase and retry up to 3x)

## TDD Workflow
Read the `coding-workflows:tdd-patterns` skill for stack-appropriate test patterns.
1. RED: Write test, confirm fails for right reason
2. GREEN: Minimum implementation to pass
3. REFACTOR: lint + typecheck, confirm still passing
Test command: {commands.test.focused from resolved config}

## Completion
All tests passing -> TaskUpdate(completed)
3 failed attempts on same error -> SendMessage to lead, do NOT mark completed
```

---

## Team Timeout

Maximum team duration: 15 minutes from TeamCreate. If not all tasks complete:

1. Send `shutdown_request` to all agents
2. Wait 30 seconds
3. TeamDelete (force cleanup if needed)
4. Complete remaining work sequentially
5. Note timeout in Session Checkpoint
