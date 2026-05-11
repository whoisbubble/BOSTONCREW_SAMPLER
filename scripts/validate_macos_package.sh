#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

ARCHIVE_PATH="${ARCHIVE_PATH:-}"
DMG_PATH="${DMG_PATH:-}"
EXPECTED_ARCH="${EXPECTED_ARCH:-}"
APP_BUNDLE_NAME="${APP_BUNDLE_NAME:-BOSTONCREW SAMPLER.app}"
APP_EXECUTABLE_NAME="${APP_EXECUTABLE_NAME:-BOSTONCREW SAMPLER}"

resolve_path() {
    local input="$1"
    case "$input" in
        /*) printf '%s\n' "$input" ;;
        *) printf '%s/%s\n' "$PROJECT_ROOT" "$input" ;;
    esac
}

require_arch() {
    local binary="$1"
    local expected="$2"
    local archs
    archs="$(lipo -archs "$binary")"
    echo "$binary: $archs"
    if ! printf '%s\n' "$archs" | tr ' ' '\n' | grep -Fxq "$expected"; then
        echo "Expected architecture $expected was not found in $binary" >&2
        exit 1
    fi
}

if [ -z "$ARCHIVE_PATH" ] && [ -z "$DMG_PATH" ]; then
    echo "Set ARCHIVE_PATH or DMG_PATH." >&2
    exit 1
fi

WORK_DIR="${RUNNER_TEMP:-/tmp}/bostoncrew-macos-validate-$$"
MOUNT_DIR="$WORK_DIR/mount"
ZIP_DIR="$WORK_DIR/zip"
mkdir -p "$MOUNT_DIR" "$ZIP_DIR"

cleanup() {
    hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 || true
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if [ -n "$ARCHIVE_PATH" ]; then
    ARCHIVE_FULL_PATH="$(resolve_path "$ARCHIVE_PATH")"
    unzip -t "$ARCHIVE_FULL_PATH"
    ditto -x -k "$ARCHIVE_FULL_PATH" "$ZIP_DIR"
    DMG_FULL_PATH="$(find "$ZIP_DIR" -maxdepth 2 -type f -name '*.dmg' | sort | head -n 1)"
else
    DMG_FULL_PATH="$(resolve_path "$DMG_PATH")"
fi

if [ -z "$DMG_FULL_PATH" ] || [ ! -f "$DMG_FULL_PATH" ]; then
    echo "DMG was not found." >&2
    exit 1
fi

hdiutil verify "$DMG_FULL_PATH"
hdiutil attach "$DMG_FULL_PATH" -mountpoint "$MOUNT_DIR" -nobrowse -readonly

APP_PATH="$MOUNT_DIR/$APP_BUNDLE_NAME"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/$APP_EXECUTABLE_NAME"
FFMPEG_PATH="$APP_PATH/Contents/MacOS/ffmpeg/ffmpeg"
FFPROBE_PATH="$APP_PATH/Contents/MacOS/ffmpeg/ffprobe"

test -d "$APP_PATH"
test -x "$EXECUTABLE_PATH"
test -x "$FFMPEG_PATH"
test -x "$FFPROBE_PATH"

if [ -n "$EXPECTED_ARCH" ]; then
    require_arch "$EXECUTABLE_PATH" "$EXPECTED_ARCH"
    require_arch "$FFMPEG_PATH" "$EXPECTED_ARCH"
    require_arch "$FFPROBE_PATH" "$EXPECTED_ARCH"
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
"$FFMPEG_PATH" -version
"$FFPROBE_PATH" -version

DEPENDENCIES="$(otool -L "$EXECUTABLE_PATH" | tail -n +2 | awk '{print $1}')"
if printf '%s\n' "$DEPENDENCIES" | grep -E "^(/Users/runner|/opt/homebrew|/usr/local/Cellar|/Users/.*/Qt|/opt/Qt|/usr/local/Qt)" >/dev/null; then
    printf '%s\n' "$DEPENDENCIES"
    echo "The app executable still references build-machine dependency paths." >&2
    exit 1
fi

echo "macOS package validation passed: $DMG_FULL_PATH"
