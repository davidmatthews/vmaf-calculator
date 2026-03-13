#!/bin/bash

# Exit on error
set -e

# Check input
if [ -z "$1" ]; then
  echo "Usage: $0 <folder> [--dry-run]"
  exit 1
fi

FOLDER="$1"
DRY_RUN=false

if [ "$2" == "--dry-run" ]; then
  DRY_RUN=true
fi

# Check folder exists
if [ ! -d "$FOLDER" ]; then
  echo "Error: '$FOLDER' is not a valid directory."
  exit 1
fi

# Supported video extensions
EXTENSIONS="mp4 mkv mov avi flv wmv m4v"

# Build find pattern safely
PATTERN=""
for EXT in $EXTENSIONS; do
  PATTERN="$PATTERN -o -iname '*.$EXT'"
done
PATTERN="${PATTERN# -o }"

# Process each video file (non-recursive)
eval "find \"$FOLDER\" -maxdepth 1 \( $PATTERN \)" | while read -r FILE; do
  DIR=$(dirname "$FILE")
  BASENAME=$(basename "$FILE")
  EXT="${BASENAME##*.}"
  NAME="${BASENAME%.*}"

  # Skip if already renamed
  if [[ "$NAME" =~ -[0-9]+kbps$ ]]; then
    echo "Skipping (already renamed): $FILE"
    continue
  fi

  # Get bitrate
  BITRATE=$(mediainfo --Inform="Video;%BitRate%" "$FILE")

  if [ -z "$BITRATE" ]; then
    echo "Skipping (no bitrate found): $FILE"
    continue
  fi

  KBPS=$((BITRATE / 1000))
  NEW_NAME="${NAME}-${KBPS}kbps.${EXT}"
  NEW_PATH="${DIR}/${NEW_NAME}"

  if [ "$FILE" != "$NEW_PATH" ]; then
    if $DRY_RUN; then
      echo "[Dry run] Would rename '$FILE' → '$NEW_PATH'"
    else
      echo "Renaming '$FILE' → '$NEW_PATH'"
      mv "$FILE" "$NEW_PATH"
    fi
  fi
done