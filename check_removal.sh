#!/usr/bin/env bash

# Check arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <frame> <remove_list>"
    exit 1
fi

frame="$1"
frame_remove_list="$2"

# First 3 characters of the frame are the track number
track="${frame:0:3}"

# Root of the LiCSAR_public directory (assumed already exported)
if [ -z "$LiCSAR_public" ]; then
    echo "ERROR: LiCSAR_public environment variable is not set."
    echo "Please export it before running:"
    echo "    export LiCSAR_public=/path/to/LiCSAR_public"
    exit 1
fi

interferogram_dir="$LiCSAR_public/$track/$frame/interferograms"

echo "Checking IFGs listed in: $frame_remove_list"
echo "Location searched:       $interferogram_dir"
echo ""

# Check directory exists
if [ ! -d "$interferogram_dir" ]; then
    echo "ERROR: Directory does not exist:"
    echo "    $interferogram_dir"
    exit 1
fi

echo "Results:"
echo "--------"

while read -r ifg; do
    # skip empty lines
    [ -z "$ifg" ] && continue

    if [ -d "$interferogram_dir/$ifg" ]; then
        echo "FOUND      $ifg"
    else
        echo "NOT FOUND  $ifg"
    fi
done < "$frame_remove_list"
