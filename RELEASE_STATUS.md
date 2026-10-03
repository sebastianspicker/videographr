# Release status

Last reviewed: 2026-09-02

Videographr is an unpublished, source-only alpha. No commit is designated as a
release candidate by this document. A local source inspection confirms the
architecture and release commands described here, but that is not a record of a
successful release-gate run for a particular commit.

The configured prerelease identifier is `0.1.0-alpha.1`, and the Xcode app bundle
identity is `0.1.0 (1)`.

## Required candidate checks

- Run `bash scripts/verify_release.sh` from the exact candidate commit.
- Obtain required CI for that same commit.
- Review the final tracked-file manifest and public-hygiene exclusions.
- Confirm matching release version, release notes, and Xcode bundle version.
- Verify remote branch protection, private vulnerability reporting, a separate
  conduct route, rendered community-file links, and Pages state.

[RELEASING.md](RELEASING.md) lists what the local gate runs and covers. There is
no dedicated UI-test target or screenshot-baseline harness.

## External validation still required

- Camera and microphone capture, audio routes, interruptions, backgrounding,
  orientation, storage pressure, thermal behavior, and long takes on supported
  iPhone and iPad hardware
- Locked-device file protection, authentication cancellation and relaunch, File
  Provider mutation, consent expiry during capture or sharing, and recovery
- A staged adult technical pilot before any classroom or minor data
- Independent human-rater validation before interpreting experimental hypotheses
- An effectiveness study before claiming improved reflection, teaching, or learning
- Subject and provenance review of the annotated bibliography
- Ownership review for `de.videographie.Unterrichtsvideographie` and
  `de.videographr.study` before signing or distribution
- Final icon and distribution validation

No classroom or minor data is authorized by this repository. Local builds and
Simulator checks do not establish device behavior, human validation, or
educational effectiveness.
