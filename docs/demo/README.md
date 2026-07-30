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

GitHub Actions publishes this directory without a build step.
