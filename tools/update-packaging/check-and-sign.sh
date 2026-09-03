#!/bin/bash
# check-and-sign.sh — Fully automated CI-to-sign-to-publish pipeline for
# Top Dogs Mail. Polls GitHub Actions for new successful runs of
# build-patriotradioclub-windows.yml, and when a new one is found:
# downloads the installer artifact, builds an unsigned complete MAR,
# signs it with exactly ONE cert (real production rule — a MAR signed with
# both primary+secondary fails verification on every real client; see
# Top-Dogs-Mail-Project-Reference.md, "HARD GATE proof" section, 2026-09-03),
# generates the AUS update.xml manifest + release-notes.html, and drops
# everything into the outbox for the existing 5-minute push cron to pick up.
#
# Runs on iffprov01 via cron. Fully unattended — no human involvement by design.
#
# One-time setup required (not done by this script):
#   - GitHub PAT (read access to Actions on gmcdole/top-dogs-mail) saved at
#     ~/mar-signing/.github-token, chmod 600
#   - NSS DB passphrase saved at ~/mar-signing/.nssdb-passphrase, chmod 600
#   - jq, unzip, p7zip-full, gcc, g++, xz-utils, curl installed
#   - build-complete-mar.sh at ~/build-complete-mar.sh (executable)
#   - generate-release-notes.sh at ~/generate-release-notes.sh (executable)
#
# State: last successfully processed run ID tracked in
#   ~/mar-signing/last-processed-run.txt (create empty/absent for first run —
#   absent is treated as "nothing processed yet")

set -uo pipefail

REPO="gmcdole/top-dogs-mail"
WORKFLOW="build-patriotradioclub-windows.yml"
BRAND="patriot-radio-club"
MAR_CHANNEL_ID="topdogsmail-patriotradioclub-release"
NSSDB="$HOME/mar-signing/nssdb"
OUTBOX="$HOME/mar-signing/outbox/$BRAND"
LOG="$HOME/mar-signing/check-and-sign.log"
TOKEN_FILE="$HOME/mar-signing/.github-token"
PASS_FILE="$HOME/mar-signing/.nssdb-passphrase"
STATE_FILE="$HOME/mar-signing/last-processed-run.txt"
BUILD_SCRIPT="$HOME/build-complete-mar.sh"
RELNOTES_SCRIPT="$HOME/generate-release-notes.sh"
SIGNMAR="$HOME/mar-build/src/signmar"

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ): $*" >> "$LOG"; }

log "=== check-and-sign run starting ==="

if [ ! -f "$TOKEN_FILE" ]; then
  log "ERROR: $TOKEN_FILE missing — cannot query GitHub API. Exiting."
  exit 1
fi
TOKEN="$(cat "$TOKEN_FILE")"

if [ ! -f "$PASS_FILE" ]; then
  log "ERROR: $PASS_FILE missing — cannot sign. Exiting."
  exit 1
fi

LAST_PROCESSED="0"
[ -f "$STATE_FILE" ] && LAST_PROCESSED="$(cat "$STATE_FILE")"

RUNS_JSON="$(curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/actions/workflows/$WORKFLOW/runs?status=success&per_page=1")"

LATEST_RUN_ID="$(echo "$RUNS_JSON" | jq -r '.workflow_runs[0].id // empty')"

if [ -z "$LATEST_RUN_ID" ]; then
  log "No successful runs found (or API error). Response snippet: $(echo "$RUNS_JSON" | head -c 500)"
  exit 0
fi

if [ "$LATEST_RUN_ID" = "$LAST_PROCESSED" ]; then
  log "Latest successful run ($LATEST_RUN_ID) already processed. Nothing to do."
  exit 0
fi

log "New run found: $LATEST_RUN_ID (last processed: $LAST_PROCESSED)"

ARTIFACTS_JSON="$(curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/actions/runs/$LATEST_RUN_ID/artifacts")"

ARTIFACT_ID="$(echo "$ARTIFACTS_JSON" | jq -r '.artifacts[] | select(.name | test("installer$")) | .id' | head -1)"
ARTIFACT_NAME="$(echo "$ARTIFACTS_JSON" | jq -r '.artifacts[] | select(.name | test("installer$")) | .name' | head -1)"

if [ -z "$ARTIFACT_ID" ]; then
  log "ERROR: no installer artifact found for run $LATEST_RUN_ID. Response snippet: $(echo "$ARTIFACTS_JSON" | head -c 500)"
  exit 1
fi

log "Found artifact: $ARTIFACT_NAME (id $ARTIFACT_ID)"

WORK="$(mktemp -d /tmp/check-and-sign.XXXXXX)"
cd "$WORK"

curl -sL -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
  -o artifact.zip \
  "https://api.github.com/repos/$REPO/actions/artifacts/$ARTIFACT_ID/zip"

if [ ! -s artifact.zip ]; then
  log "ERROR: artifact download failed or empty for run $LATEST_RUN_ID."
  rm -rf "$WORK"
  exit 1
fi

unzip -q artifact.zip
INSTALLER_EXE="$(find . -maxdepth 1 -iname '*.exe' | head -1)"
if [ -z "$INSTALLER_EXE" ]; then
  log "ERROR: no .exe found inside artifact zip for run $LATEST_RUN_ID."
  rm -rf "$WORK"
  exit 1
fi

VERSION="$(basename "$INSTALLER_EXE" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
if [ -z "$VERSION" ]; then
  log "ERROR: could not parse version from filename $INSTALLER_EXE (run $LATEST_RUN_ID)."
  rm -rf "$WORK"
  exit 1
fi

log "Parsed version: $VERSION from $(basename "$INSTALLER_EXE")"

OUTPUT_MAR="$WORK/topdogsmail-complete.mar"
BUILD_OUTPUT="$("$BUILD_SCRIPT" "$INSTALLER_EXE" "$VERSION" "$MAR_CHANNEL_ID" "$OUTPUT_MAR" 2>&1)"
BUILD_RC=$?
echo "$BUILD_OUTPUT" >> "$LOG"

if [ $BUILD_RC -ne 0 ] || [ ! -f "$OUTPUT_MAR" ]; then
  log "ERROR: build-complete-mar.sh failed (rc=$BUILD_RC) for run $LATEST_RUN_ID."
  rm -rf "$WORK"
  exit 1
fi

BUILD_ID="$(echo "$BUILD_OUTPUT" | grep -m1 '^BUILD_ID=' | cut -d= -f2)"
if [ -z "$BUILD_ID" ]; then
  log "ERROR: could not extract BuildID from build-complete-mar.sh output for run $LATEST_RUN_ID."
  rm -rf "$WORK"
  exit 1
fi

log "Real BuildID: $BUILD_ID"

SIGNED_MAR="$WORK/topdogsmail-complete.signed.mar"
# Exactly ONE cert (-n patriotradioclub-release only) — never add the
# secondary cert here. See header comment for why.
"$SIGNMAR" -d "$NSSDB" -n patriotradioclub-release -s "$OUTPUT_MAR" "$SIGNED_MAR" < "$PASS_FILE" >> "$LOG" 2>&1

if [ ! -f "$SIGNED_MAR" ]; then
  log "ERROR: signing failed for run $LATEST_RUN_ID (output MAR not created)."
  rm -rf "$WORK"
  exit 1
fi

SIG_CHECK="$("$SIGNMAR" -d "$NSSDB" -T "$SIGNED_MAR" 2>&1 | head -1)"
log "Verification: $SIG_CHECK"
if [[ "$SIG_CHECK" != *"1 signature"* ]]; then
  log "ERROR: signed MAR does not show exactly 1 signature ($SIG_CHECK) — refusing to publish run $LATEST_RUN_ID."
  rm -rf "$WORK"
  exit 1
fi

MAR_SIZE="$(stat -c%s "$SIGNED_MAR")"
MAR_SHA256="$(sha256sum "$SIGNED_MAR" | cut -d' ' -f1)"
log "Signed MAR: $MAR_SIZE bytes, sha256 $MAR_SHA256"

VERSION_DIR="$OUTBOX/$VERSION"
mkdir -p "$VERSION_DIR"
FINAL_MAR_NAME="topdogsmail-complete.signed.mar"
cp "$SIGNED_MAR" "$VERSION_DIR/$FINAL_MAR_NAME"

"$RELNOTES_SCRIPT" "$VERSION" "$OUTBOX/release-notes.html" >> "$LOG" 2>&1

cat > "$OUTBOX/update.xml" << XMLEOF
<?xml version="1.0"?>
<updates>
    <update type="minor" appVersion="$VERSION" buildID="$BUILD_ID" isCompleteUpdate="true" detailsURL="https://updates.topdogs.dev/mail/$BRAND/release-notes.html">
        <patch type="complete" URL="https://updates.topdogs.dev/mail/$BRAND/$VERSION/$FINAL_MAR_NAME" size="$MAR_SIZE"/>
    </update>
</updates>
XMLEOF

touch "$VERSION_DIR/.ready"
echo "$LATEST_RUN_ID" > "$STATE_FILE"

log "SUCCESS: run $LATEST_RUN_ID (version $VERSION, BuildID $BUILD_ID) published to outbox. Will go live on the next push cron (within 5 min)."

rm -rf "$WORK"
log "=== check-and-sign run finished ==="
