#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
PROJECT_CANONICAL="$(cd "$PROJECT_ROOT" && pwd -P)"

BUILD_DIR="${BUILD_DIR:-build-macos}"
OUTPUT_DIR="${OUTPUT_DIR:-deploy/macos}"
CONFIGURATION="${CONFIGURATION:-Release}"
QT_BIN_DIR="${QT_BIN_DIR:-}"
CACHE_DIR="${CACHE_DIR:-deploy/.cache/macos}"
PACKAGE_ARCH="${PACKAGE_ARCH:-macos}"
ARCHIVE_PATH="${ARCHIVE_PATH:-deploy/BOSTONCREW-SAMPLER-macos.zip}"
DMG_PATH="${DMG_PATH:-deploy/BOSTONCREW-SAMPLER-${PACKAGE_ARCH}.dmg}"
APP_BUNDLE_NAME="${APP_BUNDLE_NAME:-BOSTONCREW SAMPLER.app}"
DMG_VOLUME_NAME="${DMG_VOLUME_NAME:-BOSTONCREW SAMPLER}"
CMAKE_OSX_DEPLOYMENT_TARGET="${CMAKE_OSX_DEPLOYMENT_TARGET:-13.0}"
CMAKE_OSX_ARCHITECTURES="${CMAKE_OSX_ARCHITECTURES:-x86_64}"
FFMPEG_DIR="${FFMPEG_DIR:-}"
FFMPEG_ARCH="${FFMPEG_ARCH:-auto}"
FFMPEG_CHANNEL="${FFMPEG_CHANNEL:-release}"
FFMPEG_BASE_URL="${FFMPEG_BASE_URL:-https://ffmpeg.martin-riedl.de/redirect/latest/macos}"
FFMPEG_URL="${FFMPEG_URL:-}"
FFPROBE_URL="${FFPROBE_URL:-}"
SKIP_FFMPEG="${SKIP_FFMPEG:-0}"
NO_ARCHIVE="${NO_ARCHIVE:-0}"
RUN_TESTS="${RUN_TESTS:-1}"
MACOS_CODESIGN_IDENTITY="${MACOS_CODESIGN_IDENTITY:-}"
MACOS_DMG_CODESIGN_IDENTITY="${MACOS_DMG_CODESIGN_IDENTITY:-$MACOS_CODESIGN_IDENTITY}"
MACOS_ENTITLEMENTS="${MACOS_ENTITLEMENTS:-$PROJECT_ROOT/cmake/macos-entitlements.plist}"
MACOS_NOTARIZE="${MACOS_NOTARIZE:-auto}"
APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APPLE_APP_SPECIFIC_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-}"

resolve_target_path() {
    local input="$1"
    local target
    case "$input" in
        /*) target="$input" ;;
        *) target="$PROJECT_ROOT/$input" ;;
    esac

    local parent
    parent="$(dirname "$target")"
    mkdir -p "$parent"

    local parent_real
    parent_real="$(cd "$parent" && pwd -P)"
    printf '%s/%s\n' "$parent_real" "$(basename "$target")"
}

ensure_under_project() {
    local path="$1"
    local label="$2"
    case "$path" in
        "$PROJECT_CANONICAL"|"$PROJECT_CANONICAL"/*) ;;
        *)
            echo "$label must be inside the project folder: $path" >&2
            exit 1
            ;;
    esac
}

prepend_path() {
    local path="$1"
    if [ -n "$path" ] && [ -d "$path" ]; then
        export PATH="$path:$PATH"
    fi
}

find_tool() {
    local tool="$1"
    if [ -n "$QT_BIN_DIR" ] && [ -x "$QT_BIN_DIR/$tool" ]; then
        printf '%s\n' "$QT_BIN_DIR/$tool"
        return 0
    fi

    if command -v "$tool" >/dev/null 2>&1; then
        command -v "$tool"
        return 0
    fi

    local cache_file="$BUILD_PATH/CMakeCache.txt"
    if [ -f "$cache_file" ]; then
        local qt_dir
        qt_dir="$(awk -F= '/^Qt6_DIR:PATH=/{print $2; exit}' "$cache_file")"
        if [ -n "$qt_dir" ] && [ -x "$qt_dir/../../bin/$tool" ]; then
            (cd "$qt_dir/../../bin" && printf '%s/%s\n' "$(pwd -P)" "$tool")
            return 0
        fi
    fi

    return 1
}

generate_macos_icon() {
    local source_icon="$PROJECT_ROOT/assets/app_icon.png"
    local icon_target="$BUILD_PATH/generated/app_icon.icns"
    local iconset="$BUILD_PATH/generated/AppIcon.iconset"

    if [ ! -f "$source_icon" ] || ! command -v sips >/dev/null 2>&1 || ! command -v iconutil >/dev/null 2>&1; then
        return 0
    fi

    rm -rf "$iconset"
    mkdir -p "$iconset"

    for size in 16 32 128 256 512; do
        sips -z "$size" "$size" "$source_icon" --out "$iconset/icon_${size}x${size}.png" >/dev/null
        local double_size=$((size * 2))
        sips -z "$double_size" "$double_size" "$source_icon" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
    done

    iconutil -c icns "$iconset" -o "$icon_target"
    printf '%s\n' "$icon_target"
}

find_built_app() {
    local candidates=(
        "$BUILD_PATH/BOSTONCREW-SAMPLER.app"
        "$BUILD_PATH/BOSTONCREW SAMPLER.app"
        "$BUILD_PATH/appCPlusEventSampler.app"
    )

    for candidate in "${candidates[@]}"; do
        if [ -d "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    find "$BUILD_PATH" -maxdepth 2 -type d -name '*.app' | sort | head -n 1
}

find_file_in_dir() {
    local root="$1"
    local filename="$2"
    if [ -z "$root" ] || [ ! -d "$root" ]; then
        return 1
    fi
    if [ -f "$root/$filename" ]; then
        printf '%s\n' "$root/$filename"
        return 0
    fi
    find "$root" -type f -name "$filename" | sort | head -n 1
}

download_if_missing() {
    local url="$1"
    local destination="$2"
    if [ -f "$destination" ]; then
        return 0
    fi
    echo "Downloading $url" >&2
    curl --fail --location --retry 3 --output "$destination" "$url"
}

effective_ffmpeg_arch() {
    if [ "$FFMPEG_ARCH" != "auto" ]; then
        printf '%s\n' "$FFMPEG_ARCH"
        return 0
    fi

    case "$CMAKE_OSX_ARCHITECTURES" in
        arm64) printf '%s\n' "arm64" ;;
        x86_64) printf '%s\n' "amd64" ;;
        *)
            echo "Set FFMPEG_ARCH to amd64 or arm64 for CMAKE_OSX_ARCHITECTURES=$CMAKE_OSX_ARCHITECTURES." >&2
            exit 1
            ;;
    esac
}

resolve_ffmpeg_tools() {
    local ffmpeg=""
    local ffprobe=""

    if [ -n "$FFMPEG_DIR" ]; then
        ffmpeg="$(find_file_in_dir "$FFMPEG_DIR" ffmpeg || true)"
        ffprobe="$(find_file_in_dir "$FFMPEG_DIR" ffprobe || true)"
        if [ -z "$ffmpeg" ] || [ -z "$ffprobe" ]; then
            echo "ffmpeg and ffprobe were not found in FFMPEG_DIR: $FFMPEG_DIR" >&2
            exit 1
        fi
    else
        local download_arch
        download_arch="$(effective_ffmpeg_arch)"
        local ffmpeg_url="${FFMPEG_URL:-$FFMPEG_BASE_URL/$download_arch/$FFMPEG_CHANNEL/ffmpeg.zip}"
        local ffprobe_url="${FFPROBE_URL:-$FFMPEG_BASE_URL/$download_arch/$FFMPEG_CHANNEL/ffprobe.zip}"
        local ffmpeg_zip="$CACHE_PATH/ffmpeg-$download_arch.zip"
        local ffprobe_zip="$CACHE_PATH/ffprobe-$download_arch.zip"
        local extract_path="$CACHE_PATH/ffmpeg-$download_arch"

        mkdir -p "$CACHE_PATH"
        download_if_missing "$ffmpeg_url" "$ffmpeg_zip"
        download_if_missing "$ffprobe_url" "$ffprobe_zip"

        rm -rf "$extract_path"
        mkdir -p "$extract_path/ffmpeg" "$extract_path/ffprobe"
        unzip -q "$ffmpeg_zip" -d "$extract_path/ffmpeg"
        unzip -q "$ffprobe_zip" -d "$extract_path/ffprobe"

        ffmpeg="$(find_file_in_dir "$extract_path/ffmpeg" ffmpeg || true)"
        ffprobe="$(find_file_in_dir "$extract_path/ffprobe" ffprobe || true)"
        if [ -z "$ffmpeg" ] || [ -z "$ffprobe" ]; then
            echo "Downloaded FFmpeg archives do not contain ffmpeg and ffprobe." >&2
            exit 1
        fi
    fi

    printf '%s\n%s\n' "$ffmpeg" "$ffprobe"
}

copy_ffmpeg_to_app() {
    local app_path="$1"
    local tools
    tools="$(resolve_ffmpeg_tools)"
    local ffmpeg_tool
    local ffprobe_tool
    ffmpeg_tool="$(printf '%s\n' "$tools" | sed -n '1p')"
    ffprobe_tool="$(printf '%s\n' "$tools" | sed -n '2p')"

    local target_dir="$app_path/Contents/MacOS/ffmpeg"
    mkdir -p "$target_dir"
    cp "$ffmpeg_tool" "$target_dir/ffmpeg"
    cp "$ffprobe_tool" "$target_dir/ffprobe"
    chmod +x "$target_dir/ffmpeg" "$target_dir/ffprobe"
}

require_notarization_inputs() {
    if [ "$MACOS_NOTARIZE" != "1" ]; then
        return 0
    fi

    local missing=0
    for name in MACOS_CODESIGN_IDENTITY APPLE_ID APPLE_TEAM_ID APPLE_APP_SPECIFIC_PASSWORD; do
        if [ -z "${!name:-}" ]; then
            echo "$name is required when MACOS_NOTARIZE=1." >&2
            missing=1
        fi
    done

    if [ "$missing" != "0" ]; then
        exit 1
    fi
}

sign_app() {
    local app_path="$1"
    if ! command -v codesign >/dev/null 2>&1; then
        return 0
    fi

    if [ -n "$MACOS_CODESIGN_IDENTITY" ]; then
        local sign_args=(
            --force
            --deep
            --options runtime
            --timestamp
            --sign "$MACOS_CODESIGN_IDENTITY"
        )
        if [ -f "$MACOS_ENTITLEMENTS" ]; then
            sign_args+=(--entitlements "$MACOS_ENTITLEMENTS")
        fi
        codesign "${sign_args[@]}" "$app_path"
    else
        codesign --force --deep --sign - "$app_path"
    fi
}

sign_dmg() {
    local dmg_path="$1"
    if [ -z "$MACOS_DMG_CODESIGN_IDENTITY" ] || ! command -v codesign >/dev/null 2>&1; then
        return 0
    fi

    codesign --force --timestamp --sign "$MACOS_DMG_CODESIGN_IDENTITY" "$dmg_path"
}

notarization_enabled() {
    if [ "$MACOS_NOTARIZE" = "1" ]; then
        return 0
    fi
    if [ "$MACOS_NOTARIZE" = "0" ]; then
        return 1
    fi

    [ -n "$APPLE_ID" ] \
        && [ -n "$APPLE_TEAM_ID" ] \
        && [ -n "$APPLE_APP_SPECIFIC_PASSWORD" ] \
        && [ -n "$MACOS_CODESIGN_IDENTITY" ]
}

notarize_dmg() {
    local dmg_path="$1"
    if ! notarization_enabled; then
        echo "Notarization skipped. Set Apple Developer ID secrets for public macOS distribution."
        return 0
    fi

    if [ -z "$APPLE_ID" ] || [ -z "$APPLE_TEAM_ID" ] || [ -z "$APPLE_APP_SPECIFIC_PASSWORD" ]; then
        echo "APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_SPECIFIC_PASSWORD are required for notarization." >&2
        exit 1
    fi

    if [ -z "$MACOS_CODESIGN_IDENTITY" ]; then
        echo "MACOS_CODESIGN_IDENTITY is required for notarization." >&2
        exit 1
    fi

    xcrun notarytool submit "$dmg_path" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_SPECIFIC_PASSWORD" \
        --wait
    xcrun stapler staple "$dmg_path"
    xcrun stapler validate "$dmg_path"
}

create_dmg() {
    local app_path="$1"
    local dmg_path="$2"
    local stage_path="$DEPLOY_PATH/dmg-stage"

    rm -rf "$stage_path"
    mkdir -p "$stage_path"
    ditto "$app_path" "$stage_path/$APP_BUNDLE_NAME"
    ln -s /Applications "$stage_path/Applications"

    mkdir -p "$(dirname "$dmg_path")"
    rm -f "$dmg_path"
    hdiutil create \
        -volname "$DMG_VOLUME_NAME" \
        -srcfolder "$stage_path" \
        -ov \
        -format UDZO \
        "$dmg_path"

    rm -rf "$stage_path"
}

BUILD_PATH="$(resolve_target_path "$BUILD_DIR")"
DEPLOY_PATH="$(resolve_target_path "$OUTPUT_DIR")"
CACHE_PATH="$(resolve_target_path "$CACHE_DIR")"
ARCHIVE_FULL_PATH="$(resolve_target_path "$ARCHIVE_PATH")"
DMG_FULL_PATH="$(resolve_target_path "$DMG_PATH")"

ensure_under_project "$BUILD_PATH" "BuildDir"
ensure_under_project "$DEPLOY_PATH" "OutputDir"
ensure_under_project "$CACHE_PATH" "CacheDir"
ensure_under_project "$ARCHIVE_FULL_PATH" "ArchivePath"
ensure_under_project "$DMG_FULL_PATH" "DmgPath"

prepend_path "$QT_BIN_DIR"
require_notarization_inputs

mkdir -p "$BUILD_PATH"
MACOS_ICON="$(generate_macos_icon || true)"

cmake_args=(
    -S "$PROJECT_ROOT"
    -B "$BUILD_PATH"
    "-DCMAKE_BUILD_TYPE=$CONFIGURATION"
    "-DCMAKE_OSX_DEPLOYMENT_TARGET=$CMAKE_OSX_DEPLOYMENT_TARGET"
    "-DCMAKE_OSX_ARCHITECTURES=$CMAKE_OSX_ARCHITECTURES"
)

if [ -n "$MACOS_ICON" ]; then
    cmake_args+=("-DMACOS_APP_ICON=$MACOS_ICON")
fi

cmake "${cmake_args[@]}"
cmake --build "$BUILD_PATH" --config "$CONFIGURATION" --parallel

if [ "$RUN_TESTS" != "0" ]; then
    ctest --test-dir "$BUILD_PATH" --build-config "$CONFIGURATION" --output-on-failure
fi

BUILT_APP="$(find_built_app)"
if [ -z "$BUILT_APP" ] || [ ! -d "$BUILT_APP" ]; then
    echo "Built .app bundle was not found under $BUILD_PATH" >&2
    exit 1
fi

MACDEPLOYQT="$(find_tool macdeployqt || true)"
if [ -z "$MACDEPLOYQT" ]; then
    echo "macdeployqt was not found. Add Qt bin to PATH or pass QT_BIN_DIR=/path/to/Qt/bin." >&2
    exit 1
fi

rm -rf "$DEPLOY_PATH"
mkdir -p "$DEPLOY_PATH"

DEPLOY_APP="$DEPLOY_PATH/$APP_BUNDLE_NAME"
ditto "$BUILT_APP" "$DEPLOY_APP"

"$MACDEPLOYQT" "$DEPLOY_APP" -qmldir="$PROJECT_ROOT" -always-overwrite -verbose=2

if [ "$SKIP_FFMPEG" != "1" ]; then
    copy_ffmpeg_to_app "$DEPLOY_APP"
fi

sign_app "$DEPLOY_APP"

create_dmg "$DEPLOY_APP" "$DMG_FULL_PATH"
sign_dmg "$DMG_FULL_PATH"
notarize_dmg "$DMG_FULL_PATH"

if [ "$NO_ARCHIVE" != "1" ]; then
    mkdir -p "$(dirname "$ARCHIVE_FULL_PATH")"
    rm -f "$ARCHIVE_FULL_PATH"
    (cd "$(dirname "$DMG_FULL_PATH")" && ditto -c -k --sequesterRsrc --keepParent "$(basename "$DMG_FULL_PATH")" "$ARCHIVE_FULL_PATH")
fi

echo
echo "Deployment is ready:"
echo "$DEPLOY_APP"
echo "DMG is ready:"
echo "$DMG_FULL_PATH"
if [ "$SKIP_FFMPEG" != "1" ]; then
    echo "FFmpeg bundled:"
    echo "$DEPLOY_APP/Contents/MacOS/ffmpeg"
fi
if [ "$NO_ARCHIVE" != "1" ]; then
    echo "Archive is ready:"
    echo "$ARCHIVE_FULL_PATH"
fi
