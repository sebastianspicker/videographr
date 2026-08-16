# Release status

This file records evidence observed on 2026-08-09. Local results describe the
current dirty worktree, not an immutable release commit. Remote results are named
separately and do not imply that local remediation was published.

| Field | Current value |
|---|---|
| Candidate | `v0.1.0-alpha.1` |
| App bundle identity | `0.1.0 (1)` |
| Status date | 2026-08-09 |
| Distribution | Source-only GitHub prerelease candidate; no signed binary |
| Local state | `main` at `2625e743a535b6e8ce8c1bbf9dc5c5b240d5d307` with preserved tracked and untracked changes; no local commit, tag, push or deployment was made by this remediation |
| Remote state | Public repository; remote `main` observed at `fdcbb07dc75dadb15372f970798d0c4a9a13f3fd`, ahead of the local checkout |

## Current local addendum: 2026-08-14

The dated candidate record below remains useful historical evidence, but it does
not describe every live-worktree result. In the current checkout:

- a Swift 6 concurrency failure in the Simulator guidance timer was fixed by
  keeping its tick counter on the main-actor model instead of capturing mutable
  task state;
- the strict Swift package suite passed all 311 tests under Xcode 26.6 with
  complete concurrency checking and warnings treated as errors;
- the release Swift build, evidence-boundary tests, repository-tooling tests,
  generic-Simulator Release build, and two focused UI regressions passed;
- the complete screenshot tour is currently blocked because XCTest reports an
  invalid activation point for `live.start`; the August 9 passing tour below is
  historical rather than current-candidate closure;
- `verify_release.sh` stops at public hygiene because preserved local state
  includes an untracked machine-specific `.mcp.json`, two tracked deleted
  cleanup source files, and ignored `.DS_Store` files; and
- the static Pages artifact served its HTML, CSS, and JavaScript routes locally,
  and its JavaScript passed syntax checking. Rendered browser interaction was
  not available in this environment, and no deployment was performed.

## Local toolchain

| Tool | Exercised version |
|---|---|
| macOS | 26.5.1 (25F80) |
| Xcode | 26.3 (17C529) |
| Swift | 6.2.4 |
| Python | 3.14.6 |
| ShellCheck | 0.11.0 |
| Screenshot Simulator | temporary iPhone 17, iOS 26.2 |

The documented minimum versions are macOS 14, Swift 5.9, Python 3.10, and an
Xcode toolchain with an iOS 17 or newer SDK. Those minimum combinations were not
exercised locally.

## Current candidate checks

| Check | Status | Evidence |
|---|---|---|
| Public repository hygiene | Failed | Preserved local generated and tool state is included by the verifier; no cleanup or ignore change was authorized |
| Shell and Python verification | Passed | Bash syntax, ShellCheck, and 16 repository-tooling tests |
| Evidence-boundary contract | Passed | 8 focused Swift tests |
| Property-list and Xcode project syntax | Passed | `Info.plist` and `project.pbxproj` |
| Strict Swift tests | Passed | 311 tests with complete concurrency checking and warnings as errors |
| SwiftPM coverage | Passed with bounded scope | 10,321 of 11,110 package-source lines, or 92.90%; the iOS app target is not part of this report |
| Release Swift build | Passed | External SwiftPM release scratch path with complete concurrency checking and warnings as errors |
| Xcode Release analysis | Passed | Generic iOS Simulator, signing disabled, zero errors, warnings or analyzer warnings |
| SwiftLint | Completed with four threshold findings | 191 live Swift files mapped; two 55 to 56 line function warnings and two file-length informational findings retained as reviewed evidence |
| App and UI-test build | Passed | iPhone 17 simulator build-for-testing under Xcode 26.3 |
| Complete release gate | Blocked | `verify_release.sh` stops at the failing public-hygiene boundary before later lanes |
| Focused Setup UI regression | Passed | Final iPhone 17 script invocation completed in 116.563 seconds with consent persistence assertions intact |
| Compact Live UI regression | Passed | Genuine Landscape Right contract completed in 5.426 seconds with visible direct exposure evidence |
| Runtime screenshot tour | Passed | Core tour completed in 262.372 seconds; exactly eight exported PNG/state-note pairs were manually reviewed |
| CI on current local candidate | Not available | Current remediation is intentionally uncommitted and unpushed |
| Physical-device matrix | Open | Oldest supported iPhone, current iPhone, and supported iPad form factor |
| Human validation | Not available | No authorized corpus or trained-rater study |
| Effectiveness | Not available | No educational outcome study |

Generated analyzer, coverage, simulator and test artifacts are retained outside
the repository. Local compile, test and Simulator results do not close device,
human-validation or effectiveness gates.

## Verified remote surfaces

- GitHub private vulnerability reporting was enabled when queried on 2026-08-09.
  Notification delivery, named triage ownership and acknowledgement were not
  tested.
- The current remote `main` contains the README demo link, Pages workflow and all
  four static demo files.
- GitHub Pages reported a successful workflow deployment and the public demo URL
  returned HTTP 200. Browser-rendered interaction was not available in this
  environment.

## Publication blockers

- Authorize a candidate-boundary cleanup for preserved local generated and tool
  state, then rerun public hygiene without suppressing genuine leaks.
- Complete a synthetic private-vulnerability submission, notification and
  acknowledgement test with named triage ownership.
- Provision and test a separate monitored private conduct-reporting route.
- Create and review the final candidate commit only after maintainer approval,
  then obtain successful required CI checks for that exact commit.
- Verify branch protection, required checks and rendered community-file links.

A signed iOS distribution path remains outside this source-only candidate.

## External validation

- Real camera and microphone capture, interruptions, backgrounding, orientation,
  and audio routes
- Locked-device file protection, authentication cancellation and relaunch,
  storage pressure, and thermal behavior
- Consent expiry during capture and sharing, File Provider mutation, crash
  recovery, and a 60-minute take with measured synchronization and finalization
- A staged adult technical pilot before any classroom or minor data
- Independent human-rater validation before interpreting experimental hypotheses
- An effectiveness study before claiming improved reflection, teaching, or
  learning
- Subject and provenance review of the non-systematic annotated bibliography
- Ownership review for `de.videographie.Unterrichtsvideographie` and
  `de.videographr.study` before signing or distribution
- Final 1024 by 1024 app icon artwork and distribution validation

No classroom or minor data is authorized by this repository.
