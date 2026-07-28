#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 [-l] [-c num_cand] [-d delimiter] [-f frame] list threshold"
  echo " -l		Cutoff less than threshold (default greater than"
  echo " -c num_cand	number of "candidates" beyond threshold to also montage. Default 10"
  echo " -d delimiter	delimiter seperating ifg from value in list. Default tab"
  echo " -f frame	frame of ifgs. Default name of dir."
  echo " list		list of ifg and values (produced by create_sorted_to_check.py)"
  echo " threshold	the cutoff threshold for values (use evaluate_lists.py to estimate)"
}

#DEFUALTS:
less_than=0
num_cand=10
delimiter=$'\t'
frame=$(basename "$PWD")

while getopts "lc:d:f:" opt; do
  case "$opt" in
    l) less_than=1 ;;
    c) num_cand="$OPTARG" ;;
    d) delimiter="$OPTARG" ;;
    f) frame="$OPTARG" ;;
    \?) echo "Invalid option: -$opt" >&2; usage ;;
    :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
  esac
done

# Remove parsed options from $@
shift $((OPTIND - 1))

# Check positional arguments
if [ $# -ne 2 ]; then
  echo "Error: Missing positional arguments."
  usage
fi

list="$1"
threshold="$2"
track="${frame:0:3}"

num_beyond=0 #keeps track of num beyond threshold

mkdir -p tocheck
mapfile -t lines < "$list"

echo "lines - $lines"

for line in "${lines[@]}"; do
  IFS="$delimiter" read -ra fields <<< "$line"
  
  #printf 'LINE: "%s"\n' "$line"
  #printf 'FIELDS (%d): [%s]\n' "${#fields[@]}" "${fields[*]}"

  ifg="${fields[0]}"
  value="${fields[1]}"
  
  #echo "DEBUG ifg='$ifg', value='$value'"
  #echo "ifg - $ifg, value - $value"  
  if [ "$less_than" -eq 0 ]; then
    if (( $(echo "$value < $threshold" | bc -l) )); then
      num_beyond=$(($num_beyond+1))
      echo "$value is Less than threshold $threshold (We are discarding above threshold)"
    fi
  else
    if (( $(echo "$value > $threshold" | bc -l) )); then
      num_beyond=$(($num_beyond+1))
      echo "$value is greater then threshold $threshold (we are discarding below threshold)"
    fi
  fi
  echo "num_beyond - $num_beyond, num_cand - $num_cand"
  #Check if we are beyond num_cand
  if [ $num_beyond -gt $num_cand ]; then
    echo "break hit"
    break
  fi
  #softlink png
  #echo "softlinking $LiCSAR_public/$track/$frame/interferograms/$ifg/$ifg.geo.unw.png"
  #ln -s "$(readlink -f "$LiCSAR_public/$track/$frame/interferograms/$ifg/$ifg.geo.unw.png")" "./tocheck/$ifg.geo.unw.png"

  src_dir="$LiCSAR_public/$track/$frame/interferograms/$ifg"
  dst_dir="./tocheck"
  
  png="$src_dir/$ifg.geo.unw.png"
  tif="$src_dir/$ifg.geo.unw.tif"
  
  out_png="$dst_dir/$ifg.geo.unw.png"
  tmp_tif="$dst_dir/$ifg.geo.unw.tif"
  
  mkdir -p "$dst_dir"
  
  if [[ -f "$png" ]]; then
    # PNG exists → just link it
    ln -sf "$(readlink -f "$png")" "$out_png"
    echo "Linking png"
    
  elif [[ -f "$tif" ]]; then
    # PNG missing, TIFF exists
    ln -sf "$(readlink -f "$tif")" "$tmp_tif"
    echo "Linking tif"
    
    # Convert TIFF → PNG
    #gdal_translate -of PNG "$tmp_tif" "$out_png"
    gdal_translate -of PNG -ot UInt16 -scale "$tmp_tif" "$out_png"
    


    # Remove temporary TIFF link
    rm "$tmp_tif"
    
  else
    echo "Neither PNG nor TIF exists for $ifg" >&2
  fi

done

cd tocheck

$LiCS_helper_scripts/montage_months.sh
