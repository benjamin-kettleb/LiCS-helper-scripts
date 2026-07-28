#!/usr/bin/env bash

## Originally written by Dr. Jess Payne, edited by Benji Kettleborough :)

# Argument parsing
if [ -z "${frame+x}" ]; then
    frame="$1"
fi

if [ -z "${frame_remove_list+x}" ]; then
    frame_remove_list="$2"
fi

if [ -z "$frame" ] || [ -z "$frame_remove_list" ]; then
    echo "Usage: $0 <frame> <remove_list>"
    exit 1
fi

track="${frame:0:3}"

echo -e "Deleting from LiCSAR_public/$track/$frame the IFGs listed in $frame_remove_list\n"
echo -e "IFGs to remove:\n"
cat "$frame_remove_list"
echo -e "\nGiving 5 seconds to cancel...\n"
sleep 5

echo "Deleting IFGs..."
while read -r ifg; do
    remove_from_lics.sh "$frame" "$ifg"
done < "$frame_remove_list"

echo "Done!"
