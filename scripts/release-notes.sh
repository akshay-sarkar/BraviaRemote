#!/usr/bin/env bash
# Prints the GitHub release notes for a tag: that version's CHANGELOG.md section,
# install steps and a compare link to the previous release.
#
#   bash scripts/release-notes.sh v1.1.0
#   bash scripts/release-notes.sh v1.1.0 | gh release edit v1.1.0 --notes-file -
set -euo pipefail

TAG="${1:?usage: release-notes.sh vX.Y.Z}"
VERSION="${TAG#v}"
cd "$(dirname "$0")/.."

# Lines between "## [VERSION]" and the next "## [" heading.
SECTION=$(awk -v v="$VERSION" '
  /^## \[/ { if (found) exit; if (index($0, "## [" v "]") == 1) { found = 1; next } }
  found { print }
' CHANGELOG.md | sed -e '/./,$!d')   # drop leading blank lines

if [ -z "${SECTION//[[:space:]]/}" ]; then
  echo "warning: CHANGELOG.md has no section for $VERSION" >&2
  SECTION="_No changelog entry for this version._"
fi

ORIGIN=$(git remote get-url origin 2>/dev/null || true)
REPO="${GITHUB_REPOSITORY:-$(printf '%s' "$ORIGIN" | sed -E 's#.*github\.com[:/]##; s#\.git$##')}"
PREV=$(git describe --tags --abbrev=0 "${TAG}^" 2>/dev/null || true)

cat <<MD
${SECTION}

## Install

1. Download **BraviaRemote-unsigned.ipa** below.
2. Sideload it with [Sideloadly](https://sideloadly.io) or [AltStore](https://altstore.io) using your Apple ID.
3. Open the app, pick your BRAVIA and pair with the PIN or Pre-Shared Key.

> The IPA is unsigned. Your sideloading tool signs it with your own Apple ID.
MD

if [ -n "$PREV" ] && [ -n "$REPO" ]; then
  printf '\n**Full changelog:** https://github.com/%s/compare/%s...%s\n' "$REPO" "$PREV" "$TAG"
fi
