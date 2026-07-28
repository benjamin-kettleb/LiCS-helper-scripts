cd GEOC

frame=$1
track=`echo $frame | cut -c -3 | sed 's/^0//' | sed 's/^0//'`
metadir=$LiCSAR_public/$track/$frame/metadata
epochdir=$LiCSAR_public/$track/$frame/epochs

for meta in E N U hgt; do
  # echo "Getting metafiles from metadir everytime!"  ## ML: Muhammet, please.. at least keep orig lines commented or ask.. no idea why you so much needed to remove this part
  #
  # echo "ML: whatever this means (Muhammet..) - note clips stopped working with this change, trying to find how to fix it"
if [ `ls *.geo.$meta.tif 2>/dev/null | wc -l` -lt 1 ]; then
 if [ -f lookangles/$master.geo.$meta.tif ]; then
  # echo "getting metafiles from GEOC/lookangles" # - might need updating in future"
  ln -s `pwd`/lookangles/$master.geo.$meta.tif `pwd`/$master.geo.$meta.tif
 elif [ -f geo/$frame.geo.$meta.tif ]; then
  ln -s `pwd`/geo/$frame.geo.$meta.tif `pwd`/$frame.geo.$meta.tif
 else
  # ln -s $metadir/$frame.geo.$meta.tif
  cp $metadir/$frame.geo.$meta.tif .
 fi
 # ln -sf "$metadir/$frame.geo.$meta.tif" "$frame.geo.$meta.tif"
fi

done

cp $metadir/baselines .
cp $metadir/metadata.txt .

source metadata.txt

cp $epochdir/$master/$master.geo.mli.tif .
