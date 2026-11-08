#!/bin/bash
# Publish a new Cadence release that installed apps pick up through the in-app updater.
# Usage: scripts/release.sh 1.2.0 [notes-file]
set -euo pipefail

VERSION="${1:?usage: scripts/release.sh <version> [notes-file]}"
NOTES="${2:-}"
cd "$(dirname "$0")/.."

[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+)*$ ]] || { echo "error: version must look like 1.2.0" >&2; exit 1; }
git diff --quiet && git diff --cached --quiet || { echo "error: commit your changes first" >&2; exit 1; }
git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null && { echo "error: tag v$VERSION exists" >&2; exit 1; }

# Bump the marketing version and the build number.
BUILD=$(( $(sed -nE 's/.*CURRENT_PROJECT_VERSION: ([0-9]+).*/\1/p' project.yml) + 1 ))
sed -i '' -E "s/(MARKETING_VERSION: )\"[^\"]*\"/\1\"$VERSION\"/" project.yml
sed -i '' -E "s/(CURRENT_PROJECT_VERSION: )[0-9]+/\1$BUILD/" project.yml

make test
make zip
ZIP="dist/Cadence-$VERSION.zip"
[[ -f "$ZIP" ]] || { echo "error: $ZIP was not built" >&2; exit 1; }

git add project.yml Cadence.xcodeproj
git commit -m "Release v$VERSION"
git tag "v$VERSION"
git push origin HEAD "v$VERSION"

if [[ -n "$NOTES" ]]; then
  gh release create "v$VERSION" "$ZIP" --title "Cadence $VERSION" --notes-file "$NOTES"
else
  gh release create "v$VERSION" "$ZIP" --title "Cadence $VERSION" --generate-notes
fi
