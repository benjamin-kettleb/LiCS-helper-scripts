#!/bin/bash
# Make montages of all newly generated ifgs. Run in GEOC.
# Andrew Watson 2022-02-15



mkdir tocheck
find -type d -name "2*_2*" | awk '{print substr($1,3,17)}' > tocheck/new_ifgs.txt
echo "found"
cd tocheck/
for ifg in `cat new_ifgs.txt`; do ln -s `readlink -f ../$ifg/$ifg.geo.unw.png` .; done
$LiCS_helper_scripts/montage_months.sh
