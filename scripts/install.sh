#!/bin/zsh
# Builds a Release copy and installs it to ~/Applications, so Open at Login points at a stable app.
set -euo pipefail
cd "${0:A:h}/.."
CONFIG=Release ./scripts/build.sh
pkill -x "Tamil Calendar" 2>/dev/null || true
pkill -x "Rasi Palan" 2>/dev/null || true
pkill -x RasiPalan 2>/dev/null || true
sleep 0.5
mkdir -p ~/Applications
rm -rf ~/Applications/"Tamil Calendar.app" ~/Applications/"Rasi Palan.app"
cp -R "build/Build/Products/Release/Tamil Calendar.app" ~/Applications/
echo "Installed: ~/Applications/Tamil Calendar.app"
open ~/Applications/"Tamil Calendar.app"
