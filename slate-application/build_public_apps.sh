#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$APP_DIR/Slate.xcodeproj}"
CONFIGURATION="${CONFIGURATION:-Release}"
DESTINATION="${DESTINATION:-generic/platform=macOS}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$APP_DIR/build/PublicDerivedData}"
MODULE_CACHE_PATH="${MODULE_CACHE_PATH:-$APP_DIR/build/ModuleCache.noindex}"

fail() {
    printf "Error: %s\n" "$1" >&2
    exit "${2:-1}"
}

usage() {
    cat <<USAGE
Usage: $(basename "$0")

Builds the public Slate.app adapter and paneharness.app with the required
Release configuration. Products are written to build/Release.

Environment overrides:
  PROJECT_PATH=$PROJECT_PATH
  CONFIGURATION=$CONFIGURATION
  DESTINATION=$DESTINATION
  DERIVED_DATA_PATH=$DERIVED_DATA_PATH
  MODULE_CACHE_PATH=$MODULE_CACHE_PATH

The default destination is generic/platform=macOS, which avoids Xcode's toolbar
destination picker state.
USAGE
}

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    "")
        ;;
    *)
        usage >&2
        exit 64
        ;;
esac

[ -d "$PROJECT_PATH" ] || fail "missing Xcode project: $PROJECT_PATH" 66

required_runtime_artifacts=(
    "$APP_DIR/Runtime/libSlateRuntime.a"
    "$APP_DIR/Runtime/SlateValidationRuntime"
    "$APP_DIR/Runtime/SlatePackageRuntime"
    "$APP_DIR/Runtime/SlateTrackRuntime"
    "$APP_DIR/Runtime/SlateChapterRuntime"
    "$APP_DIR/Runtime/SlateReviewRuntime"
    "$APP_DIR/Runtime/SlateTimelineRuntime"
)

for artifact in "${required_runtime_artifacts[@]}"; do
    [ -e "$artifact" ] || fail "missing required runtime artifact: $artifact" 66
done

mkdir -p "$DERIVED_DATA_PATH" "$MODULE_CACHE_PATH"

build_scheme() {
    local scheme="$1"
    printf "Building %s %s...\n" "$scheme" "$CONFIGURATION"
    xcodebuild -project "$PROJECT_PATH" \
               -scheme "$scheme" \
               -configuration "$CONFIGURATION" \
               -derivedDataPath "$DERIVED_DATA_PATH" \
               -destination "$DESTINATION" \
               CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_PATH" \
               COMPILER_INDEX_STORE_ENABLE=NO \
               build
}

build_scheme Slate
build_scheme paneharness

printf "\nBuild products:\n"
printf "  %s\n" "$APP_DIR/build/$CONFIGURATION/Slate.app"
printf "  %s\n" "$APP_DIR/build/$CONFIGURATION/paneharness.app"
