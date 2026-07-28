#!/bin/bash

# Check if input path is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <path_to_TS_GEOCml1directory>"
  exit 1
fi

# Get the full input path
input_path="$1"

# Extract base directory and subdirectory names
base_dir=$(basename "$(dirname "$input_path")")
ts_dir=$(basename "$input_path")
geo_dir="${ts_dir#TS_}"

# Define target base path in home directory
target_base="$HOME/$base_dir"

# Create necessary directories
mkdir -p "$target_base/$ts_dir"
mkdir -p "$target_base/$ts_dir/results"
mkdir -p "$target_base/$geo_dir"

echo "Copying files across"

# Copy files
# cp "$base_dir/$base_dir.vel.mskd.kmz" "$target_base/$base_dir.vel.mskd.kmz"
cp "$input_path"/*.h5 "$target_base/$ts_dir/"
cp -r "$input_path/results/hgt" "$target_base/$ts_dir/results/"
cp -r "$input_path/results/coh_avg" "$target_base/$ts_dir/results/"
cp "$base_dir/${geo_dir}/U.geo" "$target_base/$geo_dir/"
cp "$base_dir/${geo_dir}/N.geo" "$target_base/$geo_dir/"
cp "$base_dir/${geo_dir}/E.geo" "$target_base/$geo_dir/"

# Create tempory cum_filt so its not overwritten
#temp_dir="$base_dir/TS_TEMP"
#mkdir -p "$temp_dir"

temp_cum_filt="$input_path/cum_filt_copy.h5"
cum_filt="$input_path/cum_filt.h5"
cp  "$cum_filt" "$temp_cum_filt"


# Define the path to the Python script
LICSBAS_SCRIPT="LiCSBAS16_filt_ts.py --n_para 5"

# Run with -r 1
echo "$LICSBAS_SCRIPT -t $input_path -r 1"
$LICSBAS_SCRIPT -t "$input_path" -r 1
cp "$input_path/cum_filt.h5" "$target_base/$ts_dir/cum_filt_ramp.h5"

# Run with --hgt_linear
echo "$LICSBAS_SCRIPT -t $input_path --hgt_linear"
$LICSBAS_SCRIPT -t "$input_path" --hgt_linear
cp "$input_path/cum_filt.h5" "$target_base/$ts_dir/cum_filt_hgt.h5"

# Run with both -r 1 and --hgt_linear
echo "$LICSBAS_SCRIPT -t $input_path -r 1 --hgt_linear"
$LICSBAS_SCRIPT -t "$input_path" -r 1 --hgt_linear
cp "$input_path/cum_filt.h5" "$target_base/$ts_dir/cum_filt_ramp_hgt.h5"

cp "$temp_cum_filt" "$cum_filt"
rm "$temp_cum_filt"
