# Architecture

## Targets

`Package.swift` defines three libraries with no third-party package dependencies:

| Target | Responsibility |
|---|---|
| `GuidanceEngine` | Direct capture observations, missing-state handling, readiness inputs, and separately labeled experimental hypothesis types |
| `SessionCore` | Sessions, consent, persistence, capture transactions, reflection, import, and study-package export |
| `LearnContent` | German-language recording reference catalogue |

The Xcode project at `App/Unterrichtsvideographie.xcodeproj` contains the iOS
application and `VideographrUITests`. The app target links the three libraries and
owns integration with SwiftUI, AVFoundation, Vision, Core Motion,
LocalAuthentication, UIKit, and the file system.

Swift package tests follow their target directories under `Tests/`. Repository
tooling tests are Python `unittest` modules under
`Tests/RepositoryToolingTests/`. UI tests remain beside the Xcode app project at
`App/VideographrUITests/`.

## App structure

`UnterrichtsvideographieApp` creates one `AppSessionModel` and places the UI behind
`OperatorAccessController`. `RootTabView` presents five tabs:

| Tab | Primary view | Responsibility |
|---|---|---|
| Setup | `SetupView` | Session selection, context, operating mode, consent, and retention |
| Live | `LiveGuidanceView` | Capture preview, direct observations, readiness, and recording |
| Reflect | `ReflectView` | Local media review and time-linked notes |
| Learn | `LearnRootView` | Reference catalogue |
| Info | `AboutView` | Product scope, evidence boundary, and platform information |

## Runtime flow

```text
Setup
  -> CaptureSession and scoped ConsentGrant values
  -> SessionStore

Live
  -> CameraSessionModel
  -> AVFoundation, Vision, Core Motion
  -> direct observations and explicit missing states
  -> ReadinessAggregator
  -> transaction-specific recording preparation
  -> finalized local media and take metadata

Reflect
  -> local media
  -> time-linked annotations

Export
  -> active consent scopes
  -> StudyPackageBuilder
  -> .videographrstudy package
  -> system share sheet and durable outcome record
```

There is no path from camera geometry or person counts to a validated pedagogical
score. Experimental hypotheses are stored separately and are not recording,
reflection, consent, or export authority.

## Persistence

`SessionStore` writes to the app's Application Support directory by default.
`AppSessionModel` performs startup reconciliation, coalesced autosave, session
selection, and async store operations.

The stored model includes session context, operating mode, consent grants,
retention information, media assets, capture decisions, take manifests,
annotations, build provenance, and export attempts. Observation and experimental
histories use bounded JSONL journals.

Recording uses a transaction identifier and a prepared lifecycle state. The app
revalidates the captured consent bindings before start and again during
finalization. A recording is attached to session metadata only after AVFoundation
finishes and media inspection succeeds. Late callbacks retain transaction
ownership so they cannot finalize or remove another take.

Study packages contain:

- `manifest.json`
- `session.json`
- `annotations.jsonl`
- `observations.jsonl`
- `coding-snapshots.jsonl`

The package contains no video payload. The app currently provides no separate
operation for exporting the recorded or imported MP4. The package manifest
declares membership and SHA-256 digests for the four non-manifest content files.
Temporary packages use unique per-attempt paths and remain leased until the share
outcome is resolved. The durable share-attempt record remains in local session
state rather than becoming a package member.

## Security boundaries

The app requests device-owner authentication on launch and after returning from
the background. A privacy cover hides app content while the scene is inactive.
This is a single-device access boundary, not an account or institutional role
system.

The store applies backup-exclusion and iOS file-protection attributes to local
artifacts. Import, deletion, recording, and export code uses markers,
transaction-specific ownership, or compensating restoration. These are
implementation properties. Their behavior under lock state, interruption,
storage pressure, and device policy still requires physical-device testing.

## Verification boundaries

Swift package tests cover pure transformations and persistence contracts. Generic
Simulator builds cover compile integration. The XCUITest tour covers eight visible
synthetic states.

Those checks do not validate real camera formats, microphone quality, audio-route
changes, interruptions, thermal limits, lock-state protection, or long-take media
integrity. See [RELEASE_STATUS.md](../RELEASE_STATUS.md).
