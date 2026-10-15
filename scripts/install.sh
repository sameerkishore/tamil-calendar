#!/bin/zsh
# Builds a Release copy and installs it to ~/Applications, so Open at Login points at a stable app.
set -euo pipefail
cd "${0:A:h}/.."
CONFIG=Release ./scripts/build.sh
pkill -x "Rasi Palan" 2>/dev/null || true
pkill -x RasiPalan 2>/dev/null || true
sleep 0.5
mkdir -p ~/Applications
rm -rf ~/Applications/"Rasi Palan.app"
cp -R "build/Build/Products/Release/Rasi Palan.app" ~/Applications/
echo "Installed: ~/Applications/Rasi Palan.app"
open ~/Applications/"Rasi Palan.app"
