# AI Coding Resources

A Claude Code plugin marketplace for engineering workflows.

## Installation

```bash
/plugin marketplace add Kiwi-Home/ai-coding-resources
/plugin install coding-workflows@ai-coding-resources
```

## Quick Start

```
/coding-workflows:prepare-issue 42    # Design session + plan + review
/coding-workflows:execute-issue 42    # Implement with TDD, create PR
```

That's it. The plugin auto-detects your project settings. Run `/coding-workflows:help` for the full command list.

For project-specific agents and review config:

```
/coding-workflows:setup
```
<img width="1024" height="559" alt="image" src="https://github.com/user-attachments/assets/51476839-c380-4c5c-912f-fec6ce4ba7b4" />


## What's in the Box

**coding-workflows** — a complete issue-to-merge workflow:

- **Write issues** with structured requirements and acceptance criteria
- **Design sessions** with multi-specialist deliberation and conflict resolution
- **Plan implementations** with mandatory build-vs-buy research and codebase exploration
- **Adversarial plan review** before any code is written
- **TDD execution** with verification gates and spec compliance checks
- **PR review** with severity-tiered findings, usable from CLI or CI
- **CI + review loop** automation with strict merge criteria

Works with zero config, or generate project-specific agents and review settings from your codebase. Three tiers: zero-config → configured → full setup.

See the [plugin README](plugins/coding-workflows/README.md) for the full command reference, configuration options, and FAQ.

## License

MIT
