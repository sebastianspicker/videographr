# Scientific alpha contract

| Field | Value |
|---|---|
| Product | Videographr |
| Candidate | `v0.1.0-alpha.1` |
| Platform | iOS and iPadOS 17 or newer |
| Default mode | Evidence-safe |
| Experimental mode | Protocol-gated, explicitly unvalidated hypotheses |
| Distribution | Source only |

## Product claim

Videographr supports the practical collection and review of classroom-video
evidence. It records purpose, context, consent, capture metadata, local media,
time-linked human notes, and export provenance.

This is an implementation claim. It is not a claim that the app measures teaching
quality, learning, or scientific validity.

## Evidence-safe mode

Evidence-safe mode:

- reports signal availability, stability, framing, exposure, visible areas, and
  basic audio levels and routes
- records explicit missing and unavailable states
- supports time-linked human reflection
- does not output IPN, TIMSS, GTI, discourse, feedback, cognitive activation,
  social-emotional support, learning, speech-intelligibility, or teaching-quality
  measures
- does not describe a recording as research-ready or scientifically validated

## Experimental research mode

Experimental research mode requires a protocol identifier, an oversight or contact
reference, a future expiry, and an acknowledgement of unvalidated status. It may
store separately namespaced, rule-based hypotheses with mode and protocol
provenance.

Those hypotheses do not determine recording readiness, reflection content, consent
authority, or export authority. They have no human-rater or psychometric
validation.

## Research context

The capture workflow is informed by the
[Derry video-research guidelines](https://cpb-us-e2.wpmucdn.com/faculty.sites.uci.edu/dist/2/425/files/2011/03/video-research-guidelines.pdf).
IPN, TIMSS, and OECD GTI/TALIS Video are treated as context for trained human
observation. The [TIMSS instruments](https://www.timssvideo.com/instruments) and
[OECD GTI framework](https://www.oecd.org/en/publications/global-teaching-insights_20d6f36b-en/full-report/component-6.html)
do not establish an automatic mapping from camera measurements to pedagogical
constructs.

The reflection fields are informed by
[Lesson Analysis Framework research](https://doi.org/10.1177/0022487110369555).
The repository does not contain an evaluation showing that this workflow improves
reflection or educational outcomes.

## Claim levels

| Level | Current status |
|---|---|
| Literature mapped | Background sources are recorded, subject to source review. |
| Implemented | Current source represents the behavior. |
| Unit tested | Deterministic tests cover specified contracts. |
| Simulator checked | Build and asserted UI states can be checked without physical capture hardware. |
| Device verified | Open for this candidate. |
| Human validated | Not available. |
| Effectiveness tested | Not available. |

The [release status](../RELEASE_STATUS.md) records the remaining candidate and
external-validation gates.
