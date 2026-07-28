#!/bin/bash
tienshan=0
volcs_south=0
ADD36M=1
ifg_combinations=4
MAXBTEMP=181

while getopts "TSn:" option; do
    case "$option" in
        T)
            tienshan=1
            echo "tienshan method being used"
            ;;
        S)
            volcs_south=1
            echo "South American volcano method being used"
            ;;
        n)
            ifg_combinations=$OPTARG
            echo "setting number of ifg combinations per epoch to "$OPTARG;
            ;;
     esac
done

shift $((OPTIND - 1))

if [ ! -z $2 ]; then MAXBTEMP=$2; fi


if [ $tienshan -eq 1 ]; then
    if [ $volcs_south -eq 1 ]; then
        tienshan=0
    fi
fi


rm -r gapfill_job 2>/dev/null
mkdir gapfill_job

frame=$(basename "$PWD")
track="${frame:0:3}"

metadata_file=$LiCSAR_public/$track/$frame/metadata/metadata.txt
master=$(grep '^master=' "$metadata_file" | cut -d= -f2)
echo "$master"

#ls $LiCSAR_public/$track/$frame/epochs/20??????/*geo.mli.tif | cut -d '/' -f2 > gapfill_job/tmp_rslcs

#find $LiCSAR_public/$track/$frame/epochs/20??????/*geo.mli.tif -type f | while IFS= read -r file; do
#    # Get the parent directory name
#    parent_dir=$(basename "$(dirname "$file")")
#    echo "$parent_dir"
#done > gapfill_job/tmp_rslcs

find $LiCSAR_public/$track/$frame/epochs/20?????? -type d | while IFS= read -r file; do
    # Get the parent directory name
    current_dir=$(basename "$file")
    echo "$current_dir"
done > gapfill_job/tmp_rslcs


# prepare the 5 combinations in a row
echo "Establishing "$ifg_combinations" consecutive pairs within max Btemp of "$MAXBTEMP" days"
for FIRST in `cat gapfill_job/tmp_rslcs`; do 
    for i in `seq 1 $ifg_combinations`; do
        last=`grep -A$i $FIRST gapfill_job/tmp_rslcs | tail -n1`;
        if [ `datediff $FIRST $last` -lt $MAXBTEMP ] && [ ! $FIRST == $last ]; then
            echo $FIRST'_'$last >> gapfill_job/tmp_ifg_all2;
        fi
    done 
done


if [ $volcs_south -eq 1 ]; then
    echo "preparing S American volcs connections (all Dec-Feb up to 1 yr)"
    rm gapfill_job/tmp_selrslcs 2>/dev/null
    for rslc in `cat gapfill_job/tmp_rslcs`; do
        if [ ${rslc:4:2} == '11' ] || [ ${rslc:4:2} == '12' ] || [ ${rslc:4:2} == '01' ] || [ ${rslc:4:2} == '02' ] || [ ${rslc:4:2} == '03' ]; then
            echo $rslc >> gapfill_job/tmp_selrslcs
            #echo $rslc
        fi
    done
    echo "Finished first loop"
    for rslc in `cat gapfill_job/tmp_selrslcs`; do
        echo "RSLC 1 - "$rslc
        for rslc2 in `cat gapfill_job/tmp_selrslcs`; do
            if [ $rslc2 -gt $rslc ]; then
                if [ `datediff $rslc $rslc2` -lt 90 ]; then
                    echo $rslc'_'$rslc2 >> gapfill_job/tmp_ifg_all2
                    echo "RSLC 2 - "$rslc2
                elif [ `datediff $rslc $rslc2` -lt 456 ]; then
                    echo $rslc'_'$rslc2 >> gapfill_job/tmp_ifg_all2
                    echo "RSLC 2 - "$rslc2
                fi
            fi
        done
    done
fi


if [ $tienshan -eq 1 ]; then
    echo "preparing Tien Shan connections"
    # Pick month to start connections from. Default to May unless stated
    if [ `grep -c startmonth $LiCSAR_procdir/$track/$frame/local_config.py 2>/dev/null` -gt 0 ]; then
       startmonth=`grep ^startmonth $LiCSAR_procdir/$track/$frame/local_config.py | cut -d '=' -f2 | sed 's/ //g'`
    else
       startmonth=5
    fi
    MONTHS=(ZERO Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
    echo 'Start Month:' ${MONTHS[$startmonth]}
    
    maxconn=100
    first=`head -n2 gapfill_job/tmp_rslcs | tail -n1`
    last=`tail -n2 gapfill_job/tmp_rslcs | head -n1`
    if [ `datediff $first $last` -gt 89 ]; then
      cp gapfill_job/tmp_rslcs gapfill_job/long_rslcs
    fi
    #do 
    for year in `cat gapfill_job/long_rslcs | cut -c -4 | sort -u`; do
        let year1=$year
        let year2=$year+1
        #let year3=$year+2
        #3 months connections
        rm gapfill_job/long_ifgs 2>/dev/null
        #for month1 in 5 6 7 8; do
        for month1 in `seq $startmonth $(expr $startmonth + 3)`; do
            let month2=$month1+3
            # Reformat months to be 01-12
            if [ $month1 -gt 12 ]; then let month1=$month1-12; let year1=$year+1; fi 
            if [ $month1 -lt 10 ]; then month1='0'$month1; fi
            if [ $month2 -gt 12 ]; then let month2=$month2-12; let year2=$year+1; fi
            if [ $month2 -lt 10 ]; then month2='0'$month2; fi
            for firstdate in `grep ^$year1$month1 gapfill_job/long_rslcs`; do
                for lastdate in `grep ^$year2$month2 gapfill_job/long_rslcs`; do
                    echo $firstdate'_'$lastdate >> gapfill_job/long_ifgs
                done
            done
        done
        if [ -f gapfill_job/long_ifgs ]; then
            shuf gapfill_job/long_ifgs | head -n $maxconn >> gapfill_job/tmp_ifg_all2
        fi
       
       
        #6 months connections: May, Nov
        rm gapfill_job/long_ifgs 2>/dev/null
        #for month1 in 5 11; do
        for month1 in $startmonth $(expr $startmonth + 6); do 
            let month2=$month1+6
            let year1=$year
            let year2=$year
            if [ $month1 -gt 12 ]; then let month1=$month1-12; let year1=$year+1; fi 
                if [ $month2 -gt 12 ]; then let month2=$month2-12; let year2=$year+1; fi
                if [ $month1 -lt 10 ]; then month1='0'$month1; fi
                if [ $month2 -lt 10 ]; then month2='0'$month2; fi
                for firstdate in `grep ^$year1$month1 gapfill_job/long_rslcs`; do
                    for lastdate in `grep ^$year2$month2 gapfill_job/long_rslcs`; do
                        echo $firstdate'_'$lastdate >> gapfill_job/long_ifgs
                    done
                done
        done
        if [ -f gapfill_job/long_ifgs ]; then
            shuf gapfill_job/long_ifgs | head -n $maxconn >> gapfill_job/tmp_ifg_all2
        fi
       
       
        #9 months connections: Aug, Sep, Oct, Nov
        rm gapfill_job/long_ifgs 2>/dev/null
        #for month1 in 8 9 10 11; do
        for month1 in `seq $(expr $startmonth + 3) $(expr $startmonth + 6)`; do
            let month2=$month1+9
            let year1=$year
            let year2=$year
            if [ $month1 -gt 12 ]; then let month1=$month1-12; let year1=$year+1; fi
            if [ $month2 -gt 12 ]; then let month2=$month2-12; let year2=$year+1; fi
            if [ $month1 -lt 10 ]; then month1='0'$month1; fi
            if [ $month2 -lt 10 ]; then month2='0'$month2; fi
            for firstdate in `grep ^$year1$month1 gapfill_job/long_rslcs`; do
                for lastdate in `grep ^$year2$month2 gapfill_job/long_rslcs`; do
                    echo $firstdate'_'$lastdate >> gapfill_job/long_ifgs
                done
            done
        done
        if [ -f gapfill_job/long_ifgs ]; then
            shuf gapfill_job/long_ifgs | head -n $maxconn >> gapfill_job/tmp_ifg_all2
        fi

        #12 months connections: May, Jun, Jul, Aug, Sep, Oct, Nov
        rm gapfill_job/long_ifgs 2>/dev/null
        #for month1 in 5 6 7 8 9 10 11; do
        for month1 in `seq $startmonth $(expr $startmonth + 6)`; do
	        let year1=$year
            if [ $month1 -gt 12 ]; then let month1=$month1-12; let year1=$year+1; fi
            let year2=$year1+1 
            let month2=$month1
            if [ $month1 -lt 10 ]; then month1='0'$month1; fi

            #         let month2=$month1
            #         let year2=$year+1
            #         if [ $month1 -lt 10 ]; then month1='0'$month1; fi
            #         if [ $month2 -lt 10 ]; then month2='0'$month2; fi
            for firstdate in `grep ^$year1$month1 gapfill_job/long_rslcs`; do
                for lastdate in `grep ^$year2$month2 gapfill_job/long_rslcs`; do
                    echo $firstdate'_'$lastdate >> gapfill_job/long_ifgs
                done
            done
        done
        if [ -f gapfill_job/long_ifgs ]; then
            shuf gapfill_job/long_ifgs | head -n $maxconn >> gapfill_job/tmp_ifg_all2
        fi
    done;

else
    if [ $ADD36M -eq 1 ]; then
        maxconn=5
        #now, add 3 and 6 months data
        first=`head -n2 gapfill_job/tmp_rslcs | tail -n1`
        last=`tail -n2 gapfill_job/tmp_rslcs | head -n1`
        if [ `datediff $first $last` -gt 89 ]; then
            echo "about to sed"
            sed '/'$master'/d' gapfill_job/tmp_rslcs | grep 0[3,6,9][0-3][0-9] > gapfill_job/long_rslcs
            echo "Just sedded"
            if [ `cat gapfill_job/long_rslcs | wc -l` -gt 1 ]; then
            echo "preparing 3/6 months connections"
                for year in `cat gapfill_job/long_rslcs | cut -c -4 | sort -u`; do
                #march connections
                    for secmon in 6 9; do
                        rm gapfill_job/long_ifgs 2>/dev/null
                        for march in `grep $year'03' gapfill_job/long_rslcs`; do
                            #connections with june and sep
                            for LAST in `grep $year'0'$secmon gapfill_job/long_rslcs`; do
                            echo $march'_'$LAST >> gapfill_job/long_ifgs
                        done
                    done
                    #do max connections per episode
                    if [ -f gapfill_job/long_ifgs ]; then
                        shuf gapfill_job/long_ifgs | head -n $maxconn >> gapfill_job/tmp_ifg_all2
                    fi
                done
                #june connections with sep
                rm gapfill_job/long_ifgs 2>/dev/null
                for june in `grep $year'06' gapfill_job/long_rslcs`; do
                        #connections with june and sep
                        for LAST in `grep $year'09' gapfill_job/long_rslcs`; do
                        echo $june'_'$LAST >> gapfill_job/long_ifgs
                        done
                done
                if [ -f gapfill_job/long_ifgs ]; then
                    shuf gapfill_job/long_ifgs | head -n $maxconn >> gapfill_job/tmp_ifg_all2
                fi
                
                #sep connections with march next year
                rm gapfill_job/long_ifgs 2>/dev/null
                let year2=$year+1
                for sep in `grep $year'09' gapfill_job/long_rslcs`; do
                    for LAST in `grep $year2'03' gapfill_job/long_rslcs`; do
                        echo $sep'_'$LAST >> gapfill_job/long_ifgs
                    done
                done
                if [ -f gapfill_job/long_ifgs ]; then
                    shuf gapfill_job/long_ifgs | head -n $maxconn >> gapfill_job/tmp_ifg_all2
                fi

                #sep connections with june next year
                rm gapfill_job/long_ifgs 2>/dev/null
                let year2=$year+1
                for sep in `grep $year'09' gapfill_job/long_rslcs`; do
                    for LAST in `grep $year2'06' gapfill_job/long_rslcs`; do
                        echo $sep'_'$LAST >> gapfill_job/long_ifgs
                    done
                done
                if [ -f gapfill_job/long_ifgs ]; then
                    shuf gapfill_job/long_ifgs | head -n $maxconn >> gapfill_job/tmp_ifg_all2
                fi
       
                # added in 07/2021 - also 12 month connections..
                #sep connections with sep next year
                rm gapfill_job/long_ifgs 2>/dev/null
                let year2=$year+1
                for sep in `grep $year'09' gapfill_job/long_rslcs`; do
                    for LAST in `grep $year2'09' gapfill_job/long_rslcs`; do
                        echo $sep'_'$LAST >> gapfill_job/long_ifgs
                    done
                done
                if [ -f gapfill_job/long_ifgs ]; then
                    shuf gapfill_job/long_ifgs | head -n $maxconn >> gapfill_job/tmp_ifg_all2
                fi
                #mar connections with mar next year
                rm gapfill_job/long_ifgs 2>/dev/null
                let year2=$year+1
                for sep in `grep $year'03' gapfill_job/long_rslcs`; do
                    for LAST in `grep $year2'03' gapfill_job/long_rslcs`; do
                        echo $sep'_'$LAST >> gapfill_job/long_ifgs
                    done
                done
                if [ -f gapfill_job/long_ifgs ]; then
                    shuf gapfill_job/long_ifgs | head -n $maxconn >> gapfill_job/tmp_ifg_all2
                fi
                #june connections with mar next year
                rm gapfill_job/long_ifgs 2>/dev/null
                let year2=$year+1
                for sep in `grep $year'06' gapfill_job/long_rslcs`; do
                    for LAST in `grep $year2'03' gapfill_job/long_rslcs`; do
                        echo $sep'_'$LAST >> gapfill_job/long_ifgs
                    done
                done
                if [ -f gapfill_job/long_ifgs ]; then
                    shuf gapfill_job/long_ifgs | head -n $maxconn >> gapfill_job/tmp_ifg_all2
                fi
       
                #june connections with june next year
                rm gapfill_job/long_ifgs 2>/dev/null
                let year2=$year+1
                for sep in `grep $year'06' gapfill_job/long_rslcs`; do
                    for LAST in `grep $year2'06' gapfill_job/long_rslcs`; do
                        echo $sep'_'$LAST >> gapfill_job/long_ifgs
                    done
                done
                if [ -f gapfill_job/long_ifgs ]; then
                    shuf gapfill_job/long_ifgs | head -n $maxconn >> gapfill_job/tmp_ifg_all2
                fi
                done #WHAT IS THIS FOR???????
            fi
        fi
    fi
fi

# adding from the txt file here:
if [ ! -z $ifglist ]; then
 cat $ifglist >> gapfill_job/tmp_ifg_all2
fi

#cat gapfill_job/tmp_ifg_all2 | head -n-5 | sort -u > gapfill_job/tmp_ifg_all
cat gapfill_job/tmp_ifg_all2 | sort -u > gapfill_job/tmp_ifg_all # this is the important file with ALL ifgs..

mv gapfill_job/tmp_ifg_all ./$frame.standard_ifgs
mv gapfill_job/tmp_rslcs ./$frame.epochs
rm -rf gapfill_jobs
