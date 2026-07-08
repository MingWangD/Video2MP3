#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Video2MP3"
CONFIGURATION="${CONFIGURATION:-release}"
VERSION="${VERSION:-0.1.1}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCH=""
UNIVERSAL="false"
FFMPEG_PATH="${FFMPEG_PATH:-$ROOT_DIR/Resources/ffmpeg/ffmpeg}"
ICON_PATH="$ROOT_DIR/Assets/AppIcon.icns"

usage() {
  cat <<'USAGE'
Usage: scripts/package_app.sh [options]

Options:
  --arch arm64|x86_64      Build a single-architecture package.
  --universal              Build a universal package. Requires full Xcode.
  --configuration name     Swift build configuration. Defaults to release.
  --ffmpeg path            Path to the ffmpeg binary to bundle.
  --help                   Show this help.

Without --arch or --universal, the script builds the current machine architecture.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch)
      ARCH="${2:-}"
      shift 2
      ;;
    --universal)
      UNIVERSAL="true"
      shift
      ;;
    --configuration)
      CONFIGURATION="${2:-}"
      shift 2
      ;;
    --ffmpeg)
      FFMPEG_PATH="${2:-}"
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

if [[ "$UNIVERSAL" == "true" && -n "$ARCH" ]]; then
  echo "error: use either --arch or --universal, not both." >&2
  exit 2
fi

if [[ -n "$ARCH" && "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
  echo "error: --arch must be arm64 or x86_64." >&2
  exit 2
fi

cd "$ROOT_DIR"

ARCHIVE_DIR="$ROOT_DIR/dist"
APP_DIR="$ARCHIVE_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BUILD_FLAGS=(-c "$CONFIGURATION")

if [[ "$UNIVERSAL" == "true" ]]; then
  if ! xcodebuild -version >/dev/null 2>&1; then
    echo "error: --universal requires full Xcode. Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
    exit 1
  fi
  BUILD_FLAGS+=(--arch arm64 --arch x86_64)
  ARCHIVE_NAME="$APP_NAME-macOS-universal.zip"
elif [[ -n "$ARCH" ]]; then
  if [[ "$ARCH" != "$(uname -m)" ]] && ! xcodebuild -version >/dev/null 2>&1; then
    echo "error: cross-architecture builds require full Xcode. Requested '$ARCH' on '$(uname -m)'." >&2
    exit 1
  fi
  BUILD_FLAGS+=(--arch "$ARCH")
  ARCHIVE_NAME="$APP_NAME-macOS-$ARCH.zip"
else
  ARCH="$(uname -m)"
  BUILD_FLAGS+=(--arch "$ARCH")
  ARCHIVE_NAME="$APP_NAME-macOS-$ARCH.zip"
  if ! xcodebuild -version >/dev/null 2>&1; then
    echo "warning: full Xcode is not active; building current architecture only ($ARCH)." >&2
  fi
fi

swift build "${BUILD_FLAGS[@]}"
BIN_DIR="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"
EXECUTABLE_PATH="$BIN_DIR/$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

if [[ -f "$ICON_PATH" ]]; then
  cp "$ICON_PATH" "$RESOURCES_DIR/AppIcon.icns"
else
  echo "warning: app icon not found at $ICON_PATH" >&2
fi

mkdir -p "$RESOURCES_DIR/zh-Hans.lproj" "$RESOURCES_DIR/en.lproj"
cat > "$RESOURCES_DIR/zh-Hans.lproj/InfoPlist.strings" <<'STRINGS'
CFBundleDisplayName = "Video2MP3";
CFBundleName = "Video2MP3";
STRINGS
cat > "$RESOURCES_DIR/en.lproj/InfoPlist.strings" <<'STRINGS'
CFBundleDisplayName = "Video2MP3";
CFBundleName = "Video2MP3";
STRINGS

if [[ -f "$FFMPEG_PATH" ]]; then
  cp "$FFMPEG_PATH" "$RESOURCES_DIR/ffmpeg"
  chmod +x "$RESOURCES_DIR/ffmpeg"
  "$ROOT_DIR/scripts/bundle_ffmpeg_deps.sh" "$APP_DIR"
else
  echo "warning: ffmpeg not found at $FFMPEG_PATH; app will require VIDEO2MP3_FFMPEG_PATH or a Homebrew ffmpeg during development." >&2
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>io.github.video2mp3.Video2MP3</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh-Hans</string>
  <key>CFBundleAllowMixedLocalizations</key>
  <true/>
  <key>CFBundleLocalizations</key>
  <array>
    <string>zh-Hans</string>
    <string>en</string>
  </array>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 Video2MP3 contributors. MIT License.</string>
</dict>
</plist>
PLIST

if [[ -d "$RESOURCES_DIR/lib" ]]; then
  while IFS= read -r library_path; do
    codesign --force --sign - "$library_path"
  done < <(find "$RESOURCES_DIR/lib" -type f -name '*.dylib' | sort)
fi

if [[ -x "$RESOURCES_DIR/ffmpeg" ]]; then
  codesign --force --sign - "$RESOURCES_DIR/ffmpeg"
fi

codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent "$APP_DIR" "$ARCHIVE_DIR/$ARCHIVE_NAME"
echo "Built $APP_DIR"
echo "Created $ARCHIVE_DIR/$ARCHIVE_NAME"
