#!/bin/zsh
# Creates a Gitea release for an existing tag and attaches build/Tamil Calendar.dmg.
# Usage: ./scripts/publish_release.sh 1.0.0   (asks for a Gitea access token with repo write scope)
set -euo pipefail
cd "${0:A:h}/.."
tag="${1:?usage: publish_release.sh <tag>}"
api="https://git.sameerkishore.com/api/v1/repos/sameerkishore/rasi-palan"
dmg="build/Tamil Calendar.dmg"
[[ -f "$dmg" ]] || ./scripts/make_dmg.sh
read -rs "token?Gitea access token: "; echo

body=$(cat <<NOTES
A tear-off South Indian daily calendar for the macOS desktop.

**Install:** open the DMG and drag Tamil Calendar onto Applications. It isn't notarized, so the first
time you open it, click Done on the warning, then go to System Settings → Privacy & Security and click
**Open Anyway**. It lives in the menu bar. Needs macOS 14 or later; runs on Apple Silicon and Intel.

© 2026 Sameer Kishore. Made with ❤️ by Sameer (and Claude).
NOTES
)
payload=$(jq -n --arg tag "$tag" --arg name "Tamil Calendar $tag" --arg body "$body" \
  '{tag_name: $tag, name: $name, body: $body}')
id=$(curl -fsS -X POST "$api/releases" -H "Authorization: token $token" \
  -H "Content-Type: application/json" -d "$payload" | jq -r .id)
curl -fsS -X POST "$api/releases/$id/assets?name=Tamil-Calendar-$tag.dmg" \
  -H "Authorization: token $token" -F "attachment=@$dmg" > /dev/null
echo "Released: https://git.sameerkishore.com/sameerkishore/rasi-palan/releases/tag/$tag"
