#!/bin/bash
set -e

GEOC_DIR="./GEOC"
OUTPUT_DIR="./GEOC_existing"
EMPTY_DIR="./GEOC_empty"


frame=$(basename "$PWD")
track="${frame:0:3}"
interf_dir="$LiCSAR_public/$track/$frame/interferograms"

mkdir -p "$OUTPUT_DIR"

# Build temp files for candidate names and interferogram names
tmp_geoc=$(mktemp)
tmp_interf=$(mktemp)

# List GEOC dirs matching XXXXXXXX_XXXXXXXX quickly using find
#find "$GEOC_DIR" -maxdepth 1 -type d -regex ".*/[0-9]\{8\}_[0-9]\{8\}" -printf "%f\n" > "$tmp_geoc"
find "$GEOC_DIR" -maxdepth 1 -type d -printf "%f\n" > "$tmp_geoc"
find "$GEOC_DIR" -maxdepth 1 -type l -printf "%f\n" > "$tmp_geoc"

# List interferogram directories
find "$interf_dir" -maxdepth 1 -type d -printf "%f\n" > "$tmp_interf"

# Compute intersection (existing in both)
matches=$(grep -Fx -f "$tmp_interf" "$tmp_geoc" || true)

for base in $matches; do
    echo "Moving $base"
    mv "$GEOC_DIR/$base" "$OUTPUT_DIR/"
done

rm "$tmp_geoc" "$tmp_interf"

echo "Removed duplicates"

#find "$GEOC_DIR" -type d -empty -delete

#echo "Removed empty"

echo "Done."
