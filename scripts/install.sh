#!/usr/bin/env bash
# Signs an IPA with your own certificate and installs it on the iPhone plugged into this Mac.
#
#   scripts/install.sh out/Spotify-9.1.78-glass.ipa
#
# Put the certificate details in .signing.env (gitignored):
#   SIGN_P12=/path/to/cert.p12
#   SIGN_PROFILE=/path/to/profile.mobileprovision
#   SIGN_P12_PASSWORD=...
# WIFI=1 installs over Wi-Fi instead of USB (the phone must be paired for wireless sync).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$ROOT/.signing.env" ] && . "$ROOT/.signing.env"
cd "$ROOT"
: "${SIGN_P12:?set SIGN_P12 in .signing.env}" "${SIGN_PROFILE:?set SIGN_PROFILE in .signing.env}" "${SIGN_P12_PASSWORD:?set SIGN_P12_PASSWORD in .signing.env}"

IN="${1:?usage: $0 <ipa>}"
SIGNED="${IN%.ipa}-signed.ipa"

command -v zsign >/dev/null || { echo "missing zsign -> brew install zsign" >&2; exit 1; }
command -v ideviceinstaller >/dev/null || { echo "missing ideviceinstaller -> brew install ideviceinstaller" >&2; exit 1; }

# A profile with a fixed App ID (signing services) may only install when the bundle id equals that
# App ID. Try the IPA's own bundle id first; fall back to the App ID if iOS rejects the signature.
PROFILE_PLIST="$(mktemp)"
security cms -D -i "$SIGN_PROFILE" > "$PROFILE_PLIST" 2>/dev/null
APP_ID="$(plutil -extract Entitlements.application-identifier raw -o - "$PROFILE_PLIST" 2>/dev/null || true)"
rm -f "$PROFILE_PLIST"
APP_ID="${APP_ID#*.}"

sign() {  # sign [bundle id]
  echo "==> signing${1:+ as $1}"
  zsign -k "$SIGN_P12" -p "$SIGN_P12_PASSWORD" -m "$SIGN_PROFILE" ${1:+-b "$1"} -z 1 -o "$SIGNED" "$IN" >/dev/null
}

sign
echo "==> installing $SIGNED"
set +e
OUTPUT="$(ideviceinstaller ${WIFI:+-n} install "$SIGNED" 2>&1)"
STATUS=$?
set -e
echo "$OUTPUT" | tail -3
if [ $STATUS -ne 0 ] && [ -n "$APP_ID" ] && [ "$APP_ID" != "*" ] && echo "$OUTPUT" | grep -qiE "entitlement|application-identifier|signature|ApplicationVerificationFailed"; then
  echo "==> iOS rejected that bundle id with this profile, retrying as $APP_ID"
  sign "$APP_ID"
  ideviceinstaller ${WIFI:+-n} install "$SIGNED" 2>&1 | tail -3
elif [ $STATUS -ne 0 ]; then
  exit $STATUS
fi
