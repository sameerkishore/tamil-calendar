#!/bin/zsh
# Sets the app version in project.yml and increments the build number Sparkle compares.
# Usage: ./scripts/bump_version.sh 1.1.0
set -euo pipefail
cd "${0:A:h}/.."
version="${1:?usage: bump_version.sh <version>}"
build=$(( $(sed -nE 's/ *CFBundleVersion: "([0-9]+)"/\1/p' project.yml) + 1 ))
sed -i '' -E "s/(CFBundleShortVersionString: )\"[^\"]*\"/\1\"$version\"/; s/(CFBundleVersion: )\"[0-9]+\"/\1\"$build\"/" project.yml
echo "Version $version (build $build)"
