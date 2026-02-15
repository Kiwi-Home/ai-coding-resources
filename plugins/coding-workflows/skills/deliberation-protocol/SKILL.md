---
name: deliberation-protocol
description: >
  Governs multi-round specialist deliberation for design sessions,
  plan reviews, and adversarial dispatch. Defines conflict detection,
  dispatch rounds, cross-pollination, and resolution protocols. Referenced
  during design sessions, plan reviews, and adversarial plan challenges.
domains: [deliberation, conflict-resolution]
user-invocable: false
---

# Deliberation Protocol

This protocol governs multi-round specialist deliberation in `/coding-workflows:design-session`, `/coding-workflows:plan-issue`, and `/coding-workflows:review-plan`. For parallel code execution teams (file ownership, TDD, git), see the `coding-workflows:agent-team-protocol` skill.

---

## Invariants

- **MAX_ROUNDS**: 3 (specialist dispatch rounds)
- **MAX_SPECIALISTS**: 4
- **Session budget**: ~10 minutes total (advisory)
- **Per-phase guidelines**: Round 1 (~4 min), Round 2 (~3 min), Round 3 (~2 min), Shutdown (~1 min)

---

## Conflict Detection

Conflict potential between specialists is determined by:

1. **Check explicit overrides** in `.claude/workflow.yaml` under `deliberation.conflict_overrides`. If an override exists for the specialist pair, use its level.
2. **If no override exists**, default to LOW.

Multi-round deliberation activates when ANY specialist pair in the dispatch set has HIGH conflict potential.

When no conflict overrides are configured: all pairs default to LOW, meaning single-round dispatch only.

> **To enable multi-round deliberation:** Add conflict overrides to `.claude/workflow.yaml`:
> ```yaml
> deliberation:
>   conflict_overrides:
>     - { agent_a: "my-architect", agent_b: "my-api-reviewer", level: "HIGH" }
> ```

---

## Phase 1: Setup

**Agent-team mode** (when `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set):
1. **Orphan check**: Use Glob for `~/.claude/teams/deliberation-*` before creating. If orphans found with the target name, remove them.
2. `TeamCreate` with deterministic name based on subject type:
   - Issue: `deliberation-issue-{number}-{cmd}` (e.g., `deliberation-issue-228-design-session`)
   - PR: `deliberation-pr-{number}-{cmd}`
   - File/topic: `deliberation-{cmd}-{unix-timestamp}`
3. Spawn specialists using their `subagent_type` from agent frontmatter
4. `TaskCreate` per specialist (no file ownership, no blockedBy)
5. Spawn prompt MUST include:
   ```
   You may ONLY communicate with the chair. Do NOT send messages to other specialists.
   ```

**Task mode** (default, no env var): No setup needed. Task calls are self-contained.

---

## Phase 2: Round 1 Dispatch (advisory: ~4 minutes)

- **Agent-team mode**: `SendMessage` to each specialist with focused question
- **Task mode**: Parallel `Task` calls with focused questions
- Both modes: Specialist output must include a Confidence Assessment block
- If any specialist has not responded and the chair is ready to proceed: continue without them

---

## Phase 3: Conflict Detection & Round 2 (advisory: ~3 minutes)

1. Chair synthesizes round 1 responses (consensus, conflicts, gaps)
2. **Short-circuit**: If no conflicts detected (all specialists agree and no key concern contradicts another's finding), skip to Phase 5
3. **Conflict detected**: Dispatch round 2 to conflicting specialists only
   - **Agent-team mode**: `SendMessage` with chair's conflict summary
   - **Task mode**: New `Task` call with round 1 context + conflict summary in prompt
4. Round 2 prompt template:
   ```
   [Specialist X] raised [concern]. Your round 1 response [proposed Y]. How does your approach account for [concern]?
   ```

---

## Phase 4: Resolution & Optional Round 3 (advisory: ~2 minutes)

- If round 2 resolved conflicts: proceed to Phase 5
- **Non-engagement short-circuit**: If a specialist's round 2 response does not substantively address the conflict question, treat their round 1 position as final. Do not re-prompt. See engagement criteria below.
- If round 2 produced no new information (no specialist engaged per the criteria below): skip round 3, chair resolves using confidence-weighted rules from round 1 responses
- If conflicts persist: ONE more round (round 3) with specific resolution question, OR chair decides using confidence-weighted rules
- After round 3 OR MAX_ROUNDS reached: chair decides regardless
- Escalation: If all specialists express low confidence after final round, escalate to human

### Engagement Criteria (Round 2 "New Information" Heuristic)

A specialist **has engaged** in round 2 if their response introduces reasoning not present in their round 1 output. The conclusion may stay the same -- what matters is whether the specialist addressed the conflict with new analysis.

| Response pattern | Engaged? | Example |
|-----------------|----------|---------|
| New argument for same conclusion | Yes | "I still recommend X, but here's why Y's concern doesn't apply: [new reasoning]" |
| Changed recommendation | Yes | "After considering Y's point, I'd revise to Z" |
| Acknowledged trade-off with analysis | Yes | "Y is right about the risk, but the mitigation is [new detail]" |
| Restated round 1 position verbatim or near-verbatim | No | "As I said, X is the right approach" |
| Dismissed without analysis | No | "Already addressed in round 1" |
| No response | No | (specialist did not reply) |

**Bright-line rule:** New reasoning about the conflict = engaged. Same words, different conflict = not engaged.

> **Anti-pattern:** Re-prompting a specialist who has declined to engage in round 2. If a specialist restates their round 1 position or says the conflict is "already addressed," further prompting wastes budget without changing the outcome.

---

## Phase 5: Shutdown (advisory: ~1 minute)

**Agent-team mode**:
1. `SendMessage(type: "shutdown_request")` to each specialist
2. `TeamDelete`. If TeamDelete fails after retry, clean up manually:
   ```bash
   rm -rf ~/.claude/teams/<team-name> ~/.claude/tasks/<team-name>
   ```
3. Use Glob to verify no orphaned `deliberation-*` dirs remain.

**Task mode**: No cleanup needed (Task calls are self-contained).

---

## TeamCreate Failure Fallback

If `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set but TeamCreate fails:
1. Log warning: `TeamCreate failed, falling back to Task-based dispatch`
2. Fall back to Task-based multi-round dispatch (same protocol phases, different dispatch mechanism)
3. Session continues without interruption

---

## Budget Enforcement

Per-phase budgets (Round 1: 4 min, Round 2: 3 min, Round 3: 2 min, Shutdown: 1 min) are **advisory guidelines**, not programmatic timeouts.

**Hard constraint:** `MAX_ROUNDS=3`. This is the only enforceable limit. After 3 rounds, the chair decides regardless of resolution state.

**Advisory budget purpose:** The declining budget pattern (4/3/2/1) signals the chair to:
- Reduce prompt complexity in later rounds
- Narrow focus to unresolved conflicts only
- Converge toward resolution, not diverge into new topics

**Exceeded budget protocol:**
1. If a specialist has not responded and the chair is ready to proceed: continue without them
2. If rounds are taking longer than budgeted: the session continues (budgets do not abort phases)
3. After `MAX_ROUNDS` exhausted: chair decides using confidence-weighted resolution rules from Phase 4

**Observability data points** the chair should track as internal state during session execution (these do not appear in session output -- they inform chair decisions about budget and round progression):
- Rounds used vs MAX_ROUNDS
- Specialists dispatched vs responded (per round)
- Conflicts detected and resolution method (short-circuit / consensus / chair decision)

The session output templates (Context Budget section in `/coding-workflows:design-session`) already capture the user-facing summary: specialist dispatch scope (files and lines per specialist). The observability data points above are complementary internal state that the chair uses to decide when to short-circuit, escalate, or terminate -- they do not need separate output formatting.

> **Note:** Sessions may exceed the ~10-minute total guideline. The session-level budget is a planning heuristic, not a hard ceiling.
