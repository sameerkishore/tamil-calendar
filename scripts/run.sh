#!/bin/zsh
# Builds, quits any running copy, and launches the app.
set -euo pipefail
cd "${0:A:h}/.."
./scripts/build.sh
pkill -x "Tamil Calendar" 2>/dev/null || true
pkill -x "Rasi Palan" 2>/dev/null || true
pkill -x RasiPalan 2>/dev/null || true
sleep 0.5
open "build/Build/Products/${CONFIG:-Debug}/Tamil Calendar.app"
