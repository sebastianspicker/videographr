/* Synthetic fixture data for the static Pages demo. No value is read from a device or service. */
window.VIDEOGRAPHR_DEMO_DATA = Object.freeze({
  scopes: [
    { id: "collection", label: "Lokale Erhebung", detail: "Ein kontinuierlicher Take bleibt auf diesem Gerät.", enabled: true },
    { id: "reflection", label: "Lokale Reflexion", detail: "Notizen mit Zeitbezug zur Aufnahme.", enabled: false },
    { id: "secondary", label: "Sekundärnutzung", detail: "Voraussetzung für ein Studienpaket.", enabled: false },
    { id: "sharing", label: "Externe Weitergabe", detail: "Muss separat autorisiert werden.", enabled: false },
  ],
  reflection: {
    note: "Am synthetischen Tafelbild werden zwei lineare Funktionen gegenübergestellt. Die Klasse vergleicht Steigungen zunächst ohne Fachbegriffe.",
    markers: ["12:41", "27:03"],
  },
  catalogue: [
    {
      id: "method",
      label: "Methode",
      title: "Unterrichtsvideographie",
      summary: "Zweck, Planung und Evidenzgrenzen",
      paragraphs: [
        "Eine Aufnahme beginnt mit einem dokumentierten Zweck, einem vorher festgelegten Beobachtungsrahmen und einer gültigen, zweckgebundenen Einwilligung.",
        "Technische Hinweise helfen bei der Aufnahme. Sie bewerten weder Unterricht noch Lernen und ersetzen keine menschliche Auswertung.",
      ],
    },
    {
      id: "technique",
      label: "Aufnahmetechnik",
      title: "Position, Ton und kontinuierlicher Take",
      summary: "Direkte Aufnahmebedingungen sichtbar machen",
      paragraphs: [
        "Die Aufnahmeposition folgt der Beobachtungsfrage. Vor dem Start werden Bildausschnitt, Kameraruhe und die Verständlichkeit des Tons unmittelbar geprüft.",
        "Ein kontinuierlicher Take macht den Verlauf nachvollziehbar. Die technische Prüfung trifft keine Aussage über pädagogische Qualität.",
      ],
    },
    {
      id: "devices",
      label: "Externe Geräte",
      title: "Stativ, Mikrofon und lokale Ablage",
      summary: "Zubehör kann die Aufnahme unterstützen",
      paragraphs: [
        "Stativ und externes Mikrofon sind optionale Hilfsmittel. Ihre konkrete Eignung hängt vom geplanten Ablauf und den örtlichen Rahmenbedingungen ab.",
        "Videographr legt Sitzungsdaten lokal ab. Die Demo nutzt kein Zubehör und hat keinen Zugriff auf Hardware, Dateien oder Speicher.",
      ],
    },
  ],
});
