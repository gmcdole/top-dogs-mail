#!/bin/bash
# generate-release-notes.sh — Generate a minimal, generic, version-stamped
# release-notes page for Top Dogs Mail.
#
# By Gene's explicit decision (2026-09-03): no human writing required, ever.
# This intentionally does NOT parse git history or commit messages — this
# repo's commits are internal build/infra messages, not user-facing copy,
# and Gene does not want to be involved in writing release notes per
# release. If a future team member wants to hand-write real release notes,
# this script (or the page it produces) is the place to change that; until
# then it just fills in the version number and build date automatically.
#
# Usage:
#   ./generate-release-notes.sh <version> <output.html>
#
# Example:
#   ./generate-release-notes.sh 153.2.1 release-notes.html

set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <version> <output.html>" >&2
  exit 1
fi

VERSION="$1"
OUTPUT="$2"
BUILD_DATE="$(date -u +"%B %-d, %Y")"

cat > "$OUTPUT" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Top Dogs Mail ${VERSION} — Release Notes</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; max-width: 640px; margin: 3rem auto; padding: 0 1.5rem; color: #1a1a1a; line-height: 1.6; }
  h1 { font-size: 1.4rem; margin-bottom: 0.25rem; }
  .meta { color: #666; font-size: 0.9rem; margin-bottom: 1.5rem; }
  p { margin: 0.5rem 0; }
</style>
</head>
<body>
<h1>Top Dogs Mail ${VERSION}</h1>
<p class="meta">Released ${BUILD_DATE}</p>
<p>General improvements and bug fixes.</p>
</body>
</html>
HTMLEOF

echo "Wrote $OUTPUT"
