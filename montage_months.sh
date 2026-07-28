#!/bin/bash



# Run in directory containing image files for each interferogram (e.g. 20191112_20191118.geo.unw.png).
# Will create a montage image for each month.



for i in `ls 2*`; do basename $i; done > pairs.txt



while read i; do awk '{print substr($1,1,6)}' | sort -u; done < pairs.txt > months.txt



while read i; do montage -label '%f' -geometry 400x400x10x10 $i*.png montage_$i.png; echo $i; done < months.txt
