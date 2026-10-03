# Changelog

All notable changes to Videographr are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and release identifiers
follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

- No release candidate is designated.
- Bound routine motion guidance updates, advance experimental windows only for
  fresh Vision observations, and record the sampling change in new provenance.
- Reuse Vision requests and capture buffers while retaining audio clipping and
  dropout evidence in bounded UI updates.
- Load sessions asynchronously, avoid repeated journal hydration and full-list
  autosave reads, and copy imports outside the shared persistence lane.
- Fix first-attachment playback, isolate playback clock updates, and report
  checked media availability and pending device checks accurately.
- Encode persisted and exported consent-scope sets in canonical order, so the
  study-package manifest, exported `session.json`, and their digests no longer
  vary between runs for identical sessions. Earlier files still decode.
- Move recording admission, consent and mode transitions, observation
  measurements, and the live experimental analysis windows into SwiftPM
  targets with tests. `AppStore` is now the only writer of the active session.
  Persisted and exported formats are unchanged and pinned by contract tests.

## [0.1.0-alpha.1] - Unreleased

Proposed first public source alpha. The iOS bundle reports marketing version
`0.1.0`, build `1`; the proposed GitHub prerelease tag is `v0.1.0-alpha.1`.

### Added

- German SwiftUI workflow for setup, live capture guidance, reflection, learning
  content, and scientific-alpha information.
- Evidence-safe direct technical observations with explicit missingness.
- Versioned scoped consent, retention, capture decisions, take manifests, media
  provenance, time-linked annotations, and bounded observation and coding journals.
- Protocol-gated experimental hypotheses that stay separate from readiness,
  consent, and export authority, with optional labeled reflection aids kept
  separate from human-authored notes.
- Local device-owner authentication, protected file handling, descriptor-pinned
  imports, and recovery for interrupted persistence operations.
- Consent-scoped study packages with exact metadata membership, SHA-256 digests,
  durable export attempts, and per-attempt leases.
- SwiftPM unit suites, hardware-free app-unit capture-event tests, architecture
  checks, public-hygiene checks, and release Simulator analysis and build commands.

### Known limits

- No signed IPA, TestFlight, App Store, or production deployment is provided.
- Physical-device capture, interruption, audio-route, file-protection, storage,
  thermal, and long-take checks are not current release evidence.
- No dedicated UI-test target or screenshot-baseline harness is present.
- No classroom or minor data is authorized by this repository.
- No human-rater validation or effectiveness study supports pedagogical or
  educational claims.
