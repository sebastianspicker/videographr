#!/usr/bin/env bash
# Run the assertion-backed eight-screen Videographr E2E UI tour on iOS Simulator.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/App"
PROJECT="$APP_DIR/Unterrichtsvideographie.xcodeproj"
SCHEME="Unterrichtsvideographie"
BUNDLE_ID="de.videographie.Unterrichtsvideographie"
SHOT_DIR="${E2E_SCREENSHOT_DIR:-$ROOT/docs/screenshots/e2e}"
SHOT_PARENT="$(dirname "$SHOT_DIR")"
DEVICE_NAME="${E2E_DEVICE:-iPhone 17 Pro}"
DERIVED="${E2E_DERIVED:-$ROOT/.derived-e2e}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/videographr-e2e.XXXXXX")"
RESULT_BUNDLE="$WORK_DIR/result.xcresult"
EXPORTED_ATTACHMENTS="$WORK_DIR/attachments"
STAGING_DIR="$WORK_DIR/staging"
PUBLISH_DIR=""
BACKUP_DIR=""

cleanup() {
  exit_status=$?
  trap - EXIT
  rm -rf -- "$WORK_DIR"
  if [[ -n "$PUBLISH_DIR" ]]; then
    rm -rf -- "$PUBLISH_DIR"
  fi
  if [[ -n "$BACKUP_DIR" ]]; then
    if [[ ! -e "$SHOT_DIR" && ! -L "$SHOT_DIR" ]]; then
      mv -- "$BACKUP_DIR" "$SHOT_DIR"
    else
      rm -rf -- "$BACKUP_DIR"
    fi
  fi
  exit "$exit_status"
}
trap cleanup EXIT

mkdir -p "$SHOT_PARENT"

echo "==> Boot simulator: $DEVICE_NAME"
UDID="$(xcrun simctl list devices available | awk -v n="$DEVICE_NAME" '
  match($0, /\([A-F0-9-]{36}\)/) {
    device_name=substr($0, 1, RSTART-1)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", device_name)
    if (device_name == n) {
      id=substr($0, RSTART+1, RLENGTH-2)
      print id
      exit
    }
  }')"
if [[ -z "${UDID:-}" ]]; then
  echo "Could not find simulator matching: $DEVICE_NAME" >&2
  xcrun simctl list devices available >&2
  exit 1
fi

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
open -a Simulator --args -CurrentDeviceUDID "$UDID" 2>/dev/null || true

echo "==> Build app and UI-test bundle for simulator"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DERIVED" \
  build-for-testing

APP_BUNDLE="$DERIVED/Build/Products/Debug-iphonesimulator/Unterrichtsvideographie.app"
echo "==> Install clean app container + privacy grants"
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP_BUNDLE"
xcrun simctl privacy "$UDID" grant camera "$BUNDLE_ID"
xcrun simctl privacy "$UDID" grant microphone "$BUNDLE_ID"

echo "==> Assertion-backed XCUITest tour → staging"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DERIVED" \
  -only-testing:VideographrUITests/VideographrE2EScreenshots/testE2E_coreFunctionsScreenshotTour \
  -resultBundlePath "$RESULT_BUNDLE" \
  test-without-building

echo "==> Export and verify retained XCTest attachments"
xcrun xcresulttool export attachments \
  --path "$RESULT_BUNDLE" \
  --output-path "$EXPORTED_ATTACHMENTS"
python3 "$ROOT/scripts/extract_e2e_attachments.py" \
  --source "$EXPORTED_ATTACHMENTS" \
  --destination "$STAGING_DIR"

PNG_COUNT="$(find "$STAGING_DIR" -maxdepth 1 -type f -name '*.png' 2>/dev/null | wc -l | tr -d ' ')"
echo "PNG count: $PNG_COUNT"
if [[ "$PNG_COUNT" -ne 8 || ! -f "$STAGING_DIR/README.md" ]]; then
  echo "Incomplete tour: expected the eight contracted PNGs and README.md." >&2
  exit 1
fi

echo "==> Publish complete screenshot set → $SHOT_DIR"
PUBLISH_DIR="$(mktemp -d "$SHOT_PARENT/.videographr-publish.XXXXXX")"
cp -R "$STAGING_DIR/." "$PUBLISH_DIR/"
if [[ -e "$SHOT_DIR" || -L "$SHOT_DIR" ]]; then
  BACKUP_DIR="$SHOT_PARENT/.videographr-backup.$$"
  if [[ -e "$BACKUP_DIR" ]]; then
    echo "Refusing to overwrite existing publish backup: $BACKUP_DIR" >&2
    exit 1
  fi
  mv -- "$SHOT_DIR" "$BACKUP_DIR"
fi
mv -- "$PUBLISH_DIR" "$SHOT_DIR"
PUBLISH_DIR=""
if [[ -n "$BACKUP_DIR" ]]; then
  rm -rf -- "$BACKUP_DIR"
  BACKUP_DIR=""
fi
ls -la "$SHOT_DIR"
