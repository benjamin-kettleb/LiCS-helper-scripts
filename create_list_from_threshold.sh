#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 [-l] [-c num_cand] [-d delimiter] [-f frame] [-o output_file] list threshold"
  echo " -l             Cutoff less than threshold (default greater than"
  echo " -c num_cand    number of "candidates" beyond threshold to also montage. Default 0"
  echo " -d delimiter   delimiter seperating ifg from value in list. Default tab"
  echo " -f frame       frame of ifgs. Default name of dir."
  echo " -o output_file filename for output file to which cutoff files are APPENDED." 
  echo " list           list of ifg and values (produced by create_sorted_to_check.py)"
  echo " threshold      the cutoff threshold for values (use evaluate_lists.py to estimate)"
}

#DEFUALTS:
less_than=0
num_cand=0
delimiter=$'\t'
frame=$(basename "$PWD")
output_file=0

while getopts "lc:d:f:o:" opt; do
  case "$opt" in
    l) less_than=1 ;;
    c) num_cand="$OPTARG" ;;
    d) delimiter="$OPTARG" ;;
    f) frame="$OPTARG" ;;
    o) output_file="$OPTARG" ;;
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

if [ "$output_file" -eq 0 ]; then
  if [ "$less_than" -eq 0 ]; then
     a_or_b="above"
  else
     a_or_b="below"
  fi
  output_file="$frame.$a_or_b"
  output_file+="_$threshold"
fi
num_beyond=0 #keeps track of num beyond threshold

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
      echo "$value is less than threshold $threshold (We are discarding Above threshold)"
    fi
  else
    if (( $(echo "$value > $threshold" | bc -l) )); then
      num_beyond=$(($num_beyond+1))
      echo "$value is greater then threshold $threshold (we are discarding below threhold)"
    fi
  fi
  echo "num_beyond - $num_beyond, num_cand - $num_cand"
  #Check if we are beyond num_cand
  if [ $num_beyond -gt $num_cand ]; then
    echo "break hit"
    break
  fi
  echo $ifg >> $output_file
done
