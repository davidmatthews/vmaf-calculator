#!/bin/bash

set -e

SOURCE="$1"
CRF="$2"
MODE="$3"

if [[ -z "$SOURCE" || -z "$CRF" ]]; then
  echo "Usage: $0 <input_file> <crf> [animation]"
  exit 1
fi

WIDTH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nk=1:nw=1 "$SOURCE")
HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nk=1:nw=1 "$SOURCE")
TRANSFER=$(ffprobe -v error -select_streams v:0 -show_entries stream=color_transfer -of default=nk=1:nw=1 "$SOURCE")

echo "Detected resolution: ${WIDTH}x${HEIGHT}"

# Get source video bitrate via MediaInfo
VIDEO_BITRATE=$(mediainfo --Inform="Video;%BitRate%" "$SOURCE" | head -n1)

if [[ -z "$VIDEO_BITRATE" ]]; then
  echo "Warning: Could not determine source video bitrate"
  VIDEO_BITRATE_KBPS=0
else
  VIDEO_BITRATE_KBPS=$((VIDEO_BITRATE / 1000))
fi

echo "Source video bitrate: ${VIDEO_BITRATE_KBPS} Kbps"

# Resolution thresholds (~10% buffer above 1080p)
WIDTH_THRESHOLD=2100
HEIGHT_THRESHOLD=1200

if [[ "$WIDTH" -gt "$WIDTH_THRESHOLD" || "$HEIGHT" -gt "$HEIGHT_THRESHOLD" ]]; then
  RES="4k"
else
  RES="1080p"
fi

# HDR detection
if [[ "$TRANSFER" == "smpte2084" || "$TRANSFER" == "arib-std-b67" ]]; then
  DYNAMIC_RANGE="HDR"
else
  DYNAMIC_RANGE="SDR"
fi

echo "Dynamic range: $DYNAMIC_RANGE ($TRANSFER)"

if [[ "$MODE" == "animation" ]]; then
  PRESET="${RES}-animation"
else
  PRESET="$RES"
fi

echo "Using preset: $PRESET"

case "$PRESET" in

1080p)
OUTPUT=$(ab-av1 sample-encode --min-samples 3 --encoder libx265 --crf "$CRF" --preset slow --pix-format yuv420p10le --enc "x265-params=high-tier=1:repeat-headers=1:aud=1:hrd=1:deblock=-3,-3:no-open-gop=1:no-sao=1:aq-mode=3:pools=6" --input "$SOURCE" 2>&1 | tee /dev/tty)
;;

1080p-animation)
OUTPUT=$(ab-av1 sample-encode --min-samples 3 --encoder libx265 --crf "$CRF" --preset slow --pix-format yuv420p10le --enc "tune=animation" --enc "x265-params=high-tier=1:repeat-headers=1:aud=1:hrd=1:deblock=-1,-1:no-open-gop=1:no-sao=1:aq-mode=3:pools=6" --input "$SOURCE" 2>&1 | tee /dev/tty)
;;

4k)
OUTPUT=$(ab-av1 sample-encode --min-samples 3 --encoder libx265 --crf "$CRF" --preset slow --pix-format yuv420p10le --enc "x265-params=high-tier=1:repeat-headers=1:aud=1:hrd=1:deblock=-3,-3:no-open-gop=1:no-sao=1:pools=6" --input "$SOURCE" 2>&1 | tee /dev/tty)
;;

4k-animation)
OUTPUT=$(ab-av1 sample-encode --min-samples 3 --encoder libx265 --crf "$CRF" --preset slow --pix-format yuv420p10le --tune animation --enc "x265-params=high-tier=1:repeat-headers=1:aud=1:hrd=1:deblock=-1,-1:no-open-gop=1:no-sao=1:pools=6" --input "$SOURCE" 2>&1 | tee /dev/tty)
;;

esac

PERCENT=$(echo "$OUTPUT" | grep "predicted video stream size" | sed -E 's/.*\(([0-9]+)%\).*/\1/' | tail -n1)

if [[ -n "$PERCENT" ]]; then
  PREDICTED_BITRATE=$((VIDEO_BITRATE_KBPS * PERCENT / 100))
  echo ""
  echo "Predicted encoded video bitrate: ${PREDICTED_BITRATE} Kbps"
fi