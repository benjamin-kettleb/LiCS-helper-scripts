#!/usr/bin/env bash

frame=$(basename "$PWD")
track="${frame:0:3}"
BASE_DIR="$LiCSAR_public/$track/$frame/interferograms"
output_file="$frame.ifg_to_ignore"

# Parse arguments
while getopts "i:o:a:" opt; do
  case $opt in
    i) INPUT_FILE="$OPTARG" ;;
    o) output_file="$OPTARG" ;;
    a) append_to_ignore="$OPTARG" ;;
    *) echo "Usage: $0 -i list_to_include -a list_to_ignore -o output_ignore_list"; exit 1 ;;
  esac
done

: > "$output_file"  # clears file

echo "$BASE_DIR"


# Check input file exists
if [[ -z "$INPUT_FILE" || ! -f "$INPUT_FILE" ]]; then
  echo "Error: Input file not provided or does not exist"
  exit 1
fi

# Read directory names (only top-level directories, not files)
mapfile -t dir_list < <(find "$BASE_DIR" -maxdepth 1 -mindepth 1 -type d -printf "%f\n" | sort)

# Read input file lines
mapfile -t input_list < <(sort "$INPUT_FILE")

# Compare: print dirs not in input file
comm -23 <(printf "%s\n" "${dir_list[@]}") <(printf "%s\n" "${input_list[@]}") > "$output_file"

if [[ ! -z "$append_to_ignore" && -f "$append_to_ignore" ]]; then
  echo "Copying ifgs from $append_to_ignore to $output_file"
  cat "$append_to_ignore" >> "$output_file"
elif [[ ! -z "$append_to_ignore" && ! -f "$append_to_ignore"  ]]; then
  echo "file $append_to_ignore does not exist so not appending"
  echo "to append manually type:"
  echo "cat ignore_list_to_append >> $output_file "
fi
echo "Successfully created $output_file"
