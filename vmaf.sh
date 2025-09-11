#!/bin/bash
# Usage: ./vmaf.sh source.mkv encoded.mkv [top right bottom left]

set -e

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <source_file> <encoded_file> [top_crop right_crop bottom_crop left_crop]"
    exit 1
fi

SOURCE="$1"
ENCODED="$2"

# If crop args provided, use them. If not, auto-detect.
if [ "$#" -ge 6 ]; then
    TOP="$3"
    RIGHT="$4"
    BOTTOM="$5"
    LEFT="$6"
elif [ "$#" -eq 2 ]; then
    echo "🔎 No crop values provided, auto-detecting with HandBrakeCLI..."
    AUTOCROP=$(HandBrakeCLI -i "$SOURCE" --scan 2>&1 | grep -o 'autocrop: [0-9/]*' | tail -n1 | awk '{print $2}')
    if [ -n "$AUTOCROP" ]; then
        IFS='/' read -r TOP BOTTOM LEFT RIGHT <<< "$AUTOCROP"
        echo "➡️  Auto-detected crop: top=$TOP, bottom=$BOTTOM, left=$LEFT, right=$RIGHT"
    else
        echo "⚠️  Could not auto-detect crop, defaulting to no crop."
        TOP=0; RIGHT=0; BOTTOM=0; LEFT=0
    fi
else
    echo "❌ Error: Invalid arguments."
    exit 1
fi

# Get source dimensions
WIDTH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$SOURCE")
HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$SOURCE")

# Compute cropped dimensions
CROP_WIDTH=$((WIDTH - LEFT - RIGHT))
CROP_HEIGHT=$((HEIGHT - TOP - BOTTOM))

# Build optional crop filter
VFILTER=""
if [ "$TOP" -ne 0 ] || [ "$RIGHT" -ne 0 ] || [ "$BOTTOM" -ne 0 ] || [ "$LEFT" -ne 0 ]; then
    VFILTER="--reference-vfilter crop=${CROP_WIDTH}:${CROP_HEIGHT}:${LEFT}:${TOP}"
fi

# Run ab-av1
echo "➡️  Running ab-av1 VMAF comparison..."
OUTPUT=$(ab-av1 vmaf --reference "$SOURCE" --distorted "$ENCODED" $VFILTER)

# Extract final VMAF score (last floating-point number)
VMAF_SCORE=$(echo "$OUTPUT" | grep -Eo '[0-9]+(\.[0-9]+)?' | tail -n1)

if [ -z "$VMAF_SCORE" ]; then
    echo "❌ Error: Could not parse VMAF score from ab-av1 output."
    exit 1
fi

# Round to 2 decimals
VMAF_SCORE_2D=$(awk -v s="$VMAF_SCORE" 'BEGIN {printf "%.2f", s}')

# Prepare new filename
BASENAME="${ENCODED%.*}"
EXT="${ENCODED##*.}"
NEW_NAME="${BASENAME}_VMAF${VMAF_SCORE_2D}.${EXT}"

# Rename encoded file
mv "$ENCODED" "$NEW_NAME"

echo "✅ VMAF score: $VMAF_SCORE (rounded: $VMAF_SCORE_2D)"
echo "📁 Renamed file: $NEW_NAME"