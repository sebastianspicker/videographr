# Changelog

All notable changes to Videographr are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and release identifiers follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

No changes are recorded after the current candidate.

## [0.1.0-alpha.1] - Unreleased

Candidate for the first public source alpha. The iOS bundle reports marketing version `0.1.0`,
build `1`; the proposed GitHub prerelease tag is `v0.1.0-alpha.1`.

### Added

- German SwiftUI workflow for setup, live capture guidance, reflection, learning content, and
  scientific-alpha information.
- Evidence-safe direct technical observations with explicit missingness.
- Versioned scoped consent, retention, capture decisions, take manifests, media provenance,
  time-linked annotations, and bounded observation/coding journals.
- Protocol-gated experimental hypotheses that remain separate from readiness and user reflection.
- Local device-owner authentication, protected file handling, descriptor-pinned imports, and
  rollback/reconciliation for interrupted persistence operations.
- Consent-scoped study packages with exact membership, SHA-256 digests, durable export attempts,
  per-attempt leases, and exactly-once outcome transitions.
- SwiftPM unit suites and assertion-backed Simulator screenshot workflow.
- Public scientific-alpha, evaluation, security, contribution, release, and research-gap docs.

### Fixed

- Experimental guidance now describes direct visibility and explicitly unvalidated rule results
  without asserting IPN, coding, or analysis suitability.
- Public API documentation describes experimental thresholds as unvalidated rule inputs rather
  than evidence of research or analysis suitability.
- Learn privacy copy distinguishes configured iOS protections from physical-device verification.
- Recording-state and guidance-activity chips use distinct labels.
- Public writing-policy checks no longer interpret Swift operators or web URL paths as formatting
  and machine-specific paths.
- The screenshot tour locates off-viewport SwiftUI form fields by geometry before its final
  hittability assertion.
- Late AVFoundation callbacks can no longer finalize, fail, or remove a newer recording transaction.
- Capture callback timeouts now preserve an honest completion-unknown state until a late result or
  relaunch reconciliation resolves ownership.
- Concurrent edits and share-sheet outcomes cannot overwrite unrelated session or terminal export
  state.
- Failed session deletion restores metadata, journals, and quarantined media before returning.
- Imports reject unsafe file types and remain bound to the opened descriptor during the copy.
- Simulator recording attempts are rejected before recording storage is prepared, and late capture
  errors cannot displace the active synthetic fallback.
- Learn-topic paragraphs and line breaks remain visible after Markdown rendering.
- Xcode 26 attachment-name decoration is normalized without weakening the exact eight-screenshot
  evidence contract.
- The app target shares audio-sample construction across capture and Simulator guidance paths, so
  the signing-disabled Release analysis compiles both paths.

### Known limits

- No signed IPA, TestFlight, App Store, or production deployment is provided.
- Physical-device capture, interruptions, audio routes, file protection, storage/thermal pressure,
  and a 60-minute take are not yet closed release evidence.
- No classroom or minor data is authorized by this repository.
- No human-rater validation or effectiveness study supports pedagogical or educational claims.
