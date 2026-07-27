#!/usr/bin/env python3
"""Validate and stage Videographr screenshot attachments from an xcresult export."""

from __future__ import annotations

import argparse
import json
import stat
from pathlib import Path
from uuid import UUID


EXPECTED_NAMES = (
    "01-setup-scoped-consent",
    "02-live-preroll-guidance",
    "03-live-simulator-recording-rejection",
    "04-reflect-laf",
    "05-learn-catalogue",
    "06-learn-method-detail",
    "07-info-scope",
    "08-info-pipeline",
)
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
REPOSITORY_ROOT = Path(__file__).resolve().parents[1]


class AttachmentError(RuntimeError):
    """Raised when the exported result bundle is not exact, safe evidence."""


def _canonical_attachment_name(suggested: str, expected_files: set[str]) -> str:
    """Normalize the exact name decoration added by newer xcresulttool exports."""
    if not _is_flat_file_name(suggested):
        raise AttachmentError(f"Unsafe suggested attachment name: {suggested!r}")
    matching_name = _matching_attachment_name(suggested, expected_files)
    if matching_name is None:
        raise AttachmentError(f"Unexpected XCTest attachment: {suggested}")
    return matching_name


def _matching_attachment_name(suggested: str, expected_files: set[str]) -> str | None:
    if suggested in expected_files:
        return suggested
    return next(
        (expected for expected in expected_files if _is_decorated_attachment_name(suggested, expected)),
        None,
    )


def _is_flat_file_name(name: str) -> bool:
    return Path(name).name == name and "\\" not in name


def _is_decorated_attachment_name(suggested: str, expected: str) -> bool:
    suggested_path = Path(suggested)
    expected_path = Path(expected)
    if suggested_path.suffix != expected_path.suffix:
        return False
    prefix = f"{expected_path.stem}_"
    if not suggested_path.stem.startswith(prefix):
        return False
    return _is_canonical_decoration(suggested_path.stem[len(prefix) :])


def _is_canonical_decoration(decoration: str) -> bool:
    occurrence, separator, identifier = decoration.partition("_")
    if not separator or not occurrence.isdigit():
        return False
    try:
        parsed_identifier = UUID(identifier)
    except ValueError:
        return False
    return identifier.lower() == str(parsed_identifier)


def _regular_file(directory: Path, exported_name: str) -> Path:
    if not exported_name or not _is_flat_file_name(exported_name):
        raise AttachmentError(f"Unsafe exported attachment name: {exported_name!r}")
    candidate = directory / exported_name
    try:
        mode = candidate.lstat().st_mode
    except FileNotFoundError as error:
        raise AttachmentError(f"Manifest attachment is missing: {exported_name}") from error
    if not stat.S_ISREG(mode):
        raise AttachmentError(f"Attachment is not a regular file: {exported_name}")
    return candidate


def _attachment_records(source: Path) -> list[dict[str, object]]:
    payload = _attachment_manifest(source)
    return [attachment for test_details in payload for attachment in _test_attachments(test_details)]


def _attachment_manifest(source: Path) -> list[object]:
    manifest_path = _regular_file(source, "manifest.json")
    try:
        payload = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise AttachmentError(f"Invalid xcresult attachment manifest: {error}") from error
    if not isinstance(payload, list) or not payload:
        raise AttachmentError("xcresult attachment manifest must be a non-empty array")
    return payload


def _test_attachments(test_details: object) -> list[dict[str, object]]:
    if not isinstance(test_details, dict):
        raise AttachmentError("Malformed test entry in attachment manifest")
    attachments = test_details.get("attachments")
    if not isinstance(attachments, list):
        raise AttachmentError("Attachment manifest test entry has no attachment array")
    if not all(isinstance(attachment, dict) for attachment in attachments):
        raise AttachmentError("Malformed attachment record")
    return attachments


def _expected_attachment_files() -> set[str]:
    return {f"{name}{suffix}" for name in EXPECTED_NAMES for suffix in (".png", ".txt")}


def _prepare_destination(destination: Path) -> None:
    if destination.exists() or destination.is_symlink():
        _validate_destination(destination)
        return
    destination.mkdir(parents=True)


def _validate_destination(destination: Path) -> None:
    if destination.is_symlink() or not destination.is_dir():
        raise AttachmentError(f"Destination must be a real directory: {destination}")
    if any(destination.iterdir()):
        raise AttachmentError(f"Destination must be empty: {destination}")


def _validated_record_names(record: dict[str, object]) -> tuple[str, str]:
    suggested = record.get("suggestedHumanReadableName")
    exported_name = record.get("exportedFileName")
    if not isinstance(suggested, str) or not isinstance(exported_name, str):
        raise AttachmentError("Attachment record is missing string names")
    if record.get("isAssociatedWithFailure") is not False:
        raise AttachmentError(f"Attachment is associated with a failed assertion: {suggested}")
    return suggested, exported_name


def _register_attachment(
    source: Path,
    names: tuple[str, str],
    expected_files: set[str],
    registry: tuple[dict[str, Path], set[str]],
) -> None:
    suggested, exported_name = names
    exported, manifest_exported_names = registry
    canonical_name = _canonical_attachment_name(suggested, expected_files)
    if canonical_name in exported:
        raise AttachmentError(f"Duplicate XCTest attachment: {canonical_name}")
    if exported_name in manifest_exported_names:
        raise AttachmentError(f"Duplicate exported attachment file: {exported_name}")
    path = _regular_file(source, exported_name)
    if path.suffix != Path(canonical_name).suffix:
        raise AttachmentError(
            f"Attachment type mismatch for {canonical_name}: exported as {exported_name}"
        )
    exported[canonical_name] = path
    manifest_exported_names.add(exported_name)


def _require_exact_manifest_entries(source: Path, manifest_exported_names: set[str]) -> None:
    actual_source_entries = {entry.name for entry in source.iterdir()}
    allowed_source_entries = manifest_exported_names | {"manifest.json"}
    unexpected_entries = sorted(actual_source_entries.difference(allowed_source_entries))
    if unexpected_entries:
        raise AttachmentError(
            f"Unmanifested xcresult export entries: {', '.join(unexpected_entries)}"
        )


def _read_attachment_content(exported: dict[str, Path]) -> tuple[dict[str, bytes], dict[str, str]]:
    images: dict[str, bytes] = {}
    notes: dict[str, str] = {}
    for name in EXPECTED_NAMES:
        images[name] = _read_image_attachment(exported[f"{name}.png"], name)
        notes[name] = _read_note_attachment(exported[f"{name}.txt"], name)
    return images, notes


def _read_image_attachment(path: Path, name: str) -> bytes:
    png_data = path.read_bytes()
    if len(png_data) <= 1_024 or not png_data.startswith(PNG_SIGNATURE):
        raise AttachmentError(f"Invalid or unexpectedly small PNG attachment: {name}.png")
    return png_data


def _read_note_attachment(path: Path, name: str) -> str:
    try:
        note = path.read_text(encoding="utf-8").strip()
    except (OSError, UnicodeError) as error:
        raise AttachmentError(f"Invalid UTF-8 note attachment: {name}.txt") from error
    if not note or "\x00" in note or len(note) > 500:
        raise AttachmentError(f"Invalid note attachment: {name}.txt")
    return " ".join(note.splitlines())


def _require_distinct_screenshots(images: dict[str, bytes]) -> None:
    for first, second in (
        ("05-learn-catalogue", "06-learn-method-detail"),
        ("07-info-scope", "08-info-pipeline"),
    ):
        if images[first] == images[second]:
            raise AttachmentError(
                f"Semantically different screenshots are identical: {first}, {second}"
            )


def _write_attachment_files(destination: Path, images: dict[str, bytes], notes: dict[str, str]) -> None:
    for name in EXPECTED_NAMES:
        (destination / f"{name}.png").write_bytes(images[name])
        (destination / f"{name}.txt").write_text(notes[name] + "\n", encoding="utf-8")


def _write_readme(destination: Path, notes: dict[str, str]) -> None:
    release_version = (REPOSITORY_ROOT / "RELEASE_VERSION").read_text(encoding="utf-8").strip()
    lines = [
        "# Videographr E2E screenshots (runtime)",
        "",
        "Captured by the assertion-backed `VideographrE2EScreenshots` XCUITest.",
        f"Release candidate: `v{release_version}` · App bundle: `0.1.0 (1)`",
        "",
        "| File | Asserted state |",
        "|------|----------------|",
    ]
    lines.extend(_readme_table_line(name, notes[name]) for name in EXPECTED_NAMES)
    lines.extend(("", "Regenerate with `scripts/run_e2e_screenshots.sh`.", ""))
    (destination / "README.md").write_text("\n".join(lines), encoding="utf-8")


def _readme_table_line(name: str, note: str) -> str:
    escaped_note = note.replace("|", "\\|")
    return f"| `{name}.png` | {escaped_note} |"


def stage_attachments(source: Path, destination: Path) -> None:
    source = source.resolve(strict=True)
    if not source.is_dir():
        raise AttachmentError(f"Attachment source is not a directory: {source}")
    _prepare_destination(destination)

    expected_files = _expected_attachment_files()
    exported: dict[str, Path] = {}
    manifest_exported_names: set[str] = set()
    registry = (exported, manifest_exported_names)
    for record in _attachment_records(source):
        names = _validated_record_names(record)
        _register_attachment(source, names, expected_files, registry)

    missing = sorted(expected_files.difference(exported))
    if missing:
        raise AttachmentError(f"Missing XCTest attachments: {', '.join(missing)}")

    _require_exact_manifest_entries(source, manifest_exported_names)
    images, notes = _read_attachment_content(exported)
    _require_distinct_screenshots(images)
    _write_attachment_files(destination, images, notes)
    _write_readme(destination, notes)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--destination", required=True, type=Path)
    arguments = parser.parse_args()
    try:
        stage_attachments(arguments.source, arguments.destination)
    except (AttachmentError, OSError) as error:
        parser.exit(1, f"E2E attachment validation failed: {error}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
