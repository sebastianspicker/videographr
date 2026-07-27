# Release status

This file records local worktree evidence. It is not a publication record and does
not identify an immutable release commit.

| Field | Current value |
|---|---|
| Candidate | `v0.1.0-alpha.1` |
| App bundle identity | `0.1.0 (1)` |
| Status date | 2026-07-24 |
| Distribution | Source-only GitHub prerelease candidate; no signed binary |
| Publication state | Local preparation only; not committed, tagged, pushed, or published |

## Local toolchain

| Tool | Exercised version |
|---|---|
| macOS | 26.5.1 (25F80) |
| Xcode | 26.3 (17C529) |
| Swift | 6.2.4 |
| Python | 3.14.6 |
| ShellCheck | 0.11.0 |
| Screenshot Simulator | iPhone 17 Pro, iOS 26.2 |

The documented minimum versions are macOS 14, Swift 5.9, Python 3.10, and an
Xcode toolchain with an iOS 17 or newer SDK. Those minimum combinations were not
exercised locally.

## Local checks

| Check | Status | Evidence |
|---|---|---|
| Public repository hygiene | Passed | 227 candidate files, 227 UTF-8 text files, 19 Markdown files, and no stale public screenshot set |
| Shell and Python verification | Passed | Bash syntax, ShellCheck, 7 attachment-extractor tests, and 7 repository-hygiene tests |
| Evidence-boundary contract | Passed | 8 focused Swift tests |
| Property-list and Xcode project syntax | Passed | `Info.plist` and `project.pbxproj` |
| Strict Swift tests | Passed | 311 tests with complete concurrency checking and warnings as errors |
| Release Swift build | Passed | SwiftPM release configuration with complete concurrency checking and warnings as errors |
| Xcode Release analysis | Passed | Generic iOS Simulator with signing disabled |
| App and UI-test build | Passed | Generic iOS Simulator with signing disabled |
| Complete release gate | Passed | `bash scripts/verify_release.sh` |
| Local Markdown links | Passed | Every relative Markdown target resolves |
| External documentation links | Partially verified | 35 URLs checked; direct resources returned successfully, and publisher-blocked DOI links resolved to registered destinations |
| Runtime screenshot tour | Failed | Current tour reached the simulator recording rejection, then `VideographrE2EScreenshots.swift:324` could not keep `live.recordStatus` visible |
| Focused Setup UI regression | Passed | Virtualized Setup form traversal completed in 93.628 seconds |
| Compact Live UI regression | Failed | `VideographrE2EScreenshots.swift:298` could not find `live.observability.exposure` in landscape |
| CI on immutable commit | Not available | The repository has no commit history or published CI run |
| Physical-device matrix | Open | Oldest supported iPhone, current iPhone, and supported iPad form factor |
| Human validation | Not available | No authorized corpus or trained-rater study |
| Effectiveness | Not available | No educational outcome study |

The screenshot command publishes only a complete passing set. The 2026-07-22 set
was archived because it is not current-candidate runtime evidence.

Local compile, test, and Simulator build success does not close device,
human-validation, or effectiveness gates.

## Publication blockers

- Repair the Live-screen visibility assertions for `live.recordStatus` and
  compact-mode `live.observability.exposure`, rerun the three UI tests, then
  inspect all eight current screenshots.
- Configure and verify a monitored private security and conduct contact before
  making the repository public.
- After public visibility, enable GitHub private vulnerability reporting and
  verify the Report a vulnerability flow.
- Create and review the final candidate commit only after maintainer approval,
  then obtain a successful CI result for that exact commit.
- Configure and verify repository visibility, branch protection, required checks,
  and rendered community-file links.
- Replace the source-checkout installation wording with the canonical repository
  URL when a remote exists.

A signed iOS distribution path remains outside this candidate.

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
