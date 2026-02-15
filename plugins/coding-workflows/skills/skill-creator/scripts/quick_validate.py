#!/usr/bin/env python3
"""
Quick validation script for skills - minimal version
"""

import re
import sys
from pathlib import Path

import yaml


def validate_skill(skill_path):
    """Basic validation of a skill"""
    skill_path = Path(skill_path)

    # Check SKILL.md exists
    skill_md = skill_path / "SKILL.md"
    if not skill_md.exists():
        return False, "SKILL.md not found"

    # Read and validate frontmatter
    content = skill_md.read_text()
    frontmatter, error = _parse_frontmatter(content)
    if error:
        return False, error

    # Validate content
    # Canonical source: Anthropic Claude Code skill frontmatter specification
    # https://docs.anthropic.com/en/docs/claude-code/skills
    ALLOWED_PROPERTIES = {
        "name", "description", "allowed-tools", "argument-hint",
        "disable-model-invocation", "user-invocable", "model",
        "context", "agent", "hooks",
        # Internal provenance fields (used by generate-assets / asset-discovery)
        "domains", "generated_by", "generated_at",
    }
    unexpected_keys = set(frontmatter.keys()) - ALLOWED_PROPERTIES
    if unexpected_keys:
        return False, (
            f"Unexpected key(s) in SKILL.md frontmatter: {', '.join(sorted(unexpected_keys))}. "
            f"Allowed properties are: {', '.join(sorted(ALLOWED_PROPERTIES))}"
        )

    required_error = _check_required_fields(frontmatter)
    if required_error:
        return False, required_error

    name_error = _validate_name(frontmatter.get("name", ""))
    if name_error:
        return False, name_error

    desc_error = _validate_description(frontmatter.get("description", ""))
    if desc_error:
        return False, desc_error

    ref_error = _validate_referenced_resources(skill_path, content)
    if ref_error:
        return False, ref_error

    return True, "Skill is valid!"


def _parse_frontmatter(content):
    if not content.startswith("---"):
        return None, "No YAML frontmatter found"

    match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
    if not match:
        return None, "Invalid frontmatter format"

    try:
        frontmatter = yaml.safe_load(match.group(1))
        if not isinstance(frontmatter, dict):
            return None, "Frontmatter must be a YAML dictionary"
        return frontmatter, None
    except yaml.YAMLError as e:
        return None, f"Invalid YAML in frontmatter: {e}"


def _check_required_fields(frontmatter):
    if "name" not in frontmatter:
        return "Missing 'name' in frontmatter"
    if "description" not in frontmatter:
        return "Missing 'description' in frontmatter"
    return None


def _validate_name(name):
    if not isinstance(name, str):
        return f"Name must be a string, got {type(name).__name__}"
    name = name.strip()
    if name:
        if not re.match(r"^[a-z0-9-]+$", name):
            return f"Name '{name}' should be hyphen-case (lowercase letters, digits, and hyphens only)"
        if name.startswith("-") or name.endswith("-") or "--" in name:
            return f"Name '{name}' cannot start/end with hyphen or contain consecutive hyphens"
        if len(name) > 64:
            return f"Name is too long ({len(name)} characters). Maximum is 64 characters."
    return None


def _validate_referenced_resources(skill_path, content):
    """Check that resource directories referenced in SKILL.md body exist."""
    # Extract the body (after frontmatter)
    match = re.match(r"^---\n.*?\n---\n?(.*)", content, re.DOTALL)
    if not match:
        return None
    body = match.group(1)

    # Strip fenced code blocks to avoid matching illustrative examples
    body_no_code = re.sub(r"```.*?```", "", body, flags=re.DOTALL)

    # Strip markdown link targets to avoid false positives: [text](references/file.md)
    body_no_code = re.sub(r"\]\([^)]*\)", "]()", body_no_code)
    # Strip markdown link text to avoid false positives: [references/file.md](url)
    body_no_code = re.sub(r"\[[^\]]*\]", "[]", body_no_code)

    resource_dirs = {"scripts", "references", "assets"}
    missing = []
    for dir_name in resource_dirs:
        # Match local resource references: "scripts/foo.py", "See references/bar.md"
        # Skip cross-skill references (e.g., "`skill-name` references/file.md")
        matches = re.finditer(rf"(?<!\S){dir_name}/\S+", body_no_code)
        is_local = False
        for m in matches:
            line_start = body_no_code.rfind("\n", 0, m.start()) + 1
            prefix = body_no_code[line_start:m.start()]
            # Skip if preceded by a backtick-wrapped skill name (cross-skill ref)
            if re.search(r"`[a-z0-9:-]+`\s*$", prefix):
                continue
            is_local = True
            break
        if is_local:
            dir_path = skill_path / dir_name
            if not dir_path.exists():
                missing.append(dir_name)

    if missing:
        dirs = ", ".join(sorted(missing))
        return (
            f"SKILL.md references missing resource director{'ies' if len(missing) > 1 else 'y'}: "
            f"{dirs}. Create {'them' if len(missing) > 1 else 'it'} or remove the references."
        )
    return None


def _validate_description(description):
    if not isinstance(description, str):
        return f"Description must be a string, got {type(description).__name__}"
    description = description.strip()
    if description:
        if "<" in description or ">" in description:
            return "Description cannot contain angle brackets (< or >)"
        if len(description) > 1024:
            return f"Description is too long ({len(description)} characters). Maximum is 1024 characters."
    return None


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python quick_validate.py <skill_directory>")
        sys.exit(1)

    valid, message = validate_skill(sys.argv[1])
    print(message)
    sys.exit(0 if valid else 1)
