# Token Budget Methodology

Reference for the skills token budget used in `generate-assets` agent generation.

## Aggregate Budget: ~5,000 Tokens

The recommended aggregate budget for frontmatter-injected skills is ~5,000
tokens per agent. This is a soft recommendation, not a hard limit.

**Rationale:** Skills injected via frontmatter `skills:` compete with
conversation history, tool results, and system prompt for effective context
space. While ~5,000 tokens is only ~2.5% of a 200K raw context window, the
usable context after system prompt, tool definitions, and conversation history
is significantly smaller. Over-injecting skills crowds out the working context
needed for the agent's actual task.

## Measuring Skill Token Counts

To estimate a skill's token count:
- **Quick estimate:** Count the file's characters and divide by ~3.5-4.0
  (the typical character-to-token ratio for English markdown content).
- **Precise measurement:** Use the Anthropic tokenizer or `claude tokenize`.

The range ~3.5-4.0 accounts for variability between prose-heavy content
(closer to 4.0) and code/table-heavy content (closer to 3.5).

## Keeping Estimates Current

The token estimate for each universal skill (e.g., ~1,273 for
`knowledge-freshness`) appears in multiple locations in `generate-assets.md`.
The **canonical location** is the first occurrence in the universal skills
list (the bullet item listing the skill and its token count). All other
occurrences (context budget math, agent template comments) must be updated
to match if the skill changes significantly.

**When a universal skill is updated:** Re-estimate its token count using the
methods above and update the canonical location. Then search the command file
for the old value and update all occurrences.

## Why No Per-Skill Size Threshold

Earlier designs included a per-skill size gate (e.g., reject skills over
2,000 characters). This was evaluated and removed because:

1. **Redundant with aggregate budget.** The aggregate budget check already
   caps total injection. A single oversized skill blows the aggregate budget
   naturally, triggering the existing warning.
2. **Character count is a poor proxy.** Token counts vary by content type
   (prose ~4.0 chars/token, code/tables ~3.5). A character threshold would
   need constant recalibration.
3. **False positives.** Comprehensive skills (e.g., a full framework
   conventions guide at 1,800 chars) would be rejected despite fitting
   comfortably within the aggregate budget alongside one or two smaller skills.

The aggregate budget provides the same safety net without the false-positive
penalty.

## When to Adjust the Budget

| Signal | Action |
|--------|--------|
| Agents frequently hit context limits during complex tasks | Lower the budget or restructure skills to reduce overlap |
| Agents lack domain knowledge they need | Consider increasing the budget or splitting large skills into focused sub-skills |
| New universal skills added to the workflow | Recalculate the baseline and adjust the remaining domain budget |
| Context window size increases significantly | The budget may scale proportionally, but re-evaluate based on actual system prompt and tool overhead |
