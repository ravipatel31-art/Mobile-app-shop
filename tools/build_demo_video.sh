#!/usr/bin/env bash
# Renders the 60-second demo video from the golden screenshots — no Canva,
# no screen recording. Two outputs:
#
#   marketing/demo-60s.mp4   1080x1920 (9:16)  Reels / WhatsApp / in-feed
#   docs/demo.mp4            1920x1080 (16:9)  landing page (#video section)
#
# Storyboard: marketing/demo-video-script.md (scene timings live there).
# Motion per scene is Ken Burns: zoom scenes use zoompan over a native-res
# crop; pan scenes slide the tall screenshot over the espresso background.
# Text overlays are burned in with ASS (Fraunces + Inter, gold keywords).
#
# The final file ships SILENT — add music on upload from YouTube's free
# Audio Library or CapCut. (Keeps licensing clean and the repo small.)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GOLD="$ROOT/mobile/test/goldens"
WORK="/tmp/opencode/demo_work"
FPS=30
XF=0.2                       # dissolve between scenes
CRF=20

# ── Storyboard durations (s): login, card, menu, kitchen, billing, cart,
#    staff, hero — see demo-video-script.md §1
D=(4 2 11 9 10 10 8 6)
TOTAL=58.6                   # 60 − 7 dissolves

rm -rf "$WORK"; mkdir -p "$WORK"

# ── Scene renderers ──────────────────────────────────────────────────────

# zoom_scene <img> <y0> <z0> <z1> <fy> <dur> <size> <crop_h> <out>
# Crop a 1200-px-wide native window at y0, then zoom z0→z1 over dur seconds,
# biased vertically by fy (0=top, 1=bottom, .5=centre).
zoom_scene() {
  local img=$1 y0=$2 z0=$3 z1=$4 fy=$5 dur=$6 size=$7 ch=$8 out=$9
  ffmpeg -hide_banner -loglevel error -y -i "$img" \
    -vf "crop=1200:${ch}:0:${y0},zoompan=z='${z0}+(${z1}-${z0})*min(out_time/${dur},1)':x='(iw-iw/zoom)*0.5':y='(ih-ih/zoom)*${fy}':d=$((dur*FPS)):s=${size}:fps=${FPS},format=yuv420p" \
    -r $FPS -c:v libx264 -preset medium -crf $CRF -an "$out"
}

# pan_scene <img> <y0> <y1> <dur> <size> <width> <out>
# Slide the full-width screenshot from overlay-y y0 to y1 (negative = lower
# part of the image visible) over the espresso backdrop.
pan_scene() {
  local img=$1 y0=$2 y1=$3 dur=$4 size=$5 w=$6 out=$7
  ffmpeg -hide_banner -loglevel error -y -loop 1 -framerate $FPS -t $dur -i "$img" \
    -f lavfi -t $dur -i "color=c=0x100D09:s=${size}:r=${FPS}" \
    -filter_complex "[0:v]scale=${w}:-2,format=yuv420p[fg];[1:v]format=yuv420p[bg];[bg][fg]overlay=x=0:y='${y0}+(${y1}-${y0})*t/${dur}':eval=frame:shortest=1" \
    -t $dur -c:v libx264 -preset medium -crf $CRF -an "$out"
}

# card_scene <dur> <size> <out> — flat espresso title card (scene 2)
card_scene() {
  local dur=$1 size=$2 out=$3
  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "color=c=0x14100C:s=${size}:r=${FPS}:d=${dur}" \
    -c:v libx264 -preset medium -crf $CRF -an "$out"
}

# ── ASS overlays ─────────────────────────────────────────────────────────
# \pos coordinates: 9:16 low third at y≈1250/1920; 16:9 at y≈690/1080.
# Scene starts: 0, 3.8, 5.6, 16.4, 25.2, 35.0, 44.8, 52.6 (after dissolves).
write_ass_916() {
cat > "$WORK/over.ass" << 'EOF'
[Script Info]
PlayResX: 1080
PlayResY: 1920
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Head,Fraunces,64,&H00FFFFFF,&H00FFFFFF,&H00090D10,&HA0090D10,1,0,0,0,100,100,0,0,3,9,0,5,60,60,0,1
Style: Sub,Inter,40,&H00DAE4ED,&H00FFFFFF,&H00090D10,&HA0090D10,0,0,0,0,100,100,0,0,3,7,0,5,60,60,0,1
Style: Title,Fraunces,104,&H005AB2E6,&H00FFFFFF,&H00090D10,&HA0090D10,1,0,0,0,100,100,0,0,3,12,0,5,60,60,0,1
Style: TitleSub,Inter,42,&H00DAE4ED,&H00FFFFFF,&H00090D10,&HA0090D10,0,0,0,0,100,100,0,0,3,8,0,5,60,60,0,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:00.40,0:00:03.45,Head,,0,0,0,,{\an5\pos(540,1480)\fad(350,350)}Still running your café on {\c&H005AB2E6&}paper chits?
Dialogue: 0,0:00:03.95,0:00:05.40,Title,,0,0,0,,{\an5\pos(540,900)\fad(300,300)}Cafe POS
Dialogue: 0,0:00:03.95,0:00:05.40,TitleSub,,0,0,0,,{\an5\pos(540,1035)\fad(300,300)}the POS built for cafés
Dialogue: 0,0:00:06.05,0:00:15.95,Head,,0,0,0,,{\an5\pos(540,1250)\fad(350,350)}Take the order {\c&H005AB2E6&}in seconds
Dialogue: 0,0:00:06.05,0:00:15.95,Sub,,0,0,0,,{\an5\pos(540,1390)\fad(350,350)}One tap per item — the cart totals itself.
Dialogue: 0,0:00:16.85,0:00:24.75,Head,,0,0,0,,{\an5\pos(540,1250)\fad(350,350)}Kitchen sees it {\c&H005AB2E6&}instantly
Dialogue: 0,0:00:16.85,0:00:24.75,Sub,,0,0,0,,{\an5\pos(540,1390)\fad(350,350)}No chits. No shouting. It's already there.
Dialogue: 0,0:00:25.65,0:00:34.65,Head,,0,0,0,,{\an5\pos(540,1250)\fad(350,350)}Bill printed · {\c&H005AB2E6&}UPI & GPay built in
Dialogue: 0,0:00:25.65,0:00:34.65,Sub,,0,0,0,,{\an5\pos(540,1390)\fad(350,350)}Print it or take a UPI payment — no extra machine.
Dialogue: 0,0:00:35.45,0:00:44.45,Head,,0,0,0,,{\an5\pos(540,1250)\fad(350,350)}Know exactly what you {\c&H005AB2E6&}earned today
Dialogue: 0,0:00:35.45,0:00:44.45,Sub,,0,0,0,,{\an5\pos(540,1390)\fad(350,350)}Sales, best-sellers and payment mix — tallied automatically.
Dialogue: 0,0:00:45.25,0:00:52.25,Head,,0,0,0,,{\an5\pos(540,1250)\fad(350,350)}Customers order from their {\c&H005AB2E6&}own phone
Dialogue: 0,0:00:45.25,0:00:52.25,Sub,,0,0,0,,{\an5\pos(540,1390)\fad(350,350)}No app for them to install.
Dialogue: 0,0:00:53.05,0:00:58.35,Head,,0,0,0,,{\an5\pos(540,1250)\fad(350,250)}{\c&H005AB2E6&}Free 14-day trial
Dialogue: 0,0:00:53.05,0:00:58.35,Sub,,0,0,0,,{\an5\pos(540,1390)\fad(350,250)}Book a free 10-minute demo · +91 63517 70056
EOF
}

write_ass_169() {
cat > "$WORK/over.ass" << 'EOF'
[Script Info]
PlayResX: 1920
PlayResY: 1080
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Head,Fraunces,66,&H00FFFFFF,&H00FFFFFF,&H00090D10,&HA0090D10,1,0,0,0,100,100,0,0,3,9,0,5,120,120,0,1
Style: Sub,Inter,42,&H00DAE4ED,&H00FFFFFF,&H00090D10,&HA0090D10,0,0,0,0,100,100,0,0,3,7,0,5,120,120,0,1
Style: Title,Fraunces,120,&H005AB2E6,&H00FFFFFF,&H00090D10,&HA0090D10,1,0,0,0,100,100,0,0,3,12,0,5,120,120,0,1
Style: TitleSub,Inter,46,&H00DAE4ED,&H00FFFFFF,&H00090D10,&HA0090D10,0,0,0,0,100,100,0,0,3,8,0,5,120,120,0,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:00.40,0:00:03.45,Head,,0,0,0,,{\an5\pos(960,760)\fad(350,350)}Still running your café on {\c&H005AB2E6&}paper chits?
Dialogue: 0,0:00:03.95,0:00:05.40,Title,,0,0,0,,{\an5\pos(960,480)\fad(300,300)}Cafe POS
Dialogue: 0,0:00:03.95,0:00:05.40,TitleSub,,0,0,0,,{\an5\pos(960,625)\fad(300,300)}the POS built for cafés
Dialogue: 0,0:00:06.05,0:00:15.95,Head,,0,0,0,,{\an5\pos(960,760)\fad(350,350)}Take the order {\c&H005AB2E6&}in seconds
Dialogue: 0,0:00:06.05,0:00:15.95,Sub,,0,0,0,,{\an5\pos(960,875)\fad(350,350)}One tap per item — the cart totals itself.
Dialogue: 0,0:00:16.85,0:00:24.75,Head,,0,0,0,,{\an5\pos(960,760)\fad(350,350)}Kitchen sees it {\c&H005AB2E6&}instantly
Dialogue: 0,0:00:16.85,0:00:24.75,Sub,,0,0,0,,{\an5\pos(960,875)\fad(350,350)}No chits. No shouting. It's already there.
Dialogue: 0,0:00:25.65,0:00:34.65,Head,,0,0,0,,{\an5\pos(960,760)\fad(350,350)}Bill printed · {\c&H005AB2E6&}UPI & GPay built in
Dialogue: 0,0:00:25.65,0:00:34.65,Sub,,0,0,0,,{\an5\pos(960,875)\fad(350,350)}Print it or take a UPI payment — no extra machine.
Dialogue: 0,0:00:35.45,0:00:44.45,Head,,0,0,0,,{\an5\pos(960,760)\fad(350,350)}Know exactly what you {\c&H005AB2E6&}earned today
Dialogue: 0,0:00:35.45,0:00:44.45,Sub,,0,0,0,,{\an5\pos(960,875)\fad(350,350)}Sales, best-sellers and payment mix — tallied automatically.
Dialogue: 0,0:00:45.25,0:00:52.25,Head,,0,0,0,,{\an5\pos(960,760)\fad(350,350)}Customers order from their {\c&H005AB2E6&}own phone
Dialogue: 0,0:00:45.25,0:00:52.25,Sub,,0,0,0,,{\an5\pos(960,875)\fad(350,350)}No app for them to install.
Dialogue: 0,0:00:53.05,0:00:58.35,Head,,0,0,0,,{\an5\pos(960,905)\fad(350,250)}{\c&H005AB2E6&}Free 14-day trial
Dialogue: 0,0:00:53.05,0:00:58.35,Sub,,0,0,0,,{\an5\pos(960,1005)\fad(350,250)}Book a free 10-minute demo · +91 63517 70056
EOF
}

# ── Per-aspect render ────────────────────────────────────────────────────
# build <aspect> where aspect is 9x16 | 16x9
build() {
  local aspect=$1 size ch w out
  if [ "$aspect" = "9x16" ]; then
    size=1080x1920; ch=2133; w=1080
    out="$ROOT/marketing/demo-60s.mp4"
    # pan offsets (overlay coords at width 1080, scale 0.9)
    local menu_y0=-1100 menu_y1=0 bill_y0=-225 bill_y1=-1350
    local login_y0=250 kitchen_y0=0 cart_y0=567 staff_y0=150 hero_y0=0
    write_ass_916
  else
    size=1920x1080; ch=675; w=1920
    out="$ROOT/docs/demo.mp4"
    # pan offsets at width 1920 (scale 1.6)
    local menu_y0=-1955 menu_y1=0 bill_y0=-400 bill_y1=-2560
    local login_y0=350 kitchen_y0=729 cart_y0=2025 staff_y0=500 hero_y0=560
    write_ass_169
  fi

  echo "▶ scenes ($aspect)…"
  zoom_scene "$GOLD/login.png"   $login_y0   1.00 1.08 0.5 4  "$size" $ch "$WORK/s1.mp4"
  card_scene 2 "$size" "$WORK/s2.mp4"
  pan_scene   "$GOLD/menu.png"   $menu_y0 $menu_y1 11 "$size" $w "$WORK/s3.mp4"
  zoom_scene  "$GOLD/kitchen.png" $kitchen_y0 1.00 1.12 0.5 9  "$size" $ch "$WORK/s4.mp4"
  pan_scene   "$GOLD/billing.png" $bill_y0 $bill_y1 10 "$size" $w "$WORK/s5.mp4"
  zoom_scene  "$GOLD/cart.png"   $cart_y0   1.00 1.15 0.7 10 "$size" $ch "$WORK/s6.mp4"
  zoom_scene  "$GOLD/staff.png"  $staff_y0  1.08 1.00 0.4 8  "$size" $ch "$WORK/s7.mp4"
  zoom_scene  "$GOLD/hero.png"   $hero_y0   1.00 1.15 0.3 6  "$size" $ch "$WORK/s8.mp4"

  echo "▶ dissolve + burn text ($aspect)…"
  ffmpeg -hide_banner -loglevel error -y \
    -i "$WORK/s1.mp4" -i "$WORK/s2.mp4" -i "$WORK/s3.mp4" -i "$WORK/s4.mp4" \
    -i "$WORK/s5.mp4" -i "$WORK/s6.mp4" -i "$WORK/s7.mp4" -i "$WORK/s8.mp4" \
    -f lavfi -t $TOTAL -i "anullsrc=r=48000:cl=stereo" \
    -filter_complex "\
[0:v][1:v]xfade=transition=fade:duration=$XF:offset=3.8[v0];\
[v0][2:v]xfade=transition=fade:duration=$XF:offset=5.6[v1];\
[v1][3:v]xfade=transition=fade:duration=$XF:offset=16.4[v2];\
[v2][4:v]xfade=transition=fade:duration=$XF:offset=25.2[v3];\
[v3][5:v]xfade=transition=fade:duration=$XF:offset=35.0[v4];\
[v4][6:v]xfade=transition=fade:duration=$XF:offset=44.8[v5];\
[v5][7:v]xfade=transition=fade:duration=$XF:offset=52.6[v6];\
[v6]ass=${WORK}/over.ass,fade=in:st=0:d=0.4,fade=out:st=58.2:d=0.4,format=yuv420p[v]" \
    -map "[v]" -map 8:a \
    -c:v libx264 -preset medium -crf $CRF -pix_fmt yuv420p \
    -c:a aac -b:a 96k -movflags +faststart -t $TOTAL "$out"

  echo "✔ $out ($(du -h "$out" | cut -f1))"
}

case "${1:-all}" in
  9x16)  build 9x16 ;;
  16x9)  build 16x9 ;;
  all)   build 9x16; build 16x9 ;;
  *) echo "usage: $0 [9x16|16x9|all]"; exit 1 ;;
esac
