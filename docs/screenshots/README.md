# Videographr screenshots

The `VideographrE2EScreenshots` XCUITest captures eight named states after their
accessibility assertions pass. Host-side validation requires the exact eight
images and notes, rejects duplicate semantic states, and publishes the complete
set transactionally to `docs/screenshots/e2e/`.

Regenerate the set with:

```bash
scripts/run_e2e_screenshots.sh
```

No current screenshot set is published while the canonical tour is failing. The
[release status](../../RELEASE_STATUS.md) records the current failure. A failed or
partial run leaves the public screenshot directory absent or unchanged.

Simulator screenshots demonstrate visible UI states only. They are not evidence
for physical camera, microphone, file protection, interruption handling, or
long-take behavior.
