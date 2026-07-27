# Releasing

This procedure creates a source-only GitHub prerelease. It does not produce a
signed IPA, TestFlight build, App Store submission, or authorization to collect
classroom or minor data.

## 1. Prepare the final candidate

1. Confirm `RELEASE_VERSION` contains the intended prerelease version.
2. Confirm the Xcode app target has the matching numeric marketing version and
   build number.
3. Finalize `CHANGELOG.md`, `RELEASE_STATUS.md`, and
   `docs/releases/<version>.md`.
4. Confirm the worktree contains no participant media, exports, credentials,
   signing material, environment files, local tool state, or build output.

For `v0.1.0-alpha.1`, the Git version is `0.1.0-alpha.1` and the numeric app
bundle version is `0.1.0 (1)`.

Do not place the candidate commit hash inside that same commit. Record the final
hash and CI URL in the GitHub prerelease or in a later status update.

## 2. Validate the worktree

```bash
scripts/run_e2e_screenshots.sh
bash scripts/verify_release.sh
git status --short --untracked-files=all
```

Inspect all eight screenshots and state notes. Confirm that they contain only
synthetic test content, have no clipping, and match the asserted UI states.

## 3. Create the candidate commit

List every file that will enter the commit:

```bash
git ls-files --cached --others --exclude-standard
python3 scripts/verify_public_hygiene.py
```

The initial public commit must include the app, libraries, tests, public
documentation, version metadata, and a current screenshot set produced by the
passing tour.

1. Create the commit only after explicit maintainer approval.
2. Review the exact commit and its complete file list.
3. Push only after a second approval.
4. Wait for CI on that exact commit.
5. Do not edit release metadata between the successful CI run and tagging.

## 4. Verify repository settings

Before publication:

1. Configure branch protection and required checks on the default branch.
2. Verify a monitored private security and conduct contact.
3. Confirm repository visibility and public metadata.
4. Verify issue templates, contribution guidance, and reporting links in the
   rendered repository.
5. After public visibility, enable GitHub private vulnerability reporting and
   verify the Report a vulnerability flow.

These settings cannot be verified from a local worktree.

## 5. Tag the CI-passed commit

Confirm that `HEAD` is the exact commit that passed CI:

```bash
VERSION="$(tr -d '[:space:]' < RELEASE_VERSION)"
git status --short
git rev-parse HEAD
git tag -s "v${VERSION}" -m "Videographr ${VERSION}"
git show --stat "v${VERSION}"
```

If signed tags are unavailable, use an annotated unsigned tag only after
documenting the exception. Do not move or recreate a published tag.

Review the tag target, obtain explicit approval, and push the tag:

```bash
git push origin "v${VERSION}"
git ls-remote --tags origin "refs/tags/v${VERSION}"
```

## 6. Publish the prerelease

```bash
VERSION="$(tr -d '[:space:]' < RELEASE_VERSION)"
gh release create "v${VERSION}" \
  --prerelease \
  --title "Videographr ${VERSION}" \
  --notes-file "docs/releases/${VERSION}.md" \
  --verify-tag
```

`--verify-tag` requires the tag to exist on the remote. Do not attach a binary
without a separate signing, privacy, device-validation, and distribution process.

After publication, record the immutable commit, CI URL, tag, and release URL in a
later status update if needed.

## Rollback

Before publication, correct the candidate and rerun every gate. After publication,
mark a faulty prerelease as superseded and prepare a new version. Do not rewrite
the published tag.
