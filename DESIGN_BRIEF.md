# Videographr design brief

Status: working brief for the 2026 interface redesign of the native SwiftUI app
(`App/Unterrichtsvideographie`). The static Pages demo (`docs/demo/`) and the
untracked `design-preview/` are out of scope for this pass; see "Next steps".

## 1. Product

Videographr is a local-first iPhone and iPad app for classroom video research.
One session lives on one device. The operator sets the purpose, lesson context,
retention policy, operating mode and scoped consent; checks direct capture
conditions (frame, level, exposure, motion, audio level, a spoken audio check);
records one continuous take or imports a local MP4; writes time-linked,
human-authored reflection notes against four Lesson Analysis Framework prompts;
and exports a metadata-only `.videographrstudy` package that never contains the
video.

The product's defining stance is epistemic restraint. Evidence-safe mode reports
what the camera and microphone directly show and nothing more. Experimental rule
hypotheses exist, but they are protocol-gated, labelled "nicht validiert", and
can never decide readiness, consent or export. Every screen repeats some version
of "this is a measurement, not a judgement of teaching".

**Moment of value.** Two moments, in order of weight:

1. *Aufnahme läuft*: the take starts with consent documented and conditions
   checked, and the operator can stop watching the iPad and watch the lesson.
2. *Notiz mit Zeitmarke gesichert*: a human observation is pinned to a time
   range of the video and saved locally, building the protocol that the
   researcher will later code or discuss.

## 2. Audience

**Primary: the operator-researcher.** An educational researcher, teacher educator
(Lehrkräftebildung, Seminarleitung, university didactics) or a doctoral student
running a video study. German-speaking, academically trained, fluent in research
ethics vocabulary (Einwilligung, Pseudonym, Sekundärnutzung, Ethikvotum),
familiar with coding manuals, transcripts, observation protocols (IPN, TIMSS
Video, GTI) and tools such as MAXQDA, ATLAS.ti, Excel, Zotero, the iPad camera.

- Goals: a clean, continuous, usable take; documented consent that will
  survive an ethics or data-protection review; notes that are traceable to a
  moment in the video; an export that a colleague can check.
- Anxieties: filming a child without valid consent; losing a 45-minute take;
  a tool that quietly "scores" a teacher; data leaving the device; being seen to
  overclaim in a publication.
- **What they distrust:** AI-flavoured interfaces, confident numbers without a
  source, cloud language, playful edtech gloss, anything that looks like
  surveillance or a teacher-rating dashboard.
- **What signals quality to them:** precise wording, visible provenance, explicit
  missing values, typographic seriousness familiar from journals, protocols and
  well-made forms; calm; nothing hidden.

Secondary: the teacher being filmed or reviewing their own lesson
(purpose "Eigener Unterricht"), and methods evaluators reading exports and
screenshots. Both read the same screens; neither operates the capture.

**Conditions of use.** Preparation happens at a desk or in a staff room. Capture
happens at the back or side of a live classroom, iPad on a tripod, often with
children in the room: the screen must be discreet, glanceable from a metre away,
and must not glow. Reflection happens later, seated, for long stretches of
reading and writing.

## 3. Key journeys

1. Prepare (tab Sitzung): title, purpose, subject, grade, lesson goal,
   planned duration → documented consent (document, version, group pseudonym,
   scopes) → optional mode and research protocol → *Speichern und Aufnahme
   prüfen*.
2. Capture (tab Aufnahme): dominant preview → direct signals (Bild, Lage,
   Belichtung, Ton) → spoken audio check → start → continuous take with elapsed
   time → stop → finalised local file.
3. Reflect (tab Notizen): choose a take or import an MP4 → play, set a
   time range → choose one of four prompts → write a human note with author
   pseudonym → *Notiz sichern* → repeat until each prompt has a note and a link.
4. Export (Notizen → *Metadaten prüfen*): see contents, required scopes and
   the video exclusion → *Paket erstellen und weitergeben* → system share sheet
   → recorded outcome.
5. Consult (tabs Referenz, Info): German reference catalogue on method,
   technique, devices, checklists; product boundary and evidence state.

## 4. Brand traits

| Trait | Not tipping into |
| --- | --- |
| Rigorous: every value has a source and a status | Bureaucratic, defensive, legalistic |
| Restrained: says what it measures and stops | Timid, apologetic, empty |
| Scholarly: reads like a well-set protocol or paper | Antiquarian, ornamental, nostalgic |
| Discreet: at home in a classroom, never on show | Invisible, unbranded, generic |
| Humane: the human note is the point; the machine only assists | Soft, cute, edtech-cheerful |

## 5. Market observations

- **Classroom video platforms** (Swivl, IRIS Connect, Edthena, GoReact, Vosaic):
  bright SaaS palettes (teal, sky blue, orange), rounded cards, stock photos of
  smiling teachers, coaching and "growth" language, cloud-first. Users depend on
  their timeline-with-comments pattern; the visual language is interchangeable
  and actively wrong for a no-cloud, no-scoring research tool.
- **Pro camera apps** (Blackmagic Camera, Filmic, Kinemaster-type tools): black
  UI, yellow or orange accents, dense mono readouts, slate metaphors. Users
  depend on the dominant preview, legible timecode and a big unmistakable record
  control. Their density and gear aesthetic would make the app feel like a
  production tool and intimidate teacher educators.
- **Qualitative analysis software** (MAXQDA, ATLAS.ti, Transana, ELAN): dense,
  grey, desktop-era panels, but one deeply familiar artifact, the transcript or
  segment list with timecodes in a margin column. Researchers read that column
  instinctively.

Honour: dominant preview and distinct record control; timecode in a margin;
explicit labels for every status; native iOS controls and navigation.
Break: SaaS cheerfulness, gear-styled darkness everywhere, card-grid
dashboards, generic system-blue.

## 6. What to keep

- The name videographr in lowercase as a typographic wordmark (no logo asset
  exists; the lowercase wordmark is the established identity).
- The five destinations, their order and their accessibility identifiers.
- Dark capture surface: functional, because a bright screen at the back of a
  classroom distracts and the preview must dominate.
- Tabular, monospaced time; text-plus-symbol status; German copy; Dynamic Type
  and reduced-motion behaviour; the 44 pt minimum target.
- The careful, honest wording about consent, validity and exports. Rewrite for
  clarity and rhythm, never to soften a claim.

## 7. Current weaknesses

- One flat graphite surface for everything. Preparation forms, long reference
  articles and the camera all look the same, so nothing signals document versus
  instrument, and long German text reads poorly light-on-dark.
- System font and system controls without decisions: headings are `.title2`
  medium, sections `.headline`; hierarchy is weak (on Setup the screen title, the
  section title and field labels are nearly the same weight).
- Boxed inputs everywhere (`scientificInput` draws a 1 pt box on every field),
  which turns forms into grids of rectangles.
- Accent blue does three jobs: action, measured signal and "consent ok".
  Provenance, who produced a value, has no visual expression, although the
  whole product is about that distinction.
- The session header duplicates the tab bar ("Sitzung" menu + tab), and the
  Live toolbar repeats the wordmark at every visit.
- Live on phone: the record control sits below the fold on small phones; the
  signal strip is centred and loose; the console has no rhythm.
- Reflect: four similar disclosure groups, two nearly identical save actions
  ("Notiz sichern", "Entwurf speichern"), prompt picker as a blue menu text.
- Legacy naming (`FieldInstrument…`, `day`/`night` roles that are identical).

## 8. Constraints

- Preserve all behaviour, bindings, `AppStore` intent calls, gating logic,
  accessibility identifiers and the five-tab structure; views stay SwiftUI-only
  and persist only through `AppStore`.
- New app Swift files must be added to `project.pbxproj` (enforced by
  `scripts/verify_architecture.py`).
- iOS 17 minimum: no iOS 18-only APIs without availability checks.
- Strict concurrency, warnings as errors in the package; app target must build
  cleanly.
- German UI text; WCAG 2.2 AA contrast; Dynamic Type up to accessibility sizes;
  text or symbol in addition to colour; reduced motion respected.
- Only open-licensed fonts; licence text must ship with the font.
- No invented claims, statistics or testimonials; screenshots use synthetic
  fixtures only.

## 9. Assumptions log

| # | Assumption | Evidence | Confidence |
| --- | --- | --- | --- |
| A1 | Primary user is a German-speaking researcher or teacher educator, not a classroom teacher filming alone. | PRODUCT.md "Intended users"; vocabulary (Protokoll, Aufsicht, Sekundärnutzung); LAF prompts; export package. | High |
| A2 | Capture happens with the device on a tripod in a live classroom, glanced at rather than held. | Learn catalogue capture checklist; "kontinuierlicher Take"; motion/level guidance; planned 20–45 min durations. | High |
| A3 | Preparation and reflection happen in normally lit rooms and involve long reading and writing. | Long consent and reference texts; four free-text prompts; Learn articles. | Medium |
| A4 | Users want the app to follow the system light/dark setting outside capture; the old forced-dark choice was aesthetic, not a requirement. | No code path depends on dark mode; PRODUCT.md mentions "graphite surfaces" as a style, not a reason. | Medium |
| A5 | A serif reading face is welcome to this audience and not perceived as old-fashioned. | Academic publishing norms; German protocol and journal conventions; long-form German text. | Medium |
| A6 | Royal-blue ink ("Königsblau") reads as "handwritten by a person" for German users. | Königsblau is the standard school and fountain-pen ink colour in Germany; teacher educators grew up correcting in it. | Medium |
| A7 | No brand assets beyond the lowercase wordmark and a blue accent need preserving. | Asset catalogue holds only AppIcon, AccentColor and LaunchBackground; no logo files. | High |
| A8 | Bundling ~1 MB of fonts is acceptable for a source-only alpha. | Optional Gaussian model is far larger; no app-size constraint documented. | High |
| A9 | Accessibility identifiers are relied upon by external UI automation even though no UI-test target exists. | Systematic identifiers on every control; README mentions a removed UI-test target. | Low: kept anyway, costs nothing |
| A10 | The snapshot test renders are the canonical review screenshots and may be regenerated. | README screenshot tour; `ScientificVideoSnapshotTests` attachments. | High |

## 10. Design direction

### Method

The domain offers three strong artifacts: the **observation protocol** (a ruled
sheet with numbered sections and a margin for times and codes), the **film
slate** (take, scene, date on a clapperboard), and the **measuring instrument**
(calibrated readouts). The emotional states differ by phase: careful and
slightly anxious while preparing consent, alert and hands-off while filming,
slow and reflective while writing.

### Direction A, "Protokoll in drei Tinten"

- Concept. The app is a living observation protocol. Documents (preparation,
  notes, export, reference) are set on paper with a ruled grid and a **margin
  column** that carries reference marks: section numbers while preparing,
  timecodes while reflecting, status marks while exporting. Colour is
  provenance: three inks say who wrote a mark. Königsblau for what a person
  wrote or decides (actions, human notes, consent the operator documented),
  graphite for what the instrument measured, **ochre with hatching** for
  experimental, unvalidated hypotheses. A fourth colour, **signal red**, exists
  only for a running take. The capture screen is the one dark room, where the
  paper gives way to the image.
- **Why it fits.** It makes the product's central idea, the separation of
  measurement, hypothesis and human judgement, visible on every screen. It uses
  artifacts researchers already read fluently (protocol margins, transcripts
  with timecodes) and the ink their profession grew up with.
- Typography. Source Serif 4 (OFL) carries the document voice: Display
  Semibold for screen titles, Subhead Semibold for sections, Small Text Regular
  and Italic for human writing and long reference text. SF Pro stays for
  controls, inputs and dense UI, because native controls and Dynamic Type depend
  on it, but every label is set as tracked small caps, never as default body.
  SF Mono for every machine value: timecode, measurements, file names, hashes.
  Rule: *serif = a person or a document, mono = the instrument, sans = the
  interface.*
- Colour. Paper `#F5F3EE`, sheet `#FBFAF7`, ink `#1A1C1E`, secondary ink
  `#4E5257`, rules `#D9D5CC`; Königsblau `#1F3FAA`; graphite measurement
  `#3A3F45`; ochre `#8A5A00` with hatching; signal red `#C8102E`; a muted green
  `#2F6B45` used only for "documented / secured" confirmations. Dark mode:
  warm night paper `#16171A`, light inks, Königsblau lifted to `#9DB0FF`.
  Capture room: `#0E0F11` with light graphite readouts.
- Layout. Form fields sit on ruled lines, not in boxes. iPad: 12-column grid,
  a fixed 88 pt margin column + content column(s); phone: the margin folds to a
  56 pt column for marks, content gets the rest. Generous vertical rhythm on a
  4 pt base (rows 52 pt). Section heads: margin number + serif heading + a full
  rule.
- Motion. Almost none. The recording tally fades in (opacity, 180 ms); a
  saved note's mark ticks from pending to saved (opacity). No movement while a
  take runs except the time counter. All disabled under reduced motion.
- **Signature details.** (1) The margin column of marks, § numbers, timecodes,
  status glyphs, that runs through every document. (2) The hatched ochre rule
  that marks any experimental content, so "nicht validiert" is visible before it
  is read.
- **Against category.** No SaaS cards, no gear darkness, no system-blue; reads as
  research document rather than product.
- Refuses. Cards with shadows, rounded pill buttons, gradients, icons in
  circles, dashboards, scores, percentages without units, any ornament that
  imitates paper texture (no grain, no torn edges, "paper" is only colour,
  rules and type).

### Direction B, "Klappe" (slate)

- Concept. Every session is a slate: production (study), scene (lesson),
  take, date. The interface is high-contrast black and white with the slate's
  diagonal stripe as the recording signature and huge condensed numerals for the
  take counter and timecode.
- Typography. A condensed DIN-like grotesk (D-DIN, OFL) for numerals and
  labels; SF Pro for text.
- Colour. Pure black, white, one chalk grey; red only for record.
- Layout. Big blocks, heavy rules, fields as slate cells.
- Motion. A "clap" when a take starts (a 120 ms bar closing).
- Signature. The slate header that stays on top of every screen.
- **Against category.** Owns the camera-app look rather than the edtech look.
- Refuses. Colour, softness, serif.
- Problem. It frames classroom research as film production, which the
  product explicitly is not (one continuous take, no editing). Its loudness is
  wrong in a room full of children, and it gives nothing to the reflection
  journey, which is about writing.

### Direction C, "Messplatz" (instrument bench)

- Concept. Evolve the current graphite into a precise lab instrument:
  everything dark, calibrated scales, mono readouts, hairline grids, a single
  phosphor-like accent for live signals.
- Typography. A characterful mono (IBM Plex Mono or Martian Mono) for labels
  and values, SF Pro for text.
- Colour. Graphite family, one luminous accent, warning amber, red.
- Layout. Dense panels, aligned readouts, scales and ticks.
- Motion. Live meters, scanning indicators.
- Signature. Calibrated ruler ticks on every meter and timeline.
- **Against category.** More rigorous than camera apps, but still close to them.
- Refuses. Paper, serif, warmth.
- Problem. It over-technicalises preparation and reflection, makes long
  German text tiring to read, and visually promotes measurement over the human
  note, the opposite of the product's values. It is also the closest to the
  current design, so it would change the least where change is needed.

### Choice

**Direction A, "Protokoll in drei Tinten".** It is the only direction that grows
directly out of the product's thesis, that measurement, hypothesis and human
judgement must stay distinguishable, and it serves all three emotional states:
calm paper for consent, a dark room for capture, a reading surface for notes.

**What it trades away.** Some immediate "pro camera" credibility on the capture
screen (mitigated by keeping that screen dark, mono and preview-led), and the
uniform dark look some users may have liked (mitigated by full dark-mode support
on paper surfaces). It also depends on A5 and A6; if the serif or the blue ink
does not land, the system still works because the provenance logic is carried by
labels, glyphs and the margin, not by the typeface or hue alone.
