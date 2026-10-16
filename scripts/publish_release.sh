#!/bin/zsh
# Builds the DMG for an existing, pushed tag, signs it for Sparkle, and creates the GitHub release
# with the DMG and appcast.xml attached. The app's SUFeedURL reads the appcast from the latest release.
# Usage: ./scripts/publish_release.sh 1.1.0 "What's new, in a sentence or two"
set -euo pipefail
cd "${0:A:h}/.."
tag="${1:?usage: publish_release.sh <tag> [notes]}"
notes="${2:-Small fixes and improvements.}"
repo="sameerkishore/tamil-calendar"

./scripts/make_dmg.sh
app="build/Build/Products/Release/Tamil Calendar.app"
short=$(plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")
build=$(plutil -extract CFBundleVersion raw "$app/Contents/Info.plist")
[[ "$short" == "$tag" ]] || { echo "App version is $short, not $tag; run bump_version.sh first." >&2; exit 1; }

dmg="build/Tamil-Calendar-$tag.dmg"
mv "build/Tamil Calendar.dmg" "$dmg"
# Signs with the EdDSA key in the login Keychain (created by Sparkle's generate_keys).
signature=$(build/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update "$dmg")

cat > build/appcast.xml <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Tamil Calendar</title>
    <item>
      <title>Tamil Calendar $tag</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$build</sparkle:version>
      <sparkle:shortVersionString>$tag</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[<p>$notes</p>]]></description>
      <enclosure url="https://github.com/$repo/releases/download/$tag/Tamil-Calendar-$tag.dmg"
                 type="application/octet-stream" $signature />
    </item>
  </channel>
</rss>
XML

gh release create "$tag" "$dmg" build/appcast.xml -R "$repo" --verify-tag \
  --title "Tamil Calendar $tag" --notes "$notes

**New here?** Open the DMG and drag Tamil Calendar onto Applications. It isn't notarized, so the first
time you open it, click Done on the warning, then go to System Settings → Privacy & Security and click
**Open Anyway**. After that it updates itself from the menu bar. Needs macOS 14 or later.

© 2026 Sameer Kishore. Made with ❤️ by Sameer (and Claude)."
