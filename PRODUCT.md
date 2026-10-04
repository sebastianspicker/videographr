# Product scope

## Intended users

Videographr is intended for educational researchers, teacher educators, and
methods evaluators who prepare, record, and review classroom video under explicit
consent and provenance requirements.

## Supported workflow

The app provides one local workflow:

1. Define the session purpose and context.
2. Record versioned consent grants and retention information.
3. Review direct capture conditions.
4. Record one continuous local take.
5. Add human-authored, time-linked reflection notes.
6. Export authorized session metadata as a study package.

The study package contains metadata, observations, annotations, digests, and
provenance. It does not contain the recorded or imported video, and the current
app has no separate video-export operation.

## Evidence boundary

Capture measurements remain separate from pedagogical interpretation. The app
reports measured values, availability, and missing states. It does not assign
teaching-quality scores or claim that a recording is scientifically valid.

Experimental research mode stores separately labeled hypotheses only when the
session includes protocol metadata, an oversight reference, an expiry, and an
acknowledgement. Experimental output does not control recording or export.

## Out of scope

- Video editing
- Multi-camera synchronization
- Cloud storage or portal upload
- Accounts, institutional roles, or remote device administration
- Automated pedagogical assessment
- Legal or institutional approval
- Human-rater validation or educational-effectiveness claims

## Interface requirements

- German user-facing text
- Visible operating-mode and consent state
- Explicit missing and unavailable states
- Status communicated by text or symbols, not color alone
- Support for Dynamic Type and reduced motion
- Body-text contrast targeting WCAG 2.2 AA

These are design requirements.
