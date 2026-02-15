# Version Discovery

Lookup methods and guidance for verifying dependency versions during planning.

> **Context:** See the core issue-workflow skill for when version discovery is required.
> This file provides the specific commands and fallback chain for version verification.

---

## Research Tools Available

When researching existing solutions:

- **Web search**: Search for libraries and patterns
- **Context7 MCP**: Look up library documentation
- **GitHub search**: Find similar implementations
- **Package registries**: Check package maintenance status

---

## Version Lookup Methods (in order of preference)

### 1. Context7 (fastest, includes docs)

```
mcp__context7__resolve-library-id libraryName="package-name"
```

### 2. Package Registry APIs (reliable)

```bash
# Python (PyPI)
curl -s "https://pypi.org/pypi/PACKAGE/json" | jq -r '.info.version'

# JavaScript (npm)
curl -s "https://registry.npmjs.org/PACKAGE/latest" | jq -r '.version'

# Ruby (RubyGems)
curl -s "https://rubygems.org/api/v1/gems/GEM.json" | jq -r '.version'

# Rust (crates.io)
curl -s "https://crates.io/api/v1/crates/CRATE" | jq -r '.crate.max_stable_version'

# Go
go list -m -versions MODULE
```

### 3. WebSearch (fallback)

```
WebSearch "PACKAGE latest stable version [current year]"
```

### 4. If All Fail

Document "version unverified - using [version] from [source], recommend human verification"

---

## When to Use Older Versions

Always document the rationale when pinning to a non-latest version:

- Newer version has known breaking bugs
- Compatibility matrix requires it
- Production system already uses it and upgrade is out of scope
- Pre-release is latest but you need stable
