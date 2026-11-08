#!/bin/bash
# Cut a release: bump the version, commit, tag and push. The Release workflow
# (.github/workflows/release.yml) then builds the app on macOS and publishes the
# GitHub release, which installed copies pick up through the in-app updater.
# Usage: scripts/release.sh 1.2.0
set -euo pipefail

VERSION="${1:?usage: scripts/release.sh <version>}"
cd "$(dirname "$0")/.."

[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+)*$ ]] || { echo "error: version must look like 1.2.0" >&2; exit 1; }
git diff --quiet && git diff --cached --quiet || { echo "error: commit your changes first" >&2; exit 1; }
git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null && { echo "error: tag v$VERSION exists" >&2; exit 1; }

BUILD=$(( $(sed -nE 's/.*CURRENT_PROJECT_VERSION: ([0-9]+).*/\1/p' project.yml) + 1 ))
sed -i '' -E "s/(MARKETING_VERSION: )\"[^\"]*\"/\1\"$VERSION\"/" project.yml
sed -i '' -E "s/(CURRENT_PROJECT_VERSION: )[0-9]+/\1$BUILD/" project.yml
make project
make test

git add project.yml Cadence.xcodeproj
git commit -m "Release v$VERSION"
git tag "v$VERSION"
git push origin HEAD "v$VERSION"

echo "Pushed v$VERSION. Follow the build: gh run list --workflow release.yml"
