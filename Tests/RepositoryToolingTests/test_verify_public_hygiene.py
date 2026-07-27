#!/usr/bin/env python3
"""Focused tests for public writing-policy classifications."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY_ROOT / "scripts"))

from verify_public_hygiene import _candidate_name_issues, _writing_policy_issues
from public_hygiene_support import screenshot_set_issues


class WritingPolicyTests(unittest.TestCase):
    def assert_policy_issue(self, text: str, relative: str, expected: str) -> None:
        self.assertTrue(
            any(expected in issue for issue in _writing_policy_issues(text, relative)),
            f"Expected {expected!r} for {relative}",
        )

    def assert_policy_clean(self, text: str, relative: str) -> None:
        self.assertEqual(_writing_policy_issues(text, relative), [])

    def test_rejects_literal_and_encoded_em_dashes(self) -> None:
        cases = (
            "alpha " + chr(0x2014) + " beta",
            "alpha " + "\\" + "u{2014} beta",
            "alpha " + "\\" + "u2014 beta",
            "alpha &" + "mdash; beta",
            "alpha &#" + "8212; beta",
        )
        for text in cases:
            with self.subTest(text=text):
                self.assert_policy_issue(text, "README.md", "em dash")

    def test_rejects_single_word_markdown_emphasis(self) -> None:
        for text in ("**Alpha**", "*Alpha*", "__Alpha__", "_Alpha_"):
            with self.subTest(text=text):
                self.assert_policy_issue(text, "README.md", "single-word Markdown emphasis")

    def test_allows_multiword_and_escaped_markdown(self) -> None:
        for text in ("**Alpha status**", "*Alpha status*", r"\*literal\*", "`**literal**`"):
            with self.subTest(text=text):
                self.assert_policy_clean(text, "README.md")

    def test_scans_only_markdown_rendered_swift_content_for_emphasis(self) -> None:
        self.assert_policy_clean("let value = a*b*c", "Sources/GuidanceEngine/Math.swift")
        self.assert_policy_clean("let value = a*b*c", "Sources/LearnContent/LearnCatalog.swift")
        rendered = 'let body = """\n**Alpha**\n"""'
        self.assert_policy_issue(
            rendered,
            "Sources/LearnContent/LearnCatalog.swift",
            "single-word Markdown emphasis",
        )

    def test_rejects_common_machine_specific_paths(self) -> None:
        paths = (
            "/" + "Users/alice/repo",
            "/" + "home/alice/repo",
            "/" + "root/repo",
            "D:" + "\\" + "Users\\alice\\repo",
        )
        for path in paths:
            with self.subTest(path=path):
                self.assert_policy_issue(path, "README.md", "machine-specific absolute path")

    def test_does_not_treat_web_url_paths_as_home_directories(self) -> None:
        self.assert_policy_clean("https://example.org/home/account", "README.md")


class CandidateNameTests(unittest.TestCase):
    def test_rejects_non_runtime_design_artifact_directories(self) -> None:
        for relative in ("docs/mockups/screen.png", "docs/_mockups/screen.png"):
            with self.subTest(relative=relative):
                path = Path(relative)
                issues = _candidate_name_issues(
                    relative,
                    set(path.parts),
                    path.name.lower(),
                    path.suffix.lower(),
                )
                self.assertTrue(any("non-runtime design artifact" in issue for issue in issues))


class ScreenshotSetTests(unittest.TestCase):
    def test_allows_no_published_screenshot_set(self) -> None:
        missing = REPOSITORY_ROOT / "Tests" / "RepositoryToolingTests" / "missing-screenshots"
        self.assertEqual(screenshot_set_issues(missing, ("one", "two")), [])

    def test_rejects_partial_published_screenshot_set(self) -> None:
        from tempfile import TemporaryDirectory

        with TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "README.md").write_text("# Manifest\n", encoding="utf-8")
            issues = screenshot_set_issues(root, ("one", "two"))
        self.assertTrue(any("runtime screenshot set is incomplete" in issue for issue in issues))


if __name__ == "__main__":
    unittest.main()
