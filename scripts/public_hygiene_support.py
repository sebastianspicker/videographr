"""Cohesive checks used by the public-surface hygiene verifier."""

from __future__ import annotations

import re
from pathlib import Path


def hidden_public_source_issues(
    root: Path,
    candidates: set[str],
    public_source_roots: tuple[str, ...],
    public_source_suffixes: set[str],
) -> list[str]:
    issues: list[str] = []
    for root_name in public_source_roots:
        source_root = root / root_name
        if source_root.exists():
            issues.extend(_hidden_source_files(root, source_root, candidates, public_source_suffixes))
    return issues


def _hidden_source_files(
    root: Path, source_root: Path, candidates: set[str], public_source_suffixes: set[str]
) -> list[str]:
    issues: list[str] = []
    for path in source_root.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in public_source_suffixes:
            continue
        relative = path.relative_to(root).as_posix()
        if relative not in candidates:
            issues.append(f"public source/doc is hidden by ignore rules: {relative}")
    return issues


def screenshot_set_issues(screenshot_root: Path, expected_screenshots: tuple[str, ...]) -> list[str]:
    actual_files = _screenshot_files(screenshot_root)
    if not actual_files:
        return []
    expected_files = {"README.md"}
    expected_files.update(
        f"{name}{suffix}" for name in expected_screenshots for suffix in (".png", ".txt")
    )
    return _screenshot_file_set_issues(expected_files, actual_files)


def _screenshot_files(screenshot_root: Path) -> set[str]:
    if not screenshot_root.is_dir():
        return set()
    return {path.name for path in screenshot_root.iterdir()}


def _screenshot_file_set_issues(expected_files: set[str], actual_files: set[str]) -> list[str]:
    issues: list[str] = []
    missing_screenshots = sorted(expected_files - actual_files)
    unexpected_screenshots = sorted(actual_files - expected_files)
    if missing_screenshots:
        issues.append(f"runtime screenshot set is incomplete: {', '.join(missing_screenshots)}")
    if unexpected_screenshots:
        issues.append(f"runtime screenshot set has stale files: {', '.join(unexpected_screenshots)}")
    return issues


def release_version_issues(root: Path, candidates: set[str]) -> tuple[list[str], str, str, str, str]:
    version = _release_version(root)
    numeric_version, alpha_build, release_notes = _release_version_parts(version)
    issues = _invalid_version_issues(version)
    if release_notes and release_notes not in candidates:
        issues.append(f"release notes are absent or ignored: {release_notes}")
    return issues, version, numeric_version, alpha_build, release_notes


def _release_version(root: Path) -> str:
    release_version_path = root / "RELEASE_VERSION"
    if release_version_path.exists():
        return release_version_path.read_text(encoding="utf-8").strip()
    return ""


def _release_version_parts(version: str) -> tuple[str, str, str]:
    if not version:
        return "", "", ""
    return version.split("-", 1)[0], version.rsplit(".", 1)[-1], f"docs/releases/{version}.md"


def _invalid_version_issues(version: str) -> list[str]:
    if re.fullmatch(r"\d+\.\d+\.\d+-alpha\.\d+", version):
        return []
    return [f"RELEASE_VERSION is not an alpha SemVer identifier: {version!r}"]


def release_text_issues(root: Path, version: str, release_notes: str, bundle_identity: str) -> list[str]:
    release_paths = (
        "README.md",
        "CHANGELOG.md",
        "RELEASE_STATUS.md",
        release_notes,
        ".github/ISSUE_TEMPLATE/bug_report.md",
    )
    issues = _missing_text_issues(root, release_paths, version, "release identifier")
    bundle_paths = ("RELEASE_STATUS.md", release_notes)
    issues.extend(_missing_text_issues(root, bundle_paths, bundle_identity, "app bundle identity"))
    return issues


def _missing_text_issues(root: Path, paths: tuple[str, ...], expected: str, label: str) -> list[str]:
    return [f"{label} {expected} missing from {relative}" for relative in paths if _missing_text(root / relative, expected)]


def _missing_text(path: Path, expected: str) -> bool:
    return path.is_file() and expected not in path.read_text(encoding="utf-8")
