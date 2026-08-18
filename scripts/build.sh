#!/bin/bash
# Builds Mani.app and signs it ad hoc — no Apple Developer account required.
#
#   scripts/build.sh              build into ./build/Mani.app
#   scripts/build.sh --install    build, then copy into /Applications
#   scripts/build.sh --test       run the unit tests instead of building the app
set -euo pipefail

cd "$(dirname "$0")/.."

pkill -x Mani 2>/dev/null || true

CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA="${DERIVED_DATA:-.derived}"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
# Ad hoc by default; override to sign with your own identity, e.g.
#   CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" scripts/build.sh
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"
install=false
test_only=false

for arg in "$@"; do
    case "$arg" in
        --install) install=true ;;
        --test) test_only=true ;;
        *) echo "usage: $0 [--install] [--test]" >&2; exit 64 ;;
    esac
done

if ! xcodebuild -version >/dev/null 2>&1; then
    echo "xcodebuild is unavailable. Install Xcode from the App Store, then run:" >&2
    echo "  sudo xcode-select --switch /Applications/Xcode.app" >&2
    exit 1
fi

paths=(
    SYMROOT="$PWD/$DERIVED_DATA"
    OBJROOT="$PWD/$DERIVED_DATA/Intermediates"
    CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY"
    CODE_SIGN_STYLE=Manual
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"
)

if $test_only; then
    exec xcodebuild -project Mani.xcodeproj -scheme Mani -configuration Debug "${paths[@]}" test
fi

xcodebuild \
    -project Mani.xcodeproj \
    -target Mani \
    -configuration "$CONFIGURATION" \
    "${paths[@]}" \
    build

built="$DERIVED_DATA/$CONFIGURATION/Mani.app"
rm -rf build/Mani.app
mkdir -p build
cp -R "$built" build/

if $install; then
    rm -rf "$INSTALL_DIR/Mani.app"
    cp -R build/Mani.app "$INSTALL_DIR/"
    echo "Installed $INSTALL_DIR/Mani.app"
else
    echo "Built build/Mani.app — drag it to /Applications, or rerun with --install."
fi
