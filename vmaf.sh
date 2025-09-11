#!/bin/bash
# Usage: ./vmaf.sh source.mkv encoded.mkv top right bottom left

set -e

if [ "$#" -ne 6 ]; then
    echo "Usage: $0 <source_file> <encoded_file> <top_crop> <right_crop> <bottom_crop> <left_crop>"
    exit 1
fi

SOURCE="$1"
ENCODED="$2"
TOP="$3"
RIGHT="$4"
BOTTOM="$5"
LEFT="$6"

# Get source dimensions
WIDTH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$SOURCE")
HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$SOURCE")

# Compute cropped dimensions
CROP_WIDTH=$((WIDTH - LEFT - RIGHT))
CROP_HEIGHT=$((HEIGHT - TOP - BOTTOM))

# Run ab-av1 with crop filter
echo "➡️  Running ab-av1 VMAF comparison..."
OUTPUT=$(ab-av1 vmaf \
    --reference "$SOURCE" \
    --distorted "$ENCODED" \
    --reference-vfilter "crop=${CROP_WIDTH}:${CROP_HEIGHT}:${LEFT}:${TOP}")

# Extract the final VMAF score
VMAF_SCORE=$(echo "$OUTPUT" | grep -Eo '[0-9]+(\.[0-9]+)?' | tail -n1)

if [ -z "$VMAF_SCORE" ]; then
    echo "❌ Error: Could not parse VMAF score from ab-av1 output."
    exit 1
fi

# Round/format to 2 decimals
VMAF_SCORE_2D=$(awk -v s="$VMAF_SCORE" 'BEGIN {printf "%.2f", s}')

# Prepare new filename
BASENAME="${ENCODED%.*}"
EXT="${ENCODED##*.}"
NEW_NAME="${BASENAME}-VMAF${VMAF_SCORE_2D}.${EXT}"

# Rename the encoded file
mv "$ENCODED" "$NEW_NAME"

echo "✅ VMAF score: $VMAF_SCORE (rounded: $VMAF_SCORE_2D)"
echo "📁 Renamed file: $NEW_NAME"