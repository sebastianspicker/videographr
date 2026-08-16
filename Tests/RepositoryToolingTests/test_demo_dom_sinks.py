#!/usr/bin/env python3
"""Source-level safeguards for the static Web demo."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DEMO_DIRECTORY = REPOSITORY_ROOT / "docs" / "demo"
FORBIDDEN_HTML_SINKS = (
    r"\.innerHTML\s*=",
    r"\.outerHTML\s*=",
    r"\.insertAdjacentHTML\s*\(",
    r"\bdocument\.write\s*\(",
)


class DemoDomSinksTests(unittest.TestCase):
    def test_demo_scripts_do_not_use_html_sinks(self) -> None:
        for demo_script in sorted(DEMO_DIRECTORY.glob("*.js")):
            source = demo_script.read_text(encoding="utf-8")
            for forbidden_sink in FORBIDDEN_HTML_SINKS:
                with self.subTest(script=demo_script.name, forbidden_sink=forbidden_sink):
                    self.assertIsNone(re.search(forbidden_sink, source))

    def test_demo_results_use_text_nodes_and_preserve_gating_copy(self) -> None:
        source = (DEMO_DIRECTORY / "demo.js").read_text(encoding="utf-8")
        for fragment in (
            "function renderNotice(container, headline, message)",
            "document.createElement('strong')",
            "document.createElement('p')",
            "title.textContent = headline",
            "detail.textContent = message",
            "container.replaceChildren(title, detail)",
            "gate.classList.toggle('warning', !(secondary && sharing))",
            "Demo-Modus: Aufnahme nicht verfügbar",
            "Es wurde nichts aufgezeichnet. Der Zustand bleibt „nicht aufnehmend“.",
            "Scopes vollständig",
            "Eine echte App könnte nun ein Metadatenpaket vorbereiten. Diese Demo erzeugt keine Datei.",
            "Export gesperrt",
            "Sekundärnutzung und externe Weitergabe fehlen.",
        ):
            with self.subTest(fragment=fragment):
                self.assertIn(fragment, source)


if __name__ == "__main__":
    unittest.main()
