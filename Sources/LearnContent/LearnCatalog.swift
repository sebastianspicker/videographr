import Foundation

/// Educational content for Videographr - method, technology, external devices.
/// Domain: Unterrichtsvideographie. Background sources are catalogued in
/// docs/references/unterrichtsvideographie.md.
public struct LearnTopic: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var sections: [LearnSection]

    public init(id: String, title: String, subtitle: String, sections: [LearnSection]) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.sections = sections
    }
}

public struct LearnSection: Identifiable, Equatable, Sendable {
    public var id: String
    public var heading: String
    public var body: String
    public var researchNote: String?

    public init(id: String, heading: String, body: String, researchNote: String? = nil) {
        self.id = id
        self.heading = heading
        self.body = body
        self.researchNote = researchNote
    }
}

public enum LearnCatalog {
    /// All top-level educational topics shown in the Learn tab.
    public static var allTopics: [LearnTopic] {
        [method, technology, externalDevices, captureChecklist, pedagogicalCoding]
    }

    public static var topicIDs: [String] {
        allTopics.map(\.id)
    }

    public static func topic(id: String) -> LearnTopic? {
        allTopics.first { $0.id == id }
    }

    // MARK: - Method

    public static let method = LearnTopic(
        id: "method",
        title: "Methode: Unterrichtsvideographie",
        subtitle: "Was, warum und wie in der Lehrkräftebildung",
        sections: [
            LearnSection(
                id: "m-def",
                heading: "Begriffsklärung",
                body: """
                Unterrichtsvideographie meint die systematische audiovisuelle Aufzeichnung von Lehr-Lern-Situationen - oft mit mehreren Mikrofonen, Kontextmaterial (Transkript, Tafelbild, Arbeitsblätter) und einer didaktisch begründeten Kameraposition.

                Davon zu unterscheiden ist die qualitative \u{201E}Videographie\u{201C} im Sinne der dokumentarischen Methode (z. B. Bohnsack): dort steht die rekonstruktive Interpretation sozialer Praktiken im Vordergrund, nicht primär das Training professioneller Wahrnehmung.
                """,
                researchNote: "Siehe Referenz: Orientierungsterminologie; Krammer & Reusser 2005; Asbrand & Martens 2018."
            ),
            LearnSection(
                id: "m-why",
                heading: "Warum Video in der Lehrkräftebildung?",
                body: """
                Videos machen die Komplexität von Unterricht wiederholbar und multiperspektivisch beobachtbar - ohne unmittelbaren Handlungsdruck. Sie unterstützen fallbasiertes Lernen, Theorie-Praxis-Verknüpfung und den Aufbau professioneller Wahrnehmung (Noticing: selektive Aufmerksamkeit + wissensbasierte Interpretation).

                Video ist jedoch kein Selbstläufer: Wirkung hängt von Zielen, Aufgaben, Begleitung und Auswertung ab (Brophy; Blomberg et al. 2013).
                """,
                researchNote: "Krammer & Reusser 2005; Sherin & van Es; Seidel & Stürmer 2014; Blomberg-Heuristiken."
            ),
            LearnSection(
                id: "m-design",
                heading: "Gestaltung guter Aufnahmen für Analyse",
                body: """
                Für die spätere Analyse (eigenes oder fremdes Video) zählen:
                • Stabiler Standpunkt (Stativ) und gerade Horizontebene
                • Tafel/Board und Interaktionsraum im Bild
                • Wenig \u{201E}leere\u{201C} Decke, kein starkes Gegenlicht
                • Für die spätere menschliche Anhörung ausreichend verständlicher Ton (Lehrperson und möglichst Beiträge von SuS)
                • Kontext: Stunde, Fach, Ziel, Einwilligungen

                Typische Settings: festes Stativ seitlich-frontal; optional zweite Kamera auf SuS-Gruppen; externes Mikrofon an der Lehrperson.
                """,
                researchNote: "Derry 2007 beschreibt zweckgeleitete, kontinuierliche Videoerhebung und die Bedeutung von Audio; diese Hinweise validieren keine automatische Unterrichtsbewertung durch die App."
            ),
            LearnSection(
                id: "m-own-other",
                heading: "Eigenes vs. fremdes Video",
                body: """
                Eigenes Video: höhere Authentizität und Motivation, aber emotionale Nähe erschwert Kritik.
                Fremdes Video: mehr kritische Distanz und Theoriebezug - gut zum Einstieg und zum Einüben von Diskursnormen.

                Viele Ausbildungen kombinieren beides: zuerst fremde Clips, später eigene Sequenzen (Seidel et al. 2011; Krammer 2014).
                """,
                researchNote: "Seidel et al. 2011; Krammer 2014."
            )
        ]
    )

    // MARK: - Technology

    public static let technology = LearnTopic(
        id: "technology",
        title: "Technik der Aufnahme",
        subtitle: "Kamera, Bild, Licht, Stabilität",
        sections: [
            LearnSection(
                id: "t-camera",
                heading: "Kamera & Bildausschnitt",
                body: """
                iPad/iPhone können sich für mobile Unterrichtsvideographie eignen. Eignung und verfügbare Speicherdauer hängen vom konkreten Gerät, der gewählten Auflösung und dem freien Speicher ab.

                Empfehlungen:
                • Querformat (Landscape) für Klassenzimmer
                • Auflösung und Bildrate vorab am Studienprotokoll prüfen; 4K benötigt mehr Speicher als 1080p
                • Stativ oder festen Standort - Handkamera erzeugt schwer auswertbare Bewegungen
                • Fokus auf Lehr-Lern-Geschehen, nicht auf \u{201E}Filmlook\u{201C}

                Diese App gibt Echtzeit-Hinweise zu Neigung (Gyroskop), Deckenanteil, Tafelposition und Gegenlicht.
                """
            ),
            LearnSection(
                id: "t-light",
                heading: "Licht & Gegenlicht",
                body: """
                Gegenlicht entsteht, wenn helle Fenster hinter dem Unterrichtsgeschehen liegen: Gesichter und Tafel werden dunkel, der Himmel/Fensterbereich brennt aus.

                Typische Gegenmaßnahmen:
                • Standort so wählen, dass Fenster seitlich oder im Rücken der Kamera liegen
                • Vorhänge teilweise schließen
                • Belichtung manuell auf die Tafel / die Lehrperson legen
                • Zusätzliches Raumlicht bei Bedarf

                Die App schätzt Gegenlicht über Helligkeitskontraste (helle Ränder vs. dunkleres Zentrum).
                """
            ),
            LearnSection(
                id: "t-frame",
                heading: "Was gehört ins Bild?",
                body: """
                Für die meisten Analyseziele:
                • Tafel/Board und Lehrperson
                • Teile der Lerngruppe (nicht nur Rückenreihen)
                • Wenig Decke, wenig leerer Rand
                • Gerade Bildkanten (kein \u{201E}schiefer\u{201C} Raum)

                Zwei-Kamera-Settings (Derry u. a.): oft eine weite Übersicht + optional eine nähere Perspektive. Audio hat Vorrang vor \u{201E}schönen\u{201C} Schwenks.
                """,
                researchNote: "Derry 2007: continuous recording, audio priority, multi-camera."
            ),
            LearnSection(
                id: "t-ethics",
                heading: "Einwilligung & Datenschutz (Kurz)",
                body: """
                Vor der Aufnahme: informierte Einwilligung von Lehrpersonen und - je nach Alter und Institution - Erziehungsberechtigten / SuS. Klären, wofür das Video genutzt wird (nur Seminar? Forschung? Portal?).

                Die App fordert iOS-Geräteauthentifizierung an und konfiguriert iOS-Dateischutz für lokale Daten. Das Verhalten im gesperrten Gerätezustand ist für diese Alpha noch nicht auf physischen Geräten verifiziert. Diese App ersetzt keine institutionelle DSGVO-Prüfung.
                """,
                researchNote: "Derry Guidelines; DE Manuals / QLB-Portale."
            )
        ]
    )

    // MARK: - External devices

    public static let externalDevices = LearnTopic(
        id: "devices",
        title: "Externe Geräte",
        subtitle: "Mikrofone und Anreicherungen der Videographie",
        sections: [
            LearnSection(
                id: "d-why-mic",
                heading: "Warum externes Audio?",
                body: """
                Das interne Gerätemikrofon kann Raumhall, Lüftung und weiter entfernte Beiträge ungleichmäßig erfassen. Für menschliche Videoanalyse oder Transkription ist ein vorab abgehörter Ton wichtig - besonders bei Beiträgen von SuS.

                Ein externes Mikrofon kann die Aufnahme der Lehrperson verbessern, muss aber im jeweiligen Raum mit einer kurzen Testaufnahme geprüft werden. Pegelwerte allein belegen keine inhaltliche Verständlichkeit.
                """
            ),
            LearnSection(
                id: "d-mic-types",
                heading: "Mikrofon-Typen im Klassenzimmer",
                body: """
                • Ansteckmikrofon (Lavalier) an der Lehrperson: kann die Lehrperson näher aufnehmen; vor Ort abhören
                • Richtmikrofon (Shotgun) am Stativ / über dem Gerät: gut für frontal-sprachliche Phasen
                • Grenzflächenmikrofon auf dem Lehrertisch: diskret, Raummitte
                • Zweites Aufnahmegerät (Audio-Recorder) als Backup, später im Schnitt synchronisieren
                • Funkstrecke (TX an Lehrperson, RX am iPad): Bewegungsfreiheit

                Tipp: Pegelprobe vor Stundenbeginn; Wind/Pop-Schutz bei lavaliers nahe dem Mund.
                """
            ),
            LearnSection(
                id: "d-multi",
                heading: "Weitere Anreicherungen",
                body: """
                • Zweites Gerät (iPhone) für Seitenperspektive oder SuS-Gruppentische
                • Dokumentenkamera / Smartboard-Export für Tafelbilder parallel zum Video
                • Timecode-Notizen (Tablet) für relevante Ereignisse während der Stunde
                • Transkript & Materialien im Anschluss (erleichtert Analyse und Seminararbeit)

                Forschung und Portale (z. B. ViU, ProVision, unterrichtsvideos.ch) kombinieren oft Video + Begleitmaterial - plane das schon bei der Aufnahme mit.
                """,
                researchNote: "Krammer/Reusser; Portal-Infrastruktur QLB; Derry selection & sharing."
            ),
            LearnSection(
                id: "d-connect",
                heading: "Anschluss am iPad/iPhone",
                body: """
                • USB-C / Lightning Audio-Interfaces und digitale Lavaliers
                • Bluetooth-Mikrofone: praktisch, aber Latenz und Stabilität prüfen
                • Adapter nur mit Stromversorgung bei längeren Aufnahmen
                • In den Systemeinstellungen Mikrofonzugriff für diese App erlauben

                Vor dem Unterricht: 30-Sekunden-Testaufnahme mit Sprechen aus verschiedenen Raumpositionen abhören.
                """
            )
        ]
    )

    // MARK: - Human-observation frameworks (IPN / TIMSS / GTI)

    public static let pedagogicalCoding = LearnTopic(
        id: "coding",
        title: "Kodierrahmen: IPN, TIMSS, GTI",
        subtitle: "Konzeptioneller Hintergrund für menschliche Beobachtung - Grenzen der App",
        sections: [
            LearnSection(
                id: "c-overview",
                heading: "Was diese Kodierrahmen bedeuten - und was die App nicht ableitet",
                body: """
                IPN, TIMSS und OECD Global Teaching InSights (GTI/TALIS Video) sind Kodier- und Beobachtungsrahmen für geschulte menschliche Beobachtung mit definierten Instrumenten, Codebüchern und Qualitätssicherung. Sie können helfen, Fragen für Reflexion oder eine spätere, dokumentierte menschliche Auswertung zu formulieren.

                Im evidenzsicheren Modus leitet Videographr daraus keine pädagogischen Codes, Qualitätsurteile, Konfidenzen oder Vergleichswerte ab. Die App zeigt dort nur direkte technische Beobachtungen wie Bildstabilität, sichtbare Bereiche, Licht- und Audiosignale.

                Ein experimenteller Forschungsmodus kann separat als **nicht validierte Hypothese** gekennzeichnete Regelhinweise speichern. Diese sind weder Human-Codes noch Ersatz für Codebook-Schulung oder Rater-Reliabilität.
                """,
                researchNote: "IPN-, TIMSS- und OECD-GTI-Quellen beschreiben menschliche Beobachtungsinstrumente. Sie sind konzeptioneller Kontext und keine Validierung von Videographr-Ausgaben."
            ),
            LearnSection(
                id: "c-presets",
                heading: "Unterrichtssituationen (Presets) steuern Erwartungen",
                body: """
                Die Presets (z. B. frontal, Dialog, Gruppe oder Experiment) dokumentieren den beabsichtigten Aufnahmekontext und passen die praktischen Hinweise an:

                • welche Bereiche für den gewählten Zweck sichtbar sein sollten
                • welche Fragen die spätere menschliche Reflexion leiten können
                • welche technischen Capture-Hinweise angezeigt werden

                Ein Preset ist keine Messung von Unterrichtsqualität. Dieselben Bildsignale werden im evidenzsicheren Modus unabhängig vom Preset gleich als technische Beobachtung ausgewiesen.
                """
            ),
            LearnSection(
                id: "c-gti",
                heading: "GTI / TALIS Video als konzeptioneller Kontext",
                body: """
                OECD Global Teaching InSights (TALIS Video Study) nutzt Beobachtungsrubriken für geschulte menschliche Ratings, unter anderem zu:

                • Classroom management - Organisation, Überblick, Stabilität
                • Social-emotional support - Klima, Partizipationsstruktur
                • Instruction - Klarheit, Aktivierung, Diskurs, Feedback

                Diese Domänen erklären, warum Videoaufnahmen Kontext und sorgfältige menschliche Analyse brauchen. Videographr misst oder bewertet diese Domänen nicht automatisch und macht keine Aussagen zur Vergleichbarkeit mit OECD-Erhebungen.
                """,
                researchNote: "OECD Global Teaching InSights ist eine Quelle für menschliche Beobachtungsrubriken; die Studie validiert keine automatische Zuordnung der App zu diesen Konstrukten."
            ),
            LearnSection(
                id: "c-export",
                heading: "Studienpaket und Grenzen",
                body: """
                Ein autorisiertes Studienpaket kann Sitzungsmetadaten, direkte technische Beobachtungen, zeitlich referenzierte Anmerkungen und Versionsangaben enthalten. Welche Daten geteilt werden dürfen, richtet sich nach der zweckgebundenen Einwilligung.

                Experimentelle Hypothesen werden getrennt und sichtbar als nicht validiert gekennzeichnet. Für menschliche Kodierungen müssen Codebuch, Rater-Schulung, Blindung und Reliabilität im jeweiligen Forschungsprotokoll dokumentiert werden.
                """
            )
        ]
    )

    // MARK: - Checklist (linked to live guidance)

    public static let captureChecklist = LearnTopic(
        id: "checklist",
        title: "Setup-Check vor der Stunde",
        subtitle: "Mit den Live-Hinweisen abstimmen",
        sections: [
            LearnSection(
                id: "c-before",
                heading: "Vor dem Läuten",
                body: """
                1. Einwilligungen geklärt, Speichermedium frei
                2. Stativ positioniert (seitlich-frontal, nicht im Fluchtweg)
                3. Live-Tab: Neigung/Roll ok, wenig Decke, Tafel sichtbar, kein kritisches Gegenlicht
                4. Externes Mikrofon pegelecht, Funk geladen
                5. Testclip 20 s - Bild und Ton prüfen
                6. Geräte im Flugmodus / Nicht stören (außer benötigtes Funk-Audio)
                """
            ),
            LearnSection(
                id: "c-live",
                heading: "Was die Live-Hinweise prüfen",
                body: """
                • Gyroskop/Lage: Pitch & Roll → schiefer Horizont, zu viel Decke/Boden
                • Live-Bild & Frame: Helligkeitskarten, leere Ränder
                • Tafelregion: dunklere/kontrastierende Schreibfläche in der Bildmitte
                • Deckenanteil: helles oberes Band
                • Gegenlicht: helle Fensterkanten vs. dunkles Zentrum
                • Struktur-CV: multi-cue Tafel, Akteure, Co-Präsenz, Layout (Reihen/Cluster/Kreis/…)
                • Verfügbarkeit technischer Signale und fehlende Messwerte

                Die Hinweise sind technische Heuristiken. Sie bewerten weder Unterrichtsqualität noch Diskurs, Feedback, Lernfortschritt oder die inhaltliche Verständlichkeit gesprochener Beiträge.
                """
            )
        ]
    )
}
