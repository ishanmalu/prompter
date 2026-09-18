#!/usr/bin/env bash
# Mirror a take horizontally, on the Mac, after filming.
#
#   ./mirror.sh ~/Downloads/take-02.mp4            # -> take-02-mirrored.mp4
#   ./mirror.sh ~/Downloads/take-02.mp4 out.mp4
#
# Why here and not on the phone: mirroring in the browser means copying every
# frame through a canvas before it is encoded, and an iPhone answers that by
# dropping frames -- a 50-second take came back at 7.6fps. The Mac does the same
# job afterwards at full frame rate, so film with "Record what I see" off and
# flip it here.
set -euo pipefail

SRC="${1:-}"
[ -n "$SRC" ] || { echo "usage: ./mirror.sh <take.mp4> [out.mp4]" >&2; exit 1; }
[ -f "$SRC" ] || { echo "No such file: $SRC" >&2; exit 1; }
command -v ffmpeg >/dev/null || { echo "ffmpeg not found. brew install ffmpeg" >&2; exit 1; }

DST="${2:-${SRC%.*}-mirrored.${SRC##*.}}"

# Audio is copied untouched; only the video is re-encoded, and hflip is the whole
# of it. CRF 18 is visually transparent for a talking head.
ffmpeg -hide_banner -loglevel error -y -i "$SRC" \
  -vf hflip -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
  -c:a copy -movflags +faststart "$DST"

echo "Wrote $DST"
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,avg_frame_rate -show_entries format=duration \
  -of default=noprint_wrappers=1 "$DST"
