#!/usr/bin/env bash
# Stage the 5.1 demo library: the 14 sample photos sorted into nested folders,
# so the folder tree, relative-path captions, and search have something to show.
# Usage: scripts/stage-demo-library.sh [destination]   (default: ~/Pictures/Landscapes)
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
photos="$here/../screenshots-4.3.0/sample-photos"
dest="${1:-$HOME/Pictures/Landscapes}"

if [[ -e "$dest" ]]; then
    echo "Refusing to overwrite existing $dest; pass another destination." >&2
    exit 1
fi

place() {
    local folder="$1"; shift
    mkdir -p "$dest/$folder"
    for name in "$@"; do cp "$photos/$name.jpg" "$dest/$folder/"; done
}

mkdir -p "$dest"
cp "$photos/raspberries.jpg" "$dest/"
place "Coast" sea-foam storm-coast lakeside-dock
place "Coast/Fjords" fjord-overlook
cp "$here/sample-documents/trailhead-notice.png" "$dest/Coast/Fjords/"
place "Mountains" highland-road valley-river canyon-sunset
place "Mountains/Winter" winter-camp northern-lights
place "Towns" brick-alley city-from-above hilltop-castle
place "Forest" forest-waterfall

echo "Staged $(find "$dest" -type f | wc -l | tr -d ' ') files in $dest"
