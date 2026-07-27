# Contributing

Videographr is a source alpha with explicit evidence and data-handling boundaries.
Changes must preserve those boundaries and include deterministic verification.

## Before changing code

Read:

1. [Product scope](PRODUCT.md)
2. [Scientific alpha contract](docs/SCIENTIFIC_ALPHA.md)
3. [Architecture](docs/ARCHITECTURE.md)
4. [Research gap inventory](docs/RESEARCH_GAP_INVENTORY.md)
5. [Security policy](SECURITY.md)

Open an issue before making a broad change to stored schemas, consent authority,
evidence claims, platform requirements, or the release process.

## Development setup

Requirements and installation are documented in [README.md](README.md). Verify the
package before opening the app:

```bash
swift test --disable-sandbox \
  -Xswiftc -strict-concurrency=complete \
  -Xswiftc -warnings-as-errors

open App/Unterrichtsvideographie.xcodeproj
```

The public product name is Videographr. The package, scheme, target, path, and
bundle names use `Unterrichtsvideographie`.

## Code organization

- Put pure, deterministic domain logic in `Sources/`.
- Keep SwiftUI and Apple-framework adapters in `App/`.
- Add package tests under the matching SwiftPM target directory in `Tests/`.
- Add repository-tooling tests under `Tests/RepositoryToolingTests/`.
- Add visible app-flow coverage under `App/VideographrUITests/`.
- Do not add a production dependency without maintainer approval.

## Change requirements

- Make one clear behavioral change at a time.
- Treat Swift warnings as errors and keep complete concurrency checking enabled.
- Test expected behavior, failure handling, and state transitions.
- Preserve transaction ownership in recording, import, deletion, and export paths.
- Keep user-facing German terminology consistent with the existing interface.
- Keep direct capture observations separate from pedagogical interpretation.
- Update the scientific and evaluation documents when the evidence scope changes.
- Update architecture documentation when module ownership or runtime flow changes.
- Regenerate and inspect all eight screenshots after a visible UI change.
- Do not commit participant media, personal data, consent documents, study
  packages, signing material, environment files, or service credentials.

## Verification

Run the complete gate:

```bash
bash scripts/verify_release.sh
```

For visible UI changes, also run:

```bash
scripts/run_e2e_screenshots.sh
```

The screenshot command publishes a replacement set only after the asserted UI
test and attachment checks pass. Inspect every PNG and its matching state note
before requesting review.

## Pull requests

A pull request should:

- explain the user-visible and evidence-scope impact
- link relevant issues
- identify stored-schema or compatibility effects
- list commands run and their results
- identify skipped device or manual checks
- use only synthetic or redacted logs and screenshots

Do not attach recordings, exports, consent documents, or sensitive diagnostic
material. Report security-sensitive findings through the process in
[SECURITY.md](SECURITY.md), not a public issue.

Contributions are licensed under the [MIT License](LICENSE).
