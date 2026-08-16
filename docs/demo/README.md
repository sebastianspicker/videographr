# Static demo

This directory contains the build-free GitHub Pages demo for Videographr. It is a
small browser simulation of the native five-tab workflow, not a web version of the
product.

The interface uses only synthetic fixture data. Every control that represents a
native command is marked `SIMULIERT`; it does not access a camera or microphone,
read files, persist data, create exports, or send data over a network.

Serve the repository root locally and open `docs/demo/`:

```bash
python3 -m http.server 4173
```

GitHub Actions uploads this directory as the complete Pages artifact, without a
build step. It is therefore served from the configured Pages subpath, not from
`/docs/demo/`. The stylesheet and script use document-relative URLs, and the
wordmark uses the canonical repository URL, so both checkout and project-Pages
hosting keep their links intact.

The workflow runs only after a push to `main` that changes this directory or on
manual dispatch. Local edits do not deploy the demo.
