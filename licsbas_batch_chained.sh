#!/bin/bash -eu

# LiCSBAS Jasmin Job Submission Script
# This script generates and submits jobs to Jasmin with dependencies
# 
# Job structure:
#  - Jasmin_LB_01.sh (Step 1)
#  - Jasmin_LB_02_11.sh (Steps 2-11)
#  - Jasmin_LB_12.sh (Step 12)
#  - Jasmin_LB_13.sh (Step 13)
#  - Jasmin_LB_14_16.sh (Steps 14-16)
#
# LiCSBAS steps:
#  01: LiCSBAS01_get_geotiff.py
#  02to05: LiCSBAS02to05_unwrap.py   or   02: LiCSBAS02_ml_prep.py
#                                         03: LiCSBAS03op_GACOS.py (optional)
#                                         04: LiCSBAS04op_mask.py (optional)
#                                         05: LiCSBAS05op_clip_unw.py (optional)
#  11: LiCSBAS11_check_unw.py
#  (optional) 120: LiCSBAS120_choose_reference.py
#  12: LiCSBAS12_loop_closure.py
#  13: LiCSBAS13_sb_inv.py
#  14: LiCSBAS14_vel_std.py
#  15: LiCSBAS15_mask_ts.py
#  16: LiCSBAS16_filt_ts.py

#################
### Settings ####
#################
start_step="01"	# 01-05, 11-16
end_step="16"	# 01-05, 11-16

## Jasmin Default Configuration ##
JASMIN_QOS_DEFAULT="high"		# Default QOS queue: normal, high, long, etc.
JASMIN_TIME_DEFAULT="24:00:00"		# Default time limit (HH:MM:SS)
JASMIN_MEM_DEFAULT="16G"			# Default memory limit
JASMIN_CPUS_DEFAULT="6"			# Default number of CPUs per job

## Per-step Overrides (leave blank to use defaults above) ##
JASMIN_TIME_STEP1=""			# Leave blank to use JASMIN_TIME_DEFAULT
JASMIN_TIME_STEP2_11=""			# Leave blank to use JASMIN_TIME_DEFAULT
JASMIN_TIME_STEP12=""			# Leave blank to use JASMIN_TIME_DEFAULT
JASMIN_TIME_STEP13=""			# Leave blank to use JASMIN_TIME_DEFAULT
JASMIN_TIME_STEP14_16=""		# Leave blank to use JASMIN_TIME_DEFAULT
JASMIN_MEM_STEP1=""			# Leave blank to use JASMIN_MEM_DEFAULT
JASMIN_MEM_STEP2_11=""			# Leave blank to use JASMIN_MEM_DEFAULT
JASMIN_MEM_STEP12=""			# Leave blank to use JASMIN_MEM_DEFAULT
JASMIN_MEM_STEP13=""			# Leave blank to use JASMIN_MEM_DEFAULT
JASMIN_MEM_STEP14_16=""			# Leave blank to use JASMIN_MEM_DEFAULT
JASMIN_CPUS_STEP1=""			# Leave blank to use JASMIN_CPUS_DEFAULT
JASMIN_CPUS_STEP2_11=""			# Leave blank to use JASMIN_CPUS_DEFAULT
JASMIN_CPUS_STEP12=""			# Leave blank to use JASMIN_CPUS_DEFAULT
JASMIN_CPUS_STEP13=""			# Leave blank to use JASMIN_CPUS_DEFAULT
JASMIN_CPUS_STEP14_16=""		# Leave blank to use JASMIN_CPUS_DEFAULT
SUBMIT_JOBS="y"				# y/n. Set to 'y' to submit jobs to Jasmin, 'n' to only generate scripts

## Data Source Configuration ##
LINK_GEOC_DATA="y"			# y/n. If 'y', symlink existing GEOC data instead of downloading. If 'n', download from LiCSAR.
GEOC_LINK_SOURCE=""			# Path to existing GEOC directory. If empty and LINK_GEOC_DATA='y', will auto-derive from $LiCSAR_public/track/frame/GEOC

cometdev='0' # shortcut to use COMET's experimental/dev functions. At this moment, '1' will turn on the nullification. Recommended: 0
eqoffs="n"  # if 'y', it will do: get_eq_offsets, then invert. if singular_gauss, then set use of model (not recommended now, experimental/need some work).
nlook="1"	# multilook factor, used in step02
GEOCmldir="GEOCml${nlook}"	# If start from 11 or later after doing 03-05, use e.g., GEOCml${nlook}GACOSmaskclip
n_para="" # Number of parallel processing in step 02-05,12,13,16. default: number of usable CPU
gpu="n"	# y/n
check_only="n" # y/n. If y, not run scripts and just show commands to be done

logdir="log"
log="$logdir/$(date +%Y%m%d%H%M)$(basename $0 .sh)_${start_step}_${end_step}.log"

freq="" # default: 5.405e9 Hz

### Running the updated pipelines:
run_reunwrapping='n' # y/n. default: 'n'. Reunwrapping would use 02to05 script instead of the original 02[,03,04,05]

### Optional steps (03-05) ###
order_op03_05="03 04 05"	# can change order e.g., 05 03 04
do03op_GACOS="n"	# y/n
do04op_mask="n"	# y/n
do05op_clip="n"	# y/n
p04_mask_coh_thre_avg=""	# e.g. 0.2
p04_mask_coh_thre_ifg=""	# e.g. 0.2
p04_mask_range=""	# e.g. 10:100/20:200 (ix start from 0)
p04_mask_range_file=""	# Name of file containing range list
p05_clip_range=""	# e.g. 10:100/20:200 (ix start from 0)
p05_clip_range_geo=""	# e.g. 130.11/131.12/34.34/34.6 (in deg)

# Optional reunwrapping:
p02to05_freq=$freq # default: 5.405e9 Hz
p02to05_gacos="" # y/n. default: 'y'. Use gacos data if available (for majority of epochs, data without GACOS corr would be dropped)
p02to05_hgtcorr="" # y/n. default: 'n'. Recommended for regions with high and varying topography
p02to05_cascade="" # y/n. default: 'n'. Cascade from higher multilook factor would propagate to higher resolution (lower ML factor) data. Useful but not universal
p02to05_filter="" # gold, gauss or adf. Default: 'gold'
p02to05_thres="" # default: 0.35. Spatial consistence of the interferogram. Recommended to keep this value. If too much is masked, may try getting close to 0 (although, this would introduce some unw errors)
p02to05_cliparea_geo=$p05_clip_range_geo # setting the clip range, e.g. 130.11/131.12/34.34/34.6 (in deg)
p02to05_n_para=$n_para
p02to05_op_GEOCdir="" # by default, if none, it will use GEOC directory

### Frequently used options. If blank, use default. ###
p01_start_date=""	# default: 20141001
p01_end_date=""	# default: today
p01_get_gacos="n" # y/n
p01_get_pha="n" # y/n
p01_get_mli="n" # y/n
p01_sbovl="n"
p02_sbovl="n"
p11_unw_thre=""	# default: 0.3
p11_coh_thre=""	# default: 0.05
p11_s_param="n" # y/n
p11_sbovl="n"
p120_use="n"  # y/n
p120_sbovl="n"
p12_loop_thre=""	# default: 1.5 rad. With --nullify, recommended higher value (as this is an average over the whole scene)
p12_multi_prime="y"	# y/n. y recommended
p12_nullify="" # y/n. y recommended
p12_rm_ifg_list=""	# List file containing ifgs to be manually removed
p12_skippngs="" # y/n. n by default
p13_nullify_noloops="" # y/n. n by default (but it is recommended to use this option with p12_nullify)
p13_ignore_nullification="" # y/n. n by default
p13_singular="" # y/n. n by default
p13_singular_gauss="" # y/n. n by default
p13_skippngs="" # y/n. n by default
p13_sbovl="n"
p15_coh_thre=""	# default: 0.05
p15_n_unw_r_thre=""	# default: 1.5
p15_vstd_thre=""	# default: 100 mm/yr
p15_maxTlen_thre=""	# default: 1 yr
p15_n_gap_thre=""	# default: 10
p15_stc_thre=""	# default: 10 mm
p15_n_ifg_noloop_thre=""	# default: 500 - setting this much higher than orig since we nullify them (p13_nullify_noloops)
p15_n_loop_err_thre=""	# default: 5
p15_n_loop_err_ratio_thre=""	# default: 0.7 - in future we will switch to this ratio term, instead of n_loop_err
p15_resid_rms_thre=""	# default: 15 mm
p15_avg_phasebias="" # default: not used. Setting 1 or 1.2 rad is good option
p15_n_gap_use_merged="y" # default: 'y'
p15_sbovl="n"
p16_filtwidth_km=""	# default: 2 km
p16_filtwidth_yr=""	# default: avg_interval*3 yr
p16_deg_deramp=""	# 1, bl, or 2. default: no deramp
p16_demerr="n"	# y/n. default: n
p16_hgt_linear="n"	# y/n. default: n
p16_hgt_min=""	# default: 200 (m)
p16_hgt_max=""  # default: 10000 (m)
p16_range=""	# e.g. 10:100/20:200 (ix start from 0)
p16_range_geo=""	# e.g. 130.11/131.12/34.34/34.6 (in deg)
p16_ex_range=""	# e.g. 10:100/20:200 (ix start from 0)
p16_ex_range_geo=""	# e.g. 130.11/131.12/34.34/34.6 (in deg)
p16_interpolate_nans="y"  # will interpolate nans in unmasked pixels
p16_skippngs="" # y/n. n by default
p16_sbovl="n"

### Less frequently used options. If blank, use default. ###
p01_frame=""	# e.g. 021D_04972_131213 
p01_n_para=$n_para	# default: 4
p01_rngoff="n"
p02_rngoff="n"
p02_GEOCdir=""	# default: GEOC
p02_GEOCmldir=""	# default: GEOCml$nlook
p02_freq=$freq	# default: 5.405e9 Hz
p02_n_para=$n_para   # default: # of usable CPU
p03_inGEOCmldir=""	# default: $GEOCmldir
p03_outGEOCmldir_suffix="" # default: GACOS
p03_fillhole="y"	# y/n. default: n
p03_gacosdir=""	# default: GACOS
p03_n_para=$n_para   # default: # of usable CPU
p04_inGEOCmldir=""	# default: $GEOCmldir
p04_outGEOCmldir_suffix="" # default: mask
p04_n_para=$n_para   # default: # of usable CPU
p05_inGEOCmldir=""      # default: $GEOCmldir
p05_outGEOCmldir_suffix="" # default: clip
p05_n_para=$n_para   # default: # of usable CPU
p11_GEOCmldir=""	# default: $GEOCmldir
p11_TSdir=""	# default: TS_$GEOCmldir
p11_minbtemp=""  # default: 0 (not use)
p11_maxbtemp=""  # default: 0 (not use)
p120_ignoreconncomp="n" # y/n
p12_GEOCmldir=""        # default: $GEOCmldir
p12_TSdir=""    # default: TS_$GEOCmldir
p12_n_para=$n_para	# default: # of usable CPU
p12_nullify_fix_ref='' # y/n
p13_GEOCmldir=""        # default: $GEOCmldir
p13_TSdir=""    # default: TS_$GEOCmldir
p13_inv_alg=""	# LS (default) or WLS
p13_mem_size=""	# default: 8000 (MB)
p13_gamma=""	# default: 0.0001
p13_inputunit="" # rad by default
p13_n_para=$n_para	# default: # of usable CPU
p13_n_unw_r_thre=""	# default: 1 for shorter-than-L-band-wavelength (if cometdev, will set to 0.1)
p13_keep_incfile="n"	# y/n. default: n
p14_TSdir=""    # default: TS_$GEOCmldir
p14_mem_size="" # default: 4000 (MB)
p15_TSdir=""    # default: TS_$GEOCmldir
p15_vmin=""	# default: auto (mm/yr)
p15_vmax=""	# default: auto (mm/yr)
p15_keep_isolated="n"	# y/n. default: n
p15_noautoadjust="n" # y/n. default: n
p16_TSdir=""    # default: TS_$GEOCmldir
p16_nomask="n"	# y/n. default: n
p16_n_para=$n_para   # default: # of usable CPU

# eqoffs
eqoffs_minmag="0"  # min magnitude of earthquakes to auto-find. 0 means skipping the estimation.
eqoffs_txtfile="eqoffsets.txt"  # path to txt file containing custom-set earthquake dates (if eqoffs_minmag is disabled/0) or that will use results of auto-find
eqoffs_buffer="0.1"  # buffer (in degrees, assuming work with WGS-84 geocoded data) to search for earthquakes (if eqoffs_minmag is set)

################################
### Job Generation & Submit ###
################################
echo ""
echo "LiCSBAS Jasmin Job Submission Script"
echo "===================================="
echo "Start step: $start_step"
echo "End step:   $end_step"
echo "Log file:   $log"
echo ""
mkdir -p $logdir

# Extract frame name from p01_frame, or use current directory name if not set
FRAME_NAME="${p01_frame:-$(basename $(pwd))}"
echo "Frame name: $FRAME_NAME"
echo ""

# Extract track from frame name (first 3 digits, remove leading zeros)
track=$(echo "$FRAME_NAME" | cut -c -3 | sed 's/^0//' | sed 's/^0//')
echo "Track: $track"

# Auto-derive GEOC_LINK_SOURCE if LINK_GEOC_DATA is enabled and source path is empty
if [ "$LINK_GEOC_DATA" == "y" ] && [ -z "$GEOC_LINK_SOURCE" ]; then
  if [ ! -z "$LiCSAR_public" ]; then
    GEOC_LINK_SOURCE="$LiCSAR_public/$track/$FRAME_NAME/GEOC"
    echo "Auto-derived GEOC_LINK_SOURCE: $GEOC_LINK_SOURCE"
  else
    echo "WARNING: LINK_GEOC_DATA='y' but LiCSAR_public environment variable not set and GEOC_LINK_SOURCE not specified"
  fi
fi
echo ""

# Initialize job IDs
JOB_ID_01=""
JOB_ID_02_11=""
JOB_ID_12=""
JOB_ID_13=""
JOB_ID_14_16=""

# Function to create and submit a job script
create_and_submit_job() {
  local step_name=$1        # e.g., "1", "2_11", "12", etc.
  local job_script=$2       # e.g., "Jasmin_LB_1.sh"
  local job_name=$3         # e.g., "Jasmin_LB_1_frame_name"
  local time_limit=$4       # e.g., "2:00:00"
  local mem_limit=$5        # e.g., "4G"
  local cpus=$6             # e.g., "4"
  local dep_job_id=$7       # Job ID to depend on (empty for first job)
  local commands=$8         # Pre-built commands to execute
  
  # Calculate total memory: mem_limit * cpus
  local mem_num=$(echo "$mem_limit" | sed 's/[A-Za-z]*$//')
  local mem_unit=$(echo "$mem_limit" | sed 's/^[0-9]*//')
  local total_mem=$((mem_num * cpus))$mem_unit
  
  echo "Creating job script: $job_script (CPUs: $cpus, Total Memory: $total_mem)" >&2
  
  cat > "$job_script" << 'JOBHEADER'
#!/bin/bash
#SBATCH --job-name=JOBNAME_PLACEHOLDER
#SBATCH --qos=QOS_PLACEHOLDER
#SBATCH --time=TIME_PLACEHOLDER
#SBATCH --mem=MEM_PLACEHOLDER
#SBATCH --cpus-per-task=CPUS_PLACEHOLDER
#SBATCH --output=JOBNAME_PLACEHOLDER.out
#SBATCH --error=JOBNAME_PLACEHOLDER.err
#SBATCH --account='nceo_geohazards'
#SBATCH --partition='standard'

set -e

echo "Starting LiCSBAS Step STEP_PLACEHOLDER at $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo "Job Node: $SLURM_NODELIST"
echo ""

JOBHEADER

  # Inject configuration variables into the job script
  cat >> "$job_script" << VARIABLES

# Configuration variables from main script
logdir="$logdir"
log="$log"

VARIABLES

  # Add the pre-built commands
  echo "$commands" >> "$job_script"

  # Substitute SBATCH parameters
  sed -i "s|JOBNAME_PLACEHOLDER|$job_name|g; s|QOS_PLACEHOLDER|$JASMIN_QOS|g; s|TIME_PLACEHOLDER|$time_limit|g; s|MEM_PLACEHOLDER|$total_mem|g; s|CPUS_PLACEHOLDER|$cpus|g; s|STEP_PLACEHOLDER|$step_name|g" "$job_script"
  
  # Add completion message
  cat >> "$job_script" << 'JOBFOOTER'

echo ""
echo "Completed LiCSBAS Step at $(date)"

JOBFOOTER

  chmod +x "$job_script"
  if [ "$SUBMIT_JOBS" == "y" ]; then
    if [ -z "$dep_job_id" ]; then
      echo "  Submitting to Jasmin (no dependency)..." >&2
      local JID=$(sbatch "$job_script" | awk '{print $NF}')
      echo "  Job ID: $JID" >&2
      echo "$JID"
    else
      echo "  Submitting to Jasmin (depends on job $dep_job_id)..." >&2
      local JID=$(sbatch --dependency=afterok:$dep_job_id "$job_script" | awk '{print $NF}')
      echo "  Job ID: $JID" >&2
      echo "$JID"
    fi
  else
    echo "  Created but not submitted (SUBMIT_JOBS='n')" >&2
    echo "" >&2
  fi
}

# Build function for STEP 1
################################
### Apply Default Configuration ###
################################

# Apply defaults for any unset time limits
JASMIN_TIME_STEP1="${JASMIN_TIME_STEP1:-$JASMIN_TIME_DEFAULT}"
JASMIN_TIME_STEP2_11="${JASMIN_TIME_STEP2_11:-$JASMIN_TIME_DEFAULT}"
JASMIN_TIME_STEP12="${JASMIN_TIME_STEP12:-$JASMIN_TIME_DEFAULT}"
JASMIN_TIME_STEP13="${JASMIN_TIME_STEP13:-$JASMIN_TIME_DEFAULT}"
JASMIN_TIME_STEP14_16="${JASMIN_TIME_STEP14_16:-$JASMIN_TIME_DEFAULT}"

# Apply defaults for any unset memory limits
JASMIN_MEM_STEP1="${JASMIN_MEM_STEP1:-$JASMIN_MEM_DEFAULT}"
JASMIN_MEM_STEP2_11="${JASMIN_MEM_STEP2_11:-$JASMIN_MEM_DEFAULT}"
JASMIN_MEM_STEP12="${JASMIN_MEM_STEP12:-$JASMIN_MEM_DEFAULT}"
JASMIN_MEM_STEP13="${JASMIN_MEM_STEP13:-$JASMIN_MEM_DEFAULT}"
JASMIN_MEM_STEP14_16="${JASMIN_MEM_STEP14_16:-$JASMIN_MEM_DEFAULT}"

# Apply defaults for any unset CPU counts
JASMIN_CPUS_STEP1="${JASMIN_CPUS_STEP1:-$JASMIN_CPUS_DEFAULT}"
JASMIN_CPUS_STEP2_11="${JASMIN_CPUS_STEP2_11:-$JASMIN_CPUS_DEFAULT}"
JASMIN_CPUS_STEP12="${JASMIN_CPUS_STEP12:-$JASMIN_CPUS_DEFAULT}"
JASMIN_CPUS_STEP13="${JASMIN_CPUS_STEP13:-$JASMIN_CPUS_DEFAULT}"
JASMIN_CPUS_STEP14_16="${JASMIN_CPUS_STEP14_16:-$JASMIN_CPUS_DEFAULT}"

# Apply defaults for CPUS and QOS if unset
JASMIN_QOS="${JASMIN_QOS:-$JASMIN_QOS_DEFAULT}"

################################
### Build Commands for Each Step ###
################################

# STEP 1: Get GEOC data
STEP1_CMDS="echo 'Running Step 1: Get GeoTIFF data...'"$'\n'
if [ "$LINK_GEOC_DATA" == "y" ]; then
  STEP1_CMDS+="echo 'Linking GEOC data from: $GEOC_LINK_SOURCE'"$'\n'
  STEP1_CMDS+="mkdir -p GEOC && cd GEOC && $(for file in $GEOC_LINK_SOURCE/*.tif; do echo \"ln -s $file $(basename $file) 2>/dev/null || true\"; done) && cd .."$'\n'
else
  STEP1_CMDS+="p01_op=''"$'\n'
  [ ! -z "$p01_frame" ] && STEP1_CMDS+="p01_op=\"\$p01_op -f $p01_frame\""$'\n'
  [ ! -z "$p01_start_date" ] && STEP1_CMDS+="p01_op=\"\$p01_op -s $p01_start_date\""$'\n'
  [ ! -z "$p01_end_date" ] && STEP1_CMDS+="p01_op=\"\$p01_op -e $p01_end_date\""$'\n'
  [ ! -z "$p01_n_para" ] && STEP1_CMDS+="p01_op=\"\$p01_op --n_para $p01_n_para\""$'\n'
  [ "$p01_sbovl" == "y" ] && STEP1_CMDS+="p01_op=\"\$p01_op --sbovl\""$'\n'
  [ "$p01_rngoff" == "y" ] && STEP1_CMDS+="p01_op=\"\$p01_op --rngoff\""$'\n'
  [ "$p01_get_gacos" == "y" ] && STEP1_CMDS+="p01_op=\"\$p01_op --get_gacos\""$'\n'
  [ "$p01_get_pha" == "y" ] && STEP1_CMDS+="p01_op=\"\$p01_op --get_pha\""$'\n'
  [ "$p01_get_mli" == "y" ] && STEP1_CMDS+="p01_op=\"\$p01_op --get_mli\""$'\n'
  STEP1_CMDS+="LiCSBAS01_get_geotiff.py \$p01_op 2>&1 | tee -a \$log"$'\n'
fi

# STEPS 2-11: ML Prep and unwrap
STEP2_11_CMDS="echo 'Running Steps 2-11...'"$'\n'
if [ "$run_reunwrapping" == "y" ]; then
  STEP2_11_CMDS+="p02to05_op=''"$'\n'
  [ ! -z "$p02to05_op_GEOCdir" ] && STEP2_11_CMDS+="p02to05_op=\"-i $p02to05_op_GEOCdir\"" || STEP2_11_CMDS+="p02to05_op='-i GEOC'"$'\n'
  [ ! -z "$nlook" ] && STEP2_11_CMDS+="p02to05_op=\"\$p02to05_op -M $nlook\""$'\n'
  [ ! -z "$p02to05_freq" ] && STEP2_11_CMDS+="p02to05_op=\"\$p02to05_op --freq $p02to05_freq\""$'\n'
  [ ! -z "$p02to05_n_para" ] && STEP2_11_CMDS+="p02to05_op=\"\$p02to05_op --n_para $p02to05_n_para\""$'\n'
  [ ! -z "$p02to05_thres" ] && STEP2_11_CMDS+="p02to05_op=\"\$p02to05_op --thres $p02to05_thres\""$'\n'
  [ ! -z "$p02to05_filter" ] && STEP2_11_CMDS+="p02to05_op=\"\$p02to05_op --filter $p02to05_filter\""$'\n'
  [ ! -z "$p02to05_cliparea_geo" ] && STEP2_11_CMDS+="p02to05_op=\"\$p02to05_op -g $p02to05_cliparea_geo\""$'\n'
  [ "$p02to05_cascade" == "y" ] && STEP2_11_CMDS+="p02to05_op=\"\$p02to05_op --cascade\""$'\n'
  [ "$p02to05_hgtcorr" == "y" ] && STEP2_11_CMDS+="p02to05_op=\"\$p02to05_op --hgtcorr\""$'\n'
  [ "$p02to05_gacos" == "y" ] && STEP2_11_CMDS+="p02to05_op=\"\$p02to05_op --gacos\""$'\n'
  STEP2_11_CMDS+="LiCSBAS02to05_unwrap.py \$p02to05_op 2>&1 | tee -a \$log"$'\n'
else
  STEP2_11_CMDS+="p02_op=''"$'\n'
  [ ! -z "$p02_GEOCdir" ] && STEP2_11_CMDS+="p02_op=\"-i $p02_GEOCdir\"" || STEP2_11_CMDS+="p02_op='-i GEOC'"$'\n'
  [ ! -z "$p02_GEOCmldir" ] && STEP2_11_CMDS+="p02_op=\"\$p02_op -o $p02_GEOCmldir\""$'\n'
  [ ! -z "$nlook" ] && STEP2_11_CMDS+="p02_op=\"\$p02_op -n $nlook\""$'\n'
  [ ! -z "$p02_freq" ] && STEP2_11_CMDS+="p02_op=\"\$p02_op --freq $p02_freq\""$'\n'
  [ "$p02_sbovl" == "y" ] && STEP2_11_CMDS+="p02_op=\"\$p02_op --sbovl\""$'\n'
  [ "$p02_rngoff" == "y" ] && STEP2_11_CMDS+="p02_op=\"\$p02_op --rngoff\""$'\n'
  STEP2_11_CMDS+="LiCSBAS02_ml_prep.py \$p02_op 2>&1 | tee -a \$log"$'\n'
fi
if [ $start_step -le 11 -a $end_step -ge 11 ]; then
  STEP2_11_CMDS+="echo 'Step 11: Check unwrap' && p11_op=''"$'\n'
  [ ! -z "$p11_GEOCmldir" ] && STEP2_11_CMDS+="p11_op=\" -d $p11_GEOCmldir\"" || STEP2_11_CMDS+="p11_op=\" -d \$GEOCmldir\""$'\n'
  [ ! -z "$p11_TSdir" ] && STEP2_11_CMDS+="p11_op=\"\$p11_op -t $p11_TSdir\""$'\n'
  [ ! -z "$p11_unw_thre" ] && STEP2_11_CMDS+="p11_op=\"\$p11_op -u $p11_unw_thre\""$'\n'
  [ ! -z "$p11_coh_thre" ] && STEP2_11_CMDS+="p11_op=\"\$p11_op -c $p11_coh_thre\""$'\n'
  [ "$p11_sbovl" == "y" ] && STEP2_11_CMDS+="p11_op=\"\$p11_op --sbovl\""$'\n'
  STEP2_11_CMDS+="LiCSBAS11_check_unw.py \$p11_op 2>&1 | tee -a \$log"$'\n'
fi

# STEP 12: Loop closure
STEP12_CMDS="echo 'Running Step 12: Loop closure...' && p12_op=''"$'\n'
[ ! -z "$p12_GEOCmldir" ] && STEP12_CMDS+="p12_op=\" -d $p12_GEOCmldir\"" || STEP12_CMDS+="p12_op=\" -d \$GEOCmldir\""$'\n'
[ ! -z "$p12_TSdir" ] && STEP12_CMDS+="p12_op=\"\$p12_op -t $p12_TSdir\"" || STEP12_CMDS+="p12_op=\"\$p12_op -t TS_\$GEOCmldir\""$'\n'
[ ! -z "$p12_loop_thre" ] && STEP12_CMDS+="p12_op=\"\$p12_op -l $p12_loop_thre\""$'\n'
[ "$p12_multi_prime" == "y" ] && STEP12_CMDS+="p12_op=\"\$p12_op --multi_prime\""$'\n'
[ "$p12_nullify" == "y" ] && STEP12_CMDS+="p12_op=\"\$p12_op --nullify\""$'\n'
[ ! -z "$p12_n_para" ] && STEP12_CMDS+="p12_op=\"\$p12_op --n_para $p12_n_para\""$'\n'
STEP12_CMDS+="LiCSBAS12_loop_closure.py \$p12_op 2>&1 | tee -a \$log"$'\n'

# STEP 13: Small baseline inversion
STEP13_CMDS="echo 'Running Step 13: Small baseline inversion...' && p13_op=''"$'\n'
[ ! -z "$p13_GEOCmldir" ] && STEP13_CMDS+="p13_op=\" -d $p13_GEOCmldir\"" || STEP13_CMDS+="p13_op=\" -d \$GEOCmldir\""$'\n'
[ ! -z "$p13_TSdir" ] && STEP13_CMDS+="p13_op=\"\$p13_op -t $p13_TSdir\"" || STEP13_CMDS+="p13_op=\"\$p13_op -t TS_\$GEOCmldir\""$'\n'
[ ! -z "$p13_inv_alg" ] && STEP13_CMDS+="p13_op=\"\$p13_op --inv_alg $p13_inv_alg\""$'\n'
[ ! -z "$p13_mem_size" ] && STEP13_CMDS+="p13_op=\"\$p13_op --mem_size $p13_mem_size\""$'\n'
[ ! -z "$p13_gamma" ] && STEP13_CMDS+="p13_op=\"\$p13_op --gamma $p13_gamma\""$'\n'
[ ! -z "$p13_n_para" ] && STEP13_CMDS+="p13_op=\"\$p13_op --n_para $p13_n_para\""$'\n'
[ "$p13_singular_gauss" == "y" ] && STEP13_CMDS+="p13_op=\"\$p13_op --singular_gauss\""$'\n'
[ "$gpu" == "y" ] && STEP13_CMDS+="p13_op=\"\$p13_op --gpu\""$'\n'
STEP13_CMDS+="LiCSBAS13_sb_inv.py \$p13_op 2>&1 | tee -a \$log"$'\n'

# STEPS 14-16: Velocity, masking, filtering
STEP14_16_CMDS="echo 'Running Steps 14-16...' && p14_op=''"$'\n'
[ ! -z "$p14_TSdir" ] && STEP14_16_CMDS+="p14_op=\" -t $p14_TSdir\"" || STEP14_16_CMDS+="p14_op=\" -t TS_\$GEOCmldir\""$'\n'
[ ! -z "$p14_mem_size" ] && STEP14_16_CMDS+="p14_op=\"\$p14_op --mem_size $p14_mem_size\""$'\n'
[ "$gpu" == "y" ] && STEP14_16_CMDS+="p14_op=\"\$p14_op --gpu\""$'\n'
STEP14_16_CMDS+="LiCSBAS14_vel_std.py \$p14_op 2>&1 | tee -a \$log && echo 'Step 15: Mask TS' && p15_op=''"$'\n'
[ ! -z "$p15_TSdir" ] && STEP14_16_CMDS+="p15_op=\" -t $p15_TSdir\"" || STEP14_16_CMDS+="p15_op=\" -t TS_\$GEOCmldir\""$'\n'
[ ! -z "$p15_coh_thre" ] && STEP14_16_CMDS+="p15_op=\"\$p15_op -c $p15_coh_thre\""$'\n'
[ ! -z "$p15_vstd_thre" ] && STEP14_16_CMDS+="p15_op=\"\$p15_op -v $p15_vstd_thre\""$'\n'
[ ! -z "$p15_n_gap_thre" ] && STEP14_16_CMDS+="p15_op=\"\$p15_op -g $p15_n_gap_thre\""$'\n'
STEP14_16_CMDS+="LiCSBAS15_mask_ts.py \$p15_op 2>&1 | tee -a \$log && echo 'Step 16: Filter TS' && p16_op=''"$'\n'
[ ! -z "$p16_TSdir" ] && STEP14_16_CMDS+="p16_op=\" -t $p16_TSdir\"" || STEP14_16_CMDS+="p16_op=\" -t TS_\$GEOCmldir\""$'\n'
[ ! -z "$p16_filtwidth_km" ] && STEP14_16_CMDS+="p16_op=\"\$p16_op -k $p16_filtwidth_km\""$'\n'
[ ! -z "$p16_deg_deramp" ] && STEP14_16_CMDS+="p16_op=\"\$p16_op -d $p16_deg_deramp\""$'\n'
[ "$p16_demerr" == "y" ] && STEP14_16_CMDS+="p16_op=\"\$p16_op --demerr\""$'\n'
STEP14_16_CMDS+="LiCSBAS16_filt_ts.py \$p16_op 2>&1 | tee -a \$log"$'\n'

################################
### Create and Submit Jobs ###
################################

echo "========================================="
echo "Creating and Submitting Job Scripts"
echo "========================================="
echo ""

# Step 01
if [ $start_step -le 01 -a $end_step -ge 01 ];then
  JOB_ID_01=$(create_and_submit_job "01" "Jasmin_LB_01.sh" "Jasmin_LB_01_${FRAME_NAME}" "$JASMIN_TIME_STEP1" "$JASMIN_MEM_STEP1" "$JASMIN_CPUS_STEP1" "" "$STEP1_CMDS")
fi

# Steps 02-11
if [ $start_step -le 11 -a $end_step -ge 02 ];then
  JOB_ID_02_11=$(create_and_submit_job "02-11" "Jasmin_LB_02_11.sh" "Jasmin_LB_02_11_${FRAME_NAME}" "$JASMIN_TIME_STEP2_11" "$JASMIN_MEM_STEP2_11" "$JASMIN_CPUS_STEP2_11" "$JOB_ID_01" "$STEP2_11_CMDS")
fi

# Step 12
if [ $start_step -le 12 -a $end_step -ge 12 ];then
  JOB_ID_12=$(create_and_submit_job "12" "Jasmin_LB_12.sh" "Jasmin_LB_12_${FRAME_NAME}" "$JASMIN_TIME_STEP12" "$JASMIN_MEM_STEP12" "$JASMIN_CPUS_STEP12" "$JOB_ID_02_11" "$STEP12_CMDS")
fi

# Step 13
if [ $start_step -le 13 -a $end_step -ge 13 ];then
  JOB_ID_13=$(create_and_submit_job "13" "Jasmin_LB_13.sh" "Jasmin_LB_13_${FRAME_NAME}" "$JASMIN_TIME_STEP13" "$JASMIN_MEM_STEP13" "$JASMIN_CPUS_STEP13" "$JOB_ID_12" "$STEP13_CMDS")
fi

# Steps 14-16
if [ $start_step -le 16 -a $end_step -ge 14 ];then
  JOB_ID_14_16=$(create_and_submit_job "14-16" "Jasmin_LB_14_16.sh" "Jasmin_LB_14_16_${FRAME_NAME}" "$JASMIN_TIME_STEP14_16" "$JASMIN_MEM_STEP14_16" "$JASMIN_CPUS_STEP14_16" "$JOB_ID_13" "$STEP14_16_CMDS")
fi

################################
### Summary ###
################################
echo ""
echo "========================================="
echo "Job Submission Summary"
echo "========================================="
echo "Frame: $FRAME_NAME"
echo "Step 01 Job ID:     $JOB_ID_01"
echo "Steps 02-11 Job ID: $JOB_ID_02_11"
echo "Step 12 Job ID:    $JOB_ID_12"
echo "Step 13 Job ID:    $JOB_ID_13"
echo "Steps 14-16 Job ID: $JOB_ID_14_16"
echo ""

if [ "$SUBMIT_JOBS" == "y" ]; then
  echo "Jobs submitted to Jasmin!"
  echo ""
  echo "To check job status:"
  echo "  squeue -u $USER"
  echo ""
  echo "To cancel all jobs:"
  echo "  scancel -u $USER"
else
  echo "Job scripts created but not submitted (SUBMIT_JOBS='n')."
  echo "To submit manually, run:"
  echo "  sbatch Jasmin_LB_01.sh"
  echo "  sbatch --dependency=afterok:\$JOB_ID_01 Jasmin_LB_02_11.sh"
  echo "  ... and so on"
fi

echo ""
echo "Log file: $log"
echo ""
