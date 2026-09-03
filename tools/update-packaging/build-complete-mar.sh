#!/bin/bash
# build-complete-mar.sh — Build an UNSIGNED complete MAR from a Top Dogs Mail
# Windows installer .exe (the NSIS installer artifact GitHub Actions produces).
#
# Written 2026-09-02/03 during the Top Dogs Mail auto-update loopback test.
# Validated end to end against Run #29's real installer in a throwaway build
# of the same tools this script re-derives (see Top-Dogs-Mail-Project-Reference.md,
# "Real signed MAR built and verified" section, for the full write-up and the
# reasoning behind each step).
#
# Intended to run ON iffprov01 (has gcc/g++, network access, and is already
# where signmar/the real certs live) — NOT in a throwaway cloud sandbox. This
# avoids the chunked SendUserFile transfer dance the first loopback test needed:
# scp the installer .exe to iffprov01, run this script there, then sign the
# output in place with the existing ~/mar-build/src/signmar.
#
# Usage:
#   ./build-complete-mar.sh <installer.exe> <version> <mar-channel-id> <output.mar>
#
# Example (matches the locked Patriot Radio Club identifiers):
#   ./build-complete-mar.sh topdogsmail-153.2.0.en-US.win64.installer.exe \
#       153.2.0 topdogsmail-patriotradioclub-release run30-topdogsmail-complete.mar
#
# Requires: p7zip-full (for extracting the NSIS installer payload), gcc, g++,
# curl, xz-utils. On a fresh iffprov01-like Ubuntu box:
#   sudo apt-get install -y p7zip-full build-essential curl xz-utils
#
# Safe to re-run: everything happens in a fresh temp working directory.

set -euo pipefail

if [ $# -ne 4 ]; then
  echo "Usage: $0 <installer.exe> <version> <mar-channel-id> <output.mar>" >&2
  exit 1
fi

INSTALLER_EXE="$(readlink -f "$1")"
VERSION="$2"
MAR_CHANNEL_ID="$3"
OUTPUT_MAR="$(readlink -f "$4" 2>/dev/null || echo "$PWD/$4")"
ESR_BRANCH="esr153"   # bump this if/when the CI pin moves to a newer ESR line

if [ ! -f "$INSTALLER_EXE" ]; then
  echo "ERROR: installer not found: $INSTALLER_EXE" >&2
  exit 1
fi

WORK="$(mktemp -d /tmp/mar-build.XXXXXX)"
echo "Working in $WORK"
cd "$WORK"

echo "--- Extracting installer payload with 7z ---"
7z x "$INSTALLER_EXE" -o./extracted -y > 7z-extract.log 2>&1
if [ ! -d extracted/core ]; then
  echo "ERROR: extracted/core not found — installer layout may have changed. See $WORK/7z-extract.log" >&2
  exit 1
fi
mv extracted/core tree
for f in precomplete removed-files update-settings.ini updater.exe updater.ini; do
  if [ ! -e "tree/$f" ]; then
    echo "WARNING: expected file tree/$f not found — updater may not be enabled in this build" >&2
  fi
done

echo "--- Fetching Mozilla libmar + CityHash source ($ESR_BRANCH) ---"
mkdir -p src/modules/libmar/src src/modules/libmar/tool
mkdir -p src/other-licenses/nsis/Contrib/CityHash/cityhash
BASE="https://raw.githubusercontent.com/mozilla-firefox/firefox/$ESR_BRANCH"
for f in modules/libmar/src/mar.h modules/libmar/src/mar_create.c \
         modules/libmar/src/mar_read.c modules/libmar/src/mar_extract.c \
         modules/libmar/src/mar_private.h modules/libmar/src/mar_cmdline.h \
         modules/libmar/tool/mar.c \
         other-licenses/nsis/Contrib/CityHash/cityhash/city.h \
         other-licenses/nsis/Contrib/CityHash/cityhash/city.cpp; do
  mkdir -p "src/$(dirname "$f")"
  code=$(curl -sL -o "src/$f" -w "%{http_code}" "$BASE/$f")
  if [ "$code" != "200" ]; then
    echo "ERROR: failed to fetch $f (HTTP $code) — upstream layout may have moved" >&2
    exit 1
  fi
done

echo "--- Fetching update-packaging scripts ($ESR_BRANCH) ---"
for f in tools/update-packaging/make_full_update.sh tools/update-packaging/common.sh; do
  code=$(curl -sL -o "$(basename "$f")" -w "%{http_code}" "$BASE/$f")
  if [ "$code" != "200" ]; then
    echo "ERROR: failed to fetch $f (HTTP $code)" >&2
    exit 1
  fi
done
chmod +x make_full_update.sh

echo "--- Building plain 'mar' tool (create-only, no NSS needed) ---"
cd src
gcc -c -DNO_SIGN_VERIFY -DMOZ_APP_VERSION="\"$VERSION\"" -DMAR_CHANNEL_ID="\"$MAR_CHANNEL_ID\"" \
  -Imodules/libmar/src -Iother-licenses/nsis/Contrib/CityHash/cityhash \
  modules/libmar/tool/mar.c -o /tmp/mar_tool.o
gcc -c -DNO_SIGN_VERIFY -Imodules/libmar/src -Iother-licenses/nsis/Contrib/CityHash/cityhash \
  modules/libmar/src/mar_create.c -o /tmp/mar_create.o
gcc -c -DNO_SIGN_VERIFY -Imodules/libmar/src -Iother-licenses/nsis/Contrib/CityHash/cityhash \
  modules/libmar/src/mar_read.c -o /tmp/mar_read.o
gcc -c -DNO_SIGN_VERIFY -Imodules/libmar/src -Iother-licenses/nsis/Contrib/CityHash/cityhash \
  modules/libmar/src/mar_extract.c -o /tmp/mar_extract.o
g++ -c -Iother-licenses/nsis/Contrib/CityHash/cityhash \
  other-licenses/nsis/Contrib/CityHash/cityhash/city.cpp -o /tmp/mar_city.o
g++ -o "$WORK/mar" /tmp/mar_tool.o /tmp/mar_create.o /tmp/mar_read.o /tmp/mar_extract.o /tmp/mar_city.o
cd "$WORK"
echo "Built $WORK/mar:"
./mar 2>&1 | head -3 || true

echo "--- Running make_full_update.sh (this compresses ~350MB with xz -T1 -7e; can take 3-6 minutes) ---"
export MAR="$WORK/mar"
export MOZ_PRODUCT_VERSION="$VERSION"
export MAR_CHANNEL_ID="$MAR_CHANNEL_ID"
bash make_full_update.sh "$WORK/unsigned.mar" tree

mv "$WORK/unsigned.mar" "$OUTPUT_MAR"
echo ""
echo "--- Done ---"
echo "Unsigned complete MAR: $OUTPUT_MAR"
sha256sum "$OUTPUT_MAR"
"$WORK/mar" -t "$OUTPUT_MAR" | wc -l

# Surface the real BuildID from the extracted application.ini, needed for the
# AUS update.xml manifest. Read here (before cleanup) rather than making a
# caller do a second extraction of the same installer.
# Added 2026-09-03 alongside the CI-to-sign automation work.
if [ -f "$WORK/tree/application.ini" ]; then
  REAL_BUILD_ID="$(grep -m1 '^BuildID=' "$WORK/tree/application.ini" | cut -d= -f2)"
  REAL_VERSION="$(grep -m1 '^Version=' "$WORK/tree/application.ini" | cut -d= -f2)"
  echo ""
  echo "BUILD_ID=$REAL_BUILD_ID"
  echo "INI_VERSION=$REAL_VERSION"
  if [ -n "$REAL_VERSION" ] && [ "$REAL_VERSION" != "$VERSION" ]; then
    echo "WARNING: version passed on the command line ($VERSION) does not match application.ini's own Version ($REAL_VERSION) — double check which is correct." >&2
  fi
else
  echo "WARNING: tree/application.ini not found — could not read real BuildID." >&2
fi

echo ""
echo "Next: sign it with exactly ONE cert (never both primary and secondary at"
echo "once — a MAR signed with 2 certs fails verification on every real client,"
echo "see Top-Dogs-Mail-Project-Reference.md, \"HARD GATE proof\" section, 2026-09-03):"
echo "  ~/mar-build/src/signmar -d ~/mar-signing/nssdb -n patriotradioclub-release -s \"$OUTPUT_MAR\" \"${OUTPUT_MAR%.mar}.signed.mar\""
echo ""
echo "Cleaning up working directory $WORK (the tree/ extraction and fetched source are disposable; only $OUTPUT_MAR matters going forward)"
rm -rf "$WORK"
