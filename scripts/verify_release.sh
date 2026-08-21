#!/usr/bin/env bash
# Deterministic local/CI gate for the public source alpha candidate.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Public repository hygiene"
PYTHONDONTWRITEBYTECODE=1 python3 scripts/verify_public_hygiene.py

echo "==> Script syntax"
bash -n scripts/*.sh
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck scripts/*.sh
fi
echo "==> Plist and Xcode project syntax"
plutil -lint App/Unterrichtsvideographie/Info.plist
plutil -lint App/Unterrichtsvideographie.xcodeproj/project.pbxproj

echo "==> Strict Swift tests"
swift test --disable-sandbox \
  -Xswiftc -strict-concurrency=complete \
  -Xswiftc -warnings-as-errors

echo "==> Release Swift build"
swift build --disable-sandbox -c release \
  -Xswiftc -strict-concurrency=complete \
  -Xswiftc -warnings-as-errors

echo "==> Xcode Release analysis"
xcodebuild -quiet \
  -project App/Unterrichtsvideographie.xcodeproj \
  -scheme Unterrichtsvideographie \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  clean analyze

echo "==> App build"
xcodebuild -quiet \
  -project App/Unterrichtsvideographie.xcodeproj \
  -scheme Unterrichtsvideographie \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "Public alpha release gate passed."
