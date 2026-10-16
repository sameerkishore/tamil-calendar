#!/bin/zsh
# Builds the DMG for an existing, pushed tag, signs it for Sparkle, and creates the GitHub release
# with the DMG and appcast.xml attached. The app's SUFeedURL reads the appcast from the latest release.
# Usage: ./scripts/publish_release.sh 1.1.0 "What's new (Markdown: paragraphs, - bullets, **bold**)"
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
# Releases must carry the stable signature, or users get the permission prompts again.
codesign -d -r- "$app" 2>&1 | grep -q 'certificate root = H"d3f87aeb17643d4dfa9aaf9286145977334f474c"' \
  || { echo "App isn't signed with the Tamil Calendar Signing certificate." >&2; exit 1; }

# The notes are Markdown for GitHub; Sparkle's update window wants HTML (paragraphs, "- " bullets, **bold**).
notes_html=$(print -r -- "$notes" | awk '
  /^- / { if (!list) { print "<ul>"; list = 1 } sub(/^- /, ""); print "<li>" $0 "</li>"; next }
  { if (list) { print "</ul>"; list = 0 } if (length($0)) print "<p>" $0 "</p>" }
  END { if (list) print "</ul>" }' | sed -E 's/\*\*([^*]+)\*\*/<b>\1<\/b>/g; s/_([^_]+)_/<i>\1<\/i>/g')

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
      <description><![CDATA[$notes_html]]></description>
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
