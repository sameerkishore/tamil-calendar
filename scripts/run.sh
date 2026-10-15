#!/bin/zsh
# Builds, quits any running copy, and launches the app.
set -euo pipefail
cd "${0:A:h}/.."
./scripts/build.sh
pkill -x RasiPalan 2>/dev/null && sleep 0.5 || true
open "build/Build/Products/${CONFIG:-Debug}/RasiPalan.app"
