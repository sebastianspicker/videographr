#!/usr/bin/env python3
"""Deterministic tests for the xcresult attachment evidence boundary."""

from __future__ import annotations

import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY_ROOT / "scripts"))

from extract_e2e_attachments import AttachmentError, EXPECTED_NAMES, PNG_SIGNATURE, stage_attachments


E2E_SCREENSHOT_TEST = REPOSITORY_ROOT / "App/VideographrUITests/VideographrE2EScreenshots.swift"
RELEASE_VERSION = (REPOSITORY_ROOT / "RELEASE_VERSION").read_text(encoding="utf-8").strip()


def swift_capture_names(source: str) -> tuple[str, ...]:
    """Return literal attachment stems emitted by the assertion-backed screenshot tour."""
    return tuple(re.findall(r'try capture\(\s*"([^"]+)"', source))


class ExtractE2EAttachmentsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.root = Path(self.temporary_directory.name)
        self.source = self.root / "source"
        self.destination = self.root / "destination"
        self.source.mkdir()
        self.records: list[dict[str, object]] = []

        for index, name in enumerate(EXPECTED_NAMES):
            exported_png = f"export-{index}.png"
            exported_note = f"export-{index}.txt"
            (self.source / exported_png).write_bytes(
                PNG_SIGNATURE + bytes([index + 1]) * 1_100
            )
            (self.source / exported_note).write_text(f"Proof for {name}\n", encoding="utf-8")
            self.records.extend(
                (
                    self.record(f"{name}.png", exported_png),
                    self.record(f"{name}.txt", exported_note),
                )
            )

    @staticmethod
    def record(suggested: str, exported: str) -> dict[str, object]:
        return {
            "suggestedHumanReadableName": suggested,
            "exportedFileName": exported,
            "isAssociatedWithFailure": False,
        }

    def write_manifest(self) -> None:
        payload = [{"testIdentifier": "VideographrE2E", "attachments": self.records}]
        (self.source / "manifest.json").write_text(json.dumps(payload), encoding="utf-8")

    def assert_staged_attachment_files(self) -> None:
        self.write_manifest()
        stage_attachments(self.source, self.destination)
        self.assertEqual(len(list(self.destination.glob("*.png"))), len(EXPECTED_NAMES))
        self.assertEqual(len(list(self.destination.glob("*.txt"))), len(EXPECTED_NAMES))

    def test_stages_only_the_exact_verified_set(self) -> None:
        self.assert_staged_attachment_files()
        readme = (self.destination / "README.md").read_text(encoding="utf-8")
        self.assertIn("assertion-backed", readme)
        self.assertIn("08-info-pipeline.png", readme)
        self.assertIn(f"v{RELEASE_VERSION}", readme)
        self.assertIn("Regenerate with `scripts/run_e2e_screenshots.sh`.", readme)

    def test_accepts_xcode_decorated_human_readable_names(self) -> None:
        identifiers = (
            "8230DCC0-A9DE-4538-AEE3-B9B40D9743A9",
            "F8A47E36-8ADF-4142-B619-2C95111A3D89",
        )
        for index, record in enumerate(self.records):
            suggested = Path(str(record["suggestedHumanReadableName"]))
            record["suggestedHumanReadableName"] = (
                f"{suggested.stem}_0_{identifiers[index % len(identifiers)]}{suggested.suffix}"
            )
        self.assert_staged_attachment_files()

    def test_rejects_a_lookalike_decorated_name(self) -> None:
        self.records[0]["suggestedHumanReadableName"] = (
            "01-setup-scoped-consent_0_not-a-uuid.png"
        )
        self.write_manifest()

        with self.assertRaisesRegex(AttachmentError, "Unexpected XCTest attachment"):
            stage_attachments(self.source, self.destination)

    def test_rejects_a_noncanonical_uuid_decoration(self) -> None:
        self.records[0]["suggestedHumanReadableName"] = (
            "01-setup-scoped-consent_0_8230DCC0A9DE4538AEE3B9B40D9743A9.png"
        )
        self.write_manifest()

        with self.assertRaisesRegex(AttachmentError, "Unexpected XCTest attachment"):
            stage_attachments(self.source, self.destination)

    def test_python_contract_matches_swift_emitted_attachment_names(self) -> None:
        swift_source = E2E_SCREENSHOT_TEST.read_text(encoding="utf-8")
        emitted_names = swift_capture_names(swift_source)

        self.assertEqual(set(emitted_names), set(EXPECTED_NAMES))
        self.assertEqual(len(emitted_names), len(EXPECTED_NAMES))
        self.assertEqual(len(set(emitted_names)), len(EXPECTED_NAMES))

    def test_rejects_a_duplicate_attachment(self) -> None:
        self.records.append(self.records[0].copy())
        self.write_manifest()

        with self.assertRaisesRegex(AttachmentError, "Duplicate XCTest attachment"):
            stage_attachments(self.source, self.destination)

    def test_rejects_an_unmanifested_export(self) -> None:
        (self.source / "surprise.png").write_bytes(PNG_SIGNATURE + b"x" * 1_100)
        self.write_manifest()

        with self.assertRaisesRegex(AttachmentError, "Unmanifested xcresult export entries"):
            stage_attachments(self.source, self.destination)


if __name__ == "__main__":
    unittest.main()
