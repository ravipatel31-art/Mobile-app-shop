#!/usr/bin/env bash
# Publish the generated app screenshots to the marketing site.
#
#   1. Regenerates the goldens at full res (Flutter, real fonts, fake API) —
#      run `flutter test test/generate_demo_shots_test.dart --update-goldens`
#      from mobile/ first if the UI changed.
#   2. Emits web-sized copies into docs/screens/ for the landing page, and a
#      hero graphic into marketing/screens/ for the one-pager PDF.
#
# The goldens in mobile/test/goldens are the full-resolution source of truth;
# everything here is a downscale of those. PNG (not WebP) because the app is
# flat dark UI — PNG compresses these near-losslessly and needs no encoder
# beyond ImageMagick.
#
# Usage:  tools/build_screenshots.sh
set -euo pipefail
cd "$(dirname "$0")/.."

GOLD=mobile/test/goldens
OUT=docs/screens
MKT=marketing/screens

command -v magick >/dev/null || { echo "ImageMagick (magick) is required"; exit 1; }
[ -d "$GOLD" ] || { echo "No goldens — run the Flutter generator first"; exit 1; }

mkdir -p "$OUT" "$MKT"

# Landing hero for the CSS phone frame (~270 CSS px wide). 560x is a clean 2x
# retina asset; the frame's object-fit:cover + object-position:top crops it to
# the top of the dashboard, which is exactly the shot we want in the hero.
magick "$GOLD/hero.png" -resize 560x -strip -quality 88 "$OUT/hero.png"

# One-pager graphic (marketing/one-pager.html references screens/onepager.png).
# Cropped to the top of the dashboard, not the full 2332px scroll — the full
# height blows out the A4 one-pager. 620x780 fits the right column exactly.
magick "$GOLD/hero.png" -resize 620x -gravity North -extent 620x780 -strip -quality 92 "$MKT/onepager.png"

# Landing gallery shots.
for shot in menu cart kitchen billing orders staff login; do
  [ -f "$GOLD/$shot.png" ] || continue
  magick "$GOLD/$shot.png" -resize 560x -strip -quality 88 "$OUT/$shot.png"
done

echo "Screens published:"
du -h "$OUT"/*.png "$MKT/onepager.png" | sort -k2
