#!/usr/bin/env bash
# Builds the spotifyglass tweak and injects it (plus FLEX) into a decrypted Spotify IPA.
#
#   scripts/pipeline.sh <decrypted.ipa> [-o out.ipa] [--no-flex] [--install]   (or: make build / make install)
#
# --install hands the result to install.sh (sign with your certificate, push to the plugged-in iPhone).
#
# Needs: Theos in $THEOS (default ~/theos) with an iPhoneOS SDK in $THEOS/sdks,
# gmake, ldid, dpkg-deb (brew) and cyan (uv tool install "cyan @ git+https://github.com/asdfzxcvbn/pyzule-rw").
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEOS="${THEOS:-$HOME/theos}"
FLEX_DEB="$ROOT/vendor/com.hopeless.autoflex_0.0.1_iphoneos-arm.deb"
# Installs next to the real Spotify instead of replacing it. Override: BUNDLE_ID=com.spotify.client make build
BUNDLE_ID="${BUNDLE_ID:-com.spotify.client2}"

IN="" OUT="" WITH_FLEX=1 INSTALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    -o) OUT="$2"; shift 2 ;;
    --no-flex) WITH_FLEX=0; shift ;;
    --install) INSTALL=1; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) IN="$1"; shift ;;
  esac
done
[ -f "$IN" ] || { echo "usage: $0 <decrypted.ipa> [-o out.ipa] [--no-flex] [--install]" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing $1 -> $2" >&2; exit 1; }; }
need gmake "brew install make"
need ldid "brew install ldid"
need dpkg-deb "brew install dpkg"
need cyan "uv tool install 'cyan @ git+https://github.com/asdfzxcvbn/pyzule-rw'"
ls "$THEOS"/sdks/iPhoneOS*.sdk >/dev/null 2>&1 || { echo "no iPhoneOS SDK in $THEOS/sdks" >&2; exit 1; }

APP_DIR="$(unzip -Z1 "$IN" | grep -oE '^Payload/[^/]+\.app/' | head -1)"
[ -n "$APP_DIR" ] || { echo "no Payload/*.app in $IN" >&2; exit 1; }
VERSION="$(unzip -p "$IN" "${APP_DIR}Info.plist" > "$ROOT/out/.info.plist" && plutil -extract CFBundleShortVersionString raw -o - "$ROOT/out/.info.plist")"
rm -f "$ROOT/out/.info.plist"
OUT="${OUT:-$ROOT/out/Spotify-$VERSION-glass.ipa}"
echo "==> Spotify $VERSION -> $OUT"

echo "==> building tweak"
# No Xcode on this machine: Theos would resolve tools through `xcrun -sdk iphoneos`, so name the CLT ones directly.
export THEOS TARGET_CC=clang TARGET_CXX=clang++ TARGET_LD=clang++ \
       TARGET_STRIP=strip TARGET_LIPO=lipo TARGET_CODESIGN_ALLOCATE=codesign_allocate TARGET_LIBTOOL=libtool
gmake -C "$ROOT/tweak" clean package >/dev/null
TWEAK_DEB="$(ls -t "$ROOT"/tweak/packages/*.deb | head -1)"
echo "    $TWEAK_DEB"

FILES=("$TWEAK_DEB")
[ "$WITH_FLEX" = 1 ] && FILES+=("$FLEX_DEB")

echo "==> injecting"
# -w drops the Watch app: its companion-app key would still name com.spotify.client and block the install.
cyan -i "$IN" -o "$OUT" -f "${FILES[@]}" -l "$ROOT/plist/liquid-glass.plist" -b "$BUNDLE_ID" -w -s --overwrite

echo "==> done: $OUT"
[ "$INSTALL" = 1 ] && exec "$ROOT/scripts/install.sh" "$OUT"
exit 0
