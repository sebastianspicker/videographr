# Static demo

This directory contains the build-free GitHub Pages demo for Videographr. It is a
small browser simulation of the native five-tab workflow, not a web version of the
product. It is a product walkthrough only and does not establish device, human-rater,
scientific, accessibility, or effectiveness validation.

Two static pages ship here:

- `index.html` is the interactive simulation.
- `tour.html` is a read-only screenshot tour of the native app. Its images are
  real SwiftUI renders captured by the app-unit test target on Simulators with
  synthetic fixtures, mirrored from `../screenshots/`. They are not physical-device
  captures and show no people.

The interface uses only synthetic fixture data from `mock-data.js`. Every control
that represents a native command is marked `SIMULIERT`; it does not access a camera
or microphone, read files, persist data, create exports, or send data over a network.
`demo.js` keeps temporary state only in memory until the page is reloaded. It does
not use `fetch`, browser storage, file inputs, media APIs, or a backend.

The simulated study-package gate uses the same explicit boundary as the native
product: `.videographrstudy` is `de.videographr.study`, contains only metadata, and
never contains a recorded or imported MP4. The displayed member names are fixtures;
the demo generates no package or digest.

Serve the repository root locally and open `docs/demo/`:

```bash
python3 -m http.server 4173
```

GitHub Actions uploads this directory as the complete Pages artifact, without a
build step. It is therefore served from the configured Pages subpath, not from
`/docs/demo/`. The stylesheet and scripts use document-relative URLs, so the
artifact works when this directory is the Pages root.

The workflow runs only after a push to `main` that changes this directory or on
manual dispatch. Local edits do not deploy the demo.

## Verification boundary

`scripts/verify_demo.py` keeps the artifact build-free and offline. It permits only
the required demo files, `tour.html`, and local `shots/*.webp` images. The
interactive page may not embed media, and the tour may reference only existing local
screenshots with non-empty alternative text. Scripts, remote URLs, inline handlers,
storage, file, device, and network APIs remain rejected.
