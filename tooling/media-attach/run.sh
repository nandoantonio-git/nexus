#!/usr/bin/env bash
# Attach a local media file to GitHub and print a hosted URL that renders as an
# inline image / video player in issue, PR, and comment markdown.
#
#   ./run.sh path/to/clip.mp4
#   ./run.sh screenshot.png --repo owner/repo
#
# Requires a one-time local setup on this machine. If it reports missing setup,
# ask the user to complete it — do not attempt to configure it yourself.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
provider="${NEXUS_MEDIA_PROVIDER:-$HOME/.config/nexus-media/provider.py}"

if [ ! -f "$provider" ]; then
  echo "media-attach: one-time local setup not found on this machine — ask the user to complete it" >&2
  exit 3
fi

GH_COOKIE="$(python3 "$provider" github.com --all)"
export GH_COOKIE
exec python3 "$here/attach.py" "$@"
