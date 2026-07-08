#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: scripts/bundle_ffmpeg_deps.sh /path/to/App.app" >&2
  exit 2
fi

APP_DIR="$1"
FFMPEG_PATH="$APP_DIR/Contents/Resources/ffmpeg"
LIB_DIR="$APP_DIR/Contents/Resources/lib"

if [[ ! -x "$FFMPEG_PATH" ]]; then
  echo "error: ffmpeg executable not found at $FFMPEG_PATH" >&2
  exit 1
fi

mkdir -p "$LIB_DIR"

is_bundle_candidate() {
  local dep="$1"
  case "$dep" in
    /System/*|/usr/lib/*)
      return 1
      ;;
    @*)
      return 1
      ;;
    *)
      [[ -f "$dep" ]]
      ;;
  esac
}

list_deps() {
  local binary="$1"
  otool -L "$binary" | tail -n +2 | awk '{print $1}'
}

rewrite_binary_dep() {
  local binary="$1"
  local original="$2"
  local replacement="$3"
  install_name_tool -change "$original" "$replacement" "$binary" 2>/dev/null || true
}

copy_dep_if_needed() {
  local dep="$1"
  local destination="$LIB_DIR/$(basename "$dep")"
  if [[ ! -f "$destination" ]]; then
    cp "$dep" "$destination"
    chmod u+w "$destination"
  fi
  printf '%s\n' "$destination"
}

queue=("$FFMPEG_PATH")
processed_file="$(mktemp "$APP_DIR/Contents/Resources/.processed-ffmpeg-deps.XXXXXX")"

while [[ ${#queue[@]} -gt 0 ]]; do
  binary="${queue[0]}"
  queue=("${queue[@]:1}")

  if grep -Fxq "$binary" "$processed_file"; then
    continue
  fi
  printf '%s\n' "$binary" >> "$processed_file"

  if [[ "$binary" == "$FFMPEG_PATH" ]]; then
    install_prefix="@executable_path/lib"
  else
    install_prefix="@loader_path"
    install_name_tool -id "@loader_path/$(basename "$binary")" "$binary" 2>/dev/null || true
  fi

  while IFS= read -r dep; do
    if ! is_bundle_candidate "$dep"; then
      continue
    fi

    copied_dep="$(copy_dep_if_needed "$dep")"
    replacement="$install_prefix/$(basename "$copied_dep")"
    rewrite_binary_dep "$binary" "$dep" "$replacement"

    should_enqueue="true"
    if grep -Fxq "$copied_dep" "$processed_file"; then
      should_enqueue="false"
    else
      for item in "${queue[@]+"${queue[@]}"}"; do
        if [[ "$item" == "$copied_dep" ]]; then
          should_enqueue="false"
          break
        fi
      done
    fi
    if [[ "$should_enqueue" == "true" ]]; then
      queue+=("$copied_dep")
    fi
  done < <(list_deps "$binary")
done

rm -f "$processed_file"
echo "Bundled ffmpeg dependencies into $LIB_DIR"
