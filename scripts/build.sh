#!/bin/zsh
# Generates the Xcode project from project.yml and builds RasiPalan.app into build/.
set -euo pipefail
cd "${0:A:h}/.."
xcodegen generate --quiet
xcodebuild -project RasiPalan.xcodeproj -scheme RasiPalan -configuration "${CONFIG:-Debug}" \
  -derivedDataPath build -destination 'platform=macOS,arch=arm64' build -quiet
echo "Built: build/Build/Products/${CONFIG:-Debug}/RasiPalan.app"
