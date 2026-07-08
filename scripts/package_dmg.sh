#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Video2MP3"
ARCH=""
DMG_DIR="$ROOT_DIR/dist"
APP_PATH="$DMG_DIR/$APP_NAME.app"

usage() {
  cat <<'USAGE'
Usage: scripts/package_dmg.sh [options]

Options:
  --arch arm64|x86_64|universal  Architecture label used in the DMG filename.
  --app path                     Path to the .app bundle. Defaults to dist/Video2MP3.app.
  --help                         Show this help.

The script creates a simple installer DMG containing Video2MP3.app and an
Applications shortcut.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch)
      ARCH="${2:-}"
      shift 2
      ;;
    --app)
      APP_PATH="${2:-}"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option '$1'" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$ARCH" ]]; then
  ARCH="$(uname -m)"
fi

case "$ARCH" in
  arm64|x86_64|universal)
    ;;
  *)
    echo "error: --arch must be arm64, x86_64, or universal." >&2
    exit 2
    ;;
esac

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app bundle not found at $APP_PATH. Run scripts/package_app.sh first." >&2
  exit 1
fi

STAGING_DIR="$(mktemp -d "$ROOT_DIR/.dmg-staging.XXXXXX")"
DMG_PATH="$DMG_DIR/$APP_NAME-macOS-$ARCH.dmg"
VOLUME_NAME="$APP_NAME"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

mkdir -p "$DMG_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
COPYFILE_DISABLE=1 hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

hdiutil verify "$DMG_PATH"

MOUNT_OUTPUT="$(hdiutil attach "$DMG_PATH" -nobrowse -readonly)"
MOUNT_POINT="$(printf '%s\n' "$MOUNT_OUTPUT" | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/")); exit}')"
if [[ -z "$MOUNT_POINT" ]]; then
  echo "error: could not determine DMG mount point." >&2
  printf '%s\n' "$MOUNT_OUTPUT" >&2
  exit 1
fi

test -d "$MOUNT_POINT/$APP_NAME.app"
test -L "$MOUNT_POINT/Applications"
hdiutil detach "$MOUNT_POINT" >/dev/null

echo "Created $DMG_PATH"
