#!/bin/zsh
# Generates the Xcode project from project.yml and builds RasiPalan.app into build/.
# UNIVERSAL=1 builds for both Apple Silicon and Intel.
set -euo pipefail
cd "${0:A:h}/.."
xcodegen generate --quiet
if [[ -n "${UNIVERSAL:-}" ]]; then
  arch_args=(-destination 'generic/platform=macOS' ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO)
else
  arch_args=(-destination 'platform=macOS,arch=arm64')
fi
xcodebuild -project RasiPalan.xcodeproj -scheme RasiPalan -configuration "${CONFIG:-Debug}" \
  -derivedDataPath build "${arch_args[@]}" build -quiet
echo "Built: build/Build/Products/${CONFIG:-Debug}/Tamil Calendar.app"
