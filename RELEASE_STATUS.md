# Release status

Last reviewed: 2026-08-18

Videographr is an unpublished, source-only alpha. The intended prerelease label
is `v0.1.0-alpha.1`; no commit is currently designated as the release
candidate. The current source identity before this documentation pass was
`52903e384af0abdbd1dc31d23f8629530830e995` on `main`. The corresponding app
bundle identity in the Xcode project is `0.1.0 (1)`.

There is no signed iOS build or distribution claim. Local builds, tests, and
Simulator runs do not establish physical-device behavior, human validation, or
educational effectiveness.

## Release checks

Before publishing a candidate:

- run `bash scripts/verify_release.sh` from the exact commit intended for the
  release;
- obtain successful required CI checks for that commit;
- review the final tracked-file manifest and generated-artifact exclusions;
- build and analyze the release configuration with the documented Xcode and
  Swift settings;
- run the focused unit contracts;
- verify private vulnerability reporting and a separate monitored conduct
  reporting route;
- confirm branch protection, required checks, Pages deployment, and rendered
  community-file links; and
- complete the external validation listed below.

## External validation

- Real camera and microphone capture, interruptions, backgrounding,
  orientation, and audio routes
- Locked-device file protection, authentication cancellation and relaunch,
  storage pressure, and thermal behavior
- Consent expiry during capture and sharing, File Provider mutation, crash
  recovery, and a 60-minute take with measured synchronization and finalization
- Oldest supported iPhone, a current iPhone, and a supported iPad form factor
- A staged adult technical pilot before any classroom or minor data
- Independent human-rater validation before interpreting experimental
  hypotheses
- An effectiveness study before claiming improved reflection, teaching, or
  learning
- Subject and provenance review of the non-systematic annotated bibliography
- Ownership review for `de.videographie.Unterrichtsvideographie` and
  `de.videographr.study` before signing or distribution
- Final 1024 by 1024 app icon artwork and distribution validation

No classroom or minor data is authorized by this repository.

## Supported-version evidence

The documented minimum versions are macOS 14, Swift 5.9, Python 3.10, and an
Xcode toolchain with an iOS 17 or newer SDK. Those minimum combinations require
their own verification; a newer local toolchain does not prove them.
