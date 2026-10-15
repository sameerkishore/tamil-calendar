#!/bin/zsh
# Builds a universal Release app and packages it as build/Tamil Calendar.dmg for sharing.
# The app is ad-hoc signed, not notarized: recipients approve it once in
# System Settings → Privacy & Security → Open Anyway (see the note inside the DMG).
set -euo pipefail
cd "${0:A:h}/.."
CONFIG=Release UNIVERSAL=1 ./scripts/build.sh

app="build/Build/Products/Release/Tamil Calendar.app"
stage="build/dmg"
dmg="build/Tamil Calendar.dmg"
rm -rf "$stage" "$dmg"
mkdir -p "$stage"
cp -R "$app" "$stage/"
ln -s /Applications "$stage/Applications"
cat > "$stage/How to open.txt" <<'NOTE'
Tamil Calendar isn't from the App Store, so macOS asks you to approve it once.

1. Drag "Tamil Calendar" onto the Applications folder.
2. Open it from Applications. macOS says it can't verify the app; click Done.
3. Open System Settings → Privacy & Security, scroll down, and click
   "Open Anyway" next to Tamil Calendar. Enter your password.

From then on it opens normally. It lives in the menu bar, not the Dock.
Needs macOS 14 (Sonoma) or later.
NOTE

hdiutil create -volname "Tamil Calendar" -srcfolder "$stage" -fs HFS+ -format UDZO -ov "$dmg" -quiet
rm -rf "$stage"
echo "Created: $dmg ($(du -h "$dmg" | cut -f1 | xargs))"
