#!/usr/bin/env bash

set -euo pipefail

# ---- Check input ----
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 /path/to/folder"
  exit 1
fi

INPUT_DIR="$1"

if [ ! -d "$INPUT_DIR" ]; then
  echo "Error: '$INPUT_DIR' is not a directory."
  exit 1
fi

# ---- Build output directory (sibling with (EAC3)) ----
PARENT_DIR="$(dirname "$INPUT_DIR")"
BASENAME="$(basename "$INPUT_DIR")"
OUTPUT_DIR="${PARENT_DIR}/${BASENAME} (EAC3)"

mkdir -p "$OUTPUT_DIR"

echo "Input folder : $INPUT_DIR"
echo "Output folder: $OUTPUT_DIR"
echo

# ---- Process files ----
shopt -s nullglob

for INPUT_PATH in "$INPUT_DIR"/*; do
  # Skip if not a regular file
  [ -f "$INPUT_PATH" ] || continue

  FILENAME="$(basename "$INPUT_PATH")"
  NAME_NO_EXT="${FILENAME%.*}"
  EXT="${FILENAME##*.}"

  OUTPUT_PATH="${OUTPUT_DIR}/${NAME_NO_EXT}.${EXT}"

  echo "Processing: $FILENAME"

  ffmpeg -hide_banner -loglevel error -stats \
    -i "$INPUT_PATH" \
    -map 0 \
    -map -0:a:1 \
    -map -0:a:2 \
    -map -0:a:3 \
    -map -0:a:4 \
    -map -0:a:5 \
    -c:v copy \
    -c:s copy \
    -c:a eac3 -b:a 640k \
    -map_metadata 0 \
    -map_chapters 0 \
    "$OUTPUT_PATH"

  echo "Done -> $OUTPUT_PATH"
  echo
done

echo "All files processed 🎉"