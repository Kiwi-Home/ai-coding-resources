#!/usr/bin/env python3
"""Tests for quick_validate.py"""

import tempfile
import textwrap
from pathlib import Path

import pytest

from quick_validate import (
    _parse_frontmatter,
    _validate_description,
    _validate_name,
    _validate_referenced_resources,
    validate_skill,
)


def _make_skill(tmp_path, body="", *, frontmatter=None, dirs=None):
    """Helper: create a minimal valid skill directory with SKILL.md."""
    if frontmatter is None:
        frontmatter = "name: test-skill\ndescription: A test skill"
    content = f"---\n{frontmatter}\n---\n{body}"
    (tmp_path / "SKILL.md").write_text(content)
    for d in dirs or []:
        (tmp_path / d).mkdir(parents=True, exist_ok=True)
    return tmp_path


# --- Frontmatter parsing ---


class TestParseFrontmatter:
    def test_valid(self):
        fm, err = _parse_frontmatter("---\nname: foo\n---\nbody")
        assert err is None
        assert fm == {"name": "foo"}

    def test_missing_frontmatter(self):
        _, err = _parse_frontmatter("no frontmatter here")
        assert "No YAML frontmatter" in err

    def test_invalid_format(self):
        _, err = _parse_frontmatter("---\nname: foo\n")
        assert "Invalid frontmatter" in err

    def test_non_dict_frontmatter(self):
        _, err = _parse_frontmatter("---\n- list item\n---\n")
        assert "must be a YAML dictionary" in err

    def test_invalid_yaml(self):
        _, err = _parse_frontmatter("---\n: bad: yaml:\n---\n")
        assert "Invalid YAML" in err


# --- Name validation ---


class TestValidateName:
    def test_valid_name(self):
        assert _validate_name("my-skill") is None

    def test_valid_name_with_digits(self):
        assert _validate_name("skill-v2") is None

    def test_uppercase_rejected(self):
        err = _validate_name("MySkill")
        assert "hyphen-case" in err

    def test_leading_hyphen_rejected(self):
        err = _validate_name("-skill")
        assert "cannot start/end" in err

    def test_trailing_hyphen_rejected(self):
        err = _validate_name("skill-")
        assert "cannot start/end" in err

    def test_consecutive_hyphens_rejected(self):
        err = _validate_name("my--skill")
        assert "consecutive hyphens" in err

    def test_too_long(self):
        err = _validate_name("a" * 65)
        assert "too long" in err

    def test_empty_name_ok(self):
        assert _validate_name("") is None

    def test_non_string(self):
        err = _validate_name(123)
        assert "must be a string" in err


# --- Description validation ---


class TestValidateDescription:
    def test_valid(self):
        assert _validate_description("A useful skill") is None

    def test_angle_brackets_rejected(self):
        err = _validate_description("Use <thing>")
        assert "angle brackets" in err

    def test_too_long(self):
        err = _validate_description("x" * 1025)
        assert "too long" in err

    def test_non_string(self):
        err = _validate_description(42)
        assert "must be a string" in err


# --- Resource reference validation ---


class TestValidateReferencedResources:
    def test_local_reference_with_dir(self, tmp_path):
        """Local reference to scripts/ with directory present passes."""
        _make_skill(tmp_path, body="Run scripts/deploy.py to deploy.", dirs=["scripts"])
        err = _validate_referenced_resources(tmp_path, (tmp_path / "SKILL.md").read_text())
        assert err is None

    def test_local_reference_missing_dir(self, tmp_path):
        """Local reference to scripts/ without directory fails."""
        _make_skill(tmp_path, body="Run scripts/deploy.py to deploy.")
        err = _validate_referenced_resources(tmp_path, (tmp_path / "SKILL.md").read_text())
        assert "missing resource directory" in err
        assert "scripts" in err

    def test_code_block_excluded(self, tmp_path):
        """References inside fenced code blocks are ignored."""
        body = textwrap.dedent("""\
            Some text.

            ```bash
            scripts/example.py --help
            ```

            More text.
        """)
        _make_skill(tmp_path, body=body)
        err = _validate_referenced_resources(tmp_path, (tmp_path / "SKILL.md").read_text())
        assert err is None

    def test_cross_skill_reference_excluded(self, tmp_path):
        """Backtick-wrapped cross-skill references are ignored."""
        body = "See `knowledge-freshness` references/guide.md for details."
        _make_skill(tmp_path, body=body)
        err = _validate_referenced_resources(tmp_path, (tmp_path / "SKILL.md").read_text())
        assert err is None

    def test_markdown_link_target_excluded(self, tmp_path):
        """Paths in markdown link targets are not flagged: [text](references/file.md)"""
        body = "See [the guide](references/api.md) for details."
        _make_skill(tmp_path, body=body)
        err = _validate_referenced_resources(tmp_path, (tmp_path / "SKILL.md").read_text())
        assert err is None

    def test_markdown_link_text_excluded(self, tmp_path):
        """Paths in markdown link text are not flagged: [references/file.md](url)"""
        body = "See [references/api.md](https://example.com/api) for details."
        _make_skill(tmp_path, body=body)
        err = _validate_referenced_resources(tmp_path, (tmp_path / "SKILL.md").read_text())
        assert err is None

    def test_markdown_link_both_excluded(self, tmp_path):
        """Links with resource paths in both text and target are not flagged."""
        body = "See [references/api.md](references/api.md) for details."
        _make_skill(tmp_path, body=body)
        err = _validate_referenced_resources(tmp_path, (tmp_path / "SKILL.md").read_text())
        assert err is None

    def test_multiple_missing_dirs(self, tmp_path):
        """Multiple missing directories are all reported."""
        body = "Use scripts/run.sh and references/guide.md and assets/logo.png."
        _make_skill(tmp_path, body=body)
        err = _validate_referenced_resources(tmp_path, (tmp_path / "SKILL.md").read_text())
        assert "missing resource directories" in err
        assert "assets" in err
        assert "references" in err
        assert "scripts" in err

    def test_no_body(self, tmp_path):
        """Content with no body after frontmatter returns no error."""
        _make_skill(tmp_path, body="")
        err = _validate_referenced_resources(tmp_path, (tmp_path / "SKILL.md").read_text())
        assert err is None

    def test_plain_text_reference_still_detected(self, tmp_path):
        """Plain text references outside of links/code are still detected."""
        body = "See references/guide.md for patterns."
        _make_skill(tmp_path, body=body)
        err = _validate_referenced_resources(tmp_path, (tmp_path / "SKILL.md").read_text())
        assert "missing resource directory" in err
        assert "references" in err


# --- Full skill validation ---


class TestValidateSkill:
    def test_valid_minimal_skill(self, tmp_path):
        """Minimal valid skill passes."""
        _make_skill(tmp_path)
        valid, msg = validate_skill(tmp_path)
        assert valid
        assert "valid" in msg

    def test_missing_skill_md(self, tmp_path):
        """Missing SKILL.md fails."""
        valid, msg = validate_skill(tmp_path)
        assert not valid
        assert "SKILL.md not found" in msg

    def test_missing_name(self, tmp_path):
        """Missing name field fails."""
        _make_skill(tmp_path, frontmatter="description: test")
        valid, msg = validate_skill(tmp_path)
        assert not valid
        assert "Missing 'name'" in msg

    def test_missing_description(self, tmp_path):
        """Missing description field fails."""
        _make_skill(tmp_path, frontmatter="name: test")
        valid, msg = validate_skill(tmp_path)
        assert not valid
        assert "Missing 'description'" in msg

    def test_unexpected_frontmatter_key(self, tmp_path):
        """Unexpected frontmatter key fails."""
        _make_skill(tmp_path, frontmatter="name: test\ndescription: test\ncustom-key: bad")
        valid, msg = validate_skill(tmp_path)
        assert not valid
        assert "Unexpected key" in msg
        assert "custom-key" in msg

    def test_valid_with_all_dirs(self, tmp_path):
        """Skill with references to existing resource dirs passes."""
        body = "See references/guide.md and scripts/run.py and assets/logo.png."
        _make_skill(tmp_path, body=body, dirs=["references", "scripts", "assets"])
        valid, msg = validate_skill(tmp_path)
        assert valid


# --- Validate all existing skills in the repo ---


class TestExistingSkills:
    """Regression tests: all existing skills in the repo must pass validation."""

    @staticmethod
    def _skill_dirs():
        repo_root = Path(__file__).resolve().parent.parent.parent.parent.parent.parent
        skills_dir = repo_root / "plugins" / "coding-workflows" / "skills"
        if not skills_dir.exists():
            return []
        return sorted(d for d in skills_dir.iterdir() if d.is_dir() and (d / "SKILL.md").exists())

    @pytest.mark.parametrize("skill_dir", _skill_dirs.__func__(), ids=lambda d: d.name)
    def test_existing_skill_valid(self, skill_dir):
        valid, msg = validate_skill(skill_dir)
        assert valid, f"{skill_dir.name}: {msg}"
