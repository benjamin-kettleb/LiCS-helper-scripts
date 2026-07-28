#This File ics coppied from licsar_proc/bin/python/plot_network.py and eddited to plot preposed ifgs
# two outputs are: png plot and text file for gaps (both are mandatory)
# e.g. $LiCSAR_public/$track/$frame output.png gaps.txt
# then... there is optional parameter for check_common_bursts --- so if you add '1' , it will additionally check for the common bursts. will take more time though...
#%% Import
import os
import sys
import numpy as np
import LiCSBAS_io_lib as io_lib
#import LiCSBAS_plot_lib as plot_lib
from LiCSBAS_plot_lib import *
import LiCSBAS_tools_lib as tools_lib
import LiCSBAS_inv_lib as inv_lib
import datetime as dt
import s1data as s1
import pandas as pd
import framecare as fc
from LiCSAR_db import LiCSquery as lq
from LiCSAR_lib import s1data
import re
from os import path

check_common_bursts = False

#%%
def read_bperp_file(bperp_file, imdates, return_missflag = False):
    """
    updated from LiCSBAS io_lib function to give 0 for missing imdates
    
    bperp_file (baselines) contains (m: primary (master), s: secondary,
                                     sm: single prime):
          smdate    sdate    bp    dt
        20170302 20170326 130.9  24.0
        20170302 20170314  32.4  12.0
    Old bperp_file contains (m: primary (master), s:secondary,
                             sm: single prime):
        num    mdate    sdate   bp   dt  dt_m_sm dt_s_sm bp_m_sm bp_s_sm
          1 20170218 20170326 96.6 36.0    -12.0    24.0    34.2   130.9
          2 20170302 20170314 32.4 12.0      0.0    12.0     0.0    32.4
    Return: bperp
    """
    bperp = []
    missflag = False
    bperp_dict = {}
    ### Determine type of bperp_file; old or not
    with open(bperp_file) as f:
        line = f.readline().split() #list
    if len(line) == 4: ## new format
        bperp_dict[line[0]] = '0.00' ## single prime. unnecessary?
        with open(bperp_file) as f:
            for l in f:
                if len(l.split()) == 4:
                    bperp_dict[l.split()[1]] = l.split()[2]
    else: ## old format
        with open(bperp_file) as f:
            for l in f:
                bperp_dict[l.split()[1]] = l.split()[-2]
                bperp_dict[l.split()[2]] = l.split()[-1]
    for imd in imdates:
        if imd in bperp_dict:
            bperp.append(float(bperp_dict[imd]))
        else: ## If no key exists
            bperp.append(0)
            missflag = True
            if not return_missflag:
                print('WARNING: bperp for {} not found, nullifying'.format(imd))
            #return False
    if return_missflag:
        return bperp, missflag
    else:
        return bperp

def plot_preposed_network(ifgdates, bperp, frame, pngfile, preposed_ifgdates, firstdate = dt.datetime(2014, 9, 25), lastdate = dt.datetime(2025, 12, 31)):
    """
    Plot network of interferometric pairs.
    bperp can be dummy (-1~1).
    Suffix of pngfile can be png, ps, pdf, or svg.

    Function originally plot_network_upd from licsar_proc. Edited by Benjamin Kettleborough to also plot recomended connections in green
    """
    imdates_all = tools_lib.ifgdates2imdates(ifgdates)
    n_im_all = len(imdates_all)
    imdates_dt_all = np.array(([dt.datetime.strptime(imd, '%Y%m%d') for imd in imdates_all])) ##datetime
    ifgdates = list(set(ifgdates))
    ifgdates.sort()
    imdates = tools_lib.ifgdates2imdates(ifgdates)
    n_im = len(imdates)
    imdates_dt = np.array(([dt.datetime.strptime(imd, '%Y%m%d') for imd in imdates])) ##datetime
    #
    ### Identify gaps    
    G = inv_lib.make_sb_matrix(ifgdates)
    ixs_inc_gap = np.where(G.sum(axis=0)==0)[0]
    #
    ### Plot fig
    #figsize_x = np.round(((imdates_dt_all[-1]-imdates_dt_all[0]).days)/80)+2
    figsize_x = np.round(((lastdate-firstdate).days)/80)+2
    #fig = plt.figure(figsize=(figsize_x, 6))
    fig = plt.figure(figsize=(figsize_x, 7))
    #ax = fig.add_axes([0.06, 0.12, 0.92,0.85])
    ax = fig.add_axes([0.03, 0.12, 0.94,0.8])
    #
    ### IFG blue lines
    for i, ifgd in enumerate(ifgdates):
        ix_m = imdates_all.index(ifgd[:8])
        ix_s = imdates_all.index(ifgd[-8:])
        label = 'IFG' if i==0 else '' #label only first
        plt.plot([imdates_dt_all[ix_m], imdates_dt_all[ix_s]], [bperp[ix_m],
                bperp[ix_s]], color='b', alpha=0.6, zorder=2, label=label)

    ### Preposed IFG marked with green lines
    for i, ifgd in enumerate(preposed_ifgdates):
        ix_m = imdates_all.index(ifgd[:8])
        ix_s = imdates_all.index(ifgd[-8:])
        label = 'Prposed IFG' if i==0 else '' #label only first
        plt.plot([imdates_dt_all[ix_m], imdates_dt_all[ix_s]], [bperp[ix_m],
                bperp[ix_s]], color='g', alpha=0.6, zorder=2, label=label)

    #
    #
    ### Image points and dates
    ax.scatter(imdates_dt_all, bperp, alpha=0.6, zorder=4)
    for i in range(n_im_all):
        if bperp[i] > np.median(bperp): va='bottom'
        else: va = 'top'
        ax.annotate(imdates_all[i][4:6]+'/'+imdates_all[i][6:],
                    (imdates_dt_all[i], bperp[i]), ha='center', va=va, zorder=8)
    #
    #
    ### gaps
    if len(ixs_inc_gap)!=0:
        gap_dates_dt = []
        for ix_gap in ixs_inc_gap:
            ddays_td = imdates_dt[ix_gap+1]-imdates_dt[ix_gap]
            gap_dates_dt.append(imdates_dt[ix_gap]+ddays_td/2)
        plt.vlines(gap_dates_dt, 0, 1, transform=ax.get_xaxis_transform(),
                   zorder=1, label='Gap', alpha=0.6, colors='k', linewidth=3)
    #
    #
    ### Locater        
    loc = ax.xaxis.set_major_locator(mdates.AutoDateLocator())
    try:  # Only support from Matplotlib 3.1
        ax.xaxis.set_major_formatter(mdates.ConciseDateFormatter(loc))
    except:
        ax.xaxis.set_major_formatter(mdates.DateFormatter('%Y/%m/%d'))
        for label in ax.get_xticklabels():
            label.set_rotation(20)
            label.set_horizontalalignment('right')
    #
    #
    ax.grid(b=True, which='major')
    ### Add bold line every 1yr
    ax.xaxis.set_minor_locator(mdates.YearLocator())
    ax.grid(b=True, which='minor', linewidth=2)
    ax.set_xlim((firstdate, lastdate))
    #ax.set_xlim((imdates_dt_all[0]-dt.timedelta(days=10),
    #             imdates_dt_all[-1]+dt.timedelta(days=10)))
    ### Labels and legend
    plt.xlabel('Time')
    if np.all(np.abs(np.array(bperp))<=1): ## dummy
        plt.ylabel('dummy')
    else:
        plt.ylabel('Bperp [m]')
    #
    # 2022-04-19 adding dots of 'existing epochs'
    print("getting existing epochs for the frame bounding box")
    epochdates = s1.get_epochs_for_frame(frame, firstdate.date(), lastdate.date(), returnAsDate = True)
    epochdates.sort()
    for imd in imdates_dt:
        imdd = imd.date()
        if imdd in epochdates:
            #print('debug - found and removed ok: '+str(imdd))
            epochdates.remove(imdd)
    if check_common_bursts:
        print("checking if the epochs have any common burst - if not, will plot them anyway, in gray")
        framebursts = fc.lq.sqlout2list(fc.get_bidtanxs_in_frame(frame))
        epochdates_outburst = []
        if os.path.exists(temp_outbursts):
            try:
                epochdates_outburst = pd.read_csv(temp_outbursts, header=None)[0].to_list()
                epochdates_outburst = [dt.datetime.strptime(d, "%Y-%m-%d").date() for d in epochdates_outburst]
            except:
                print('some error trying to read the temp file '+temp_outbursts)
                epochdates_outburst = []
        for ep in epochdates_outburst:  # epochs in the outburst must not appear as the red circles
            if ep in epochdates:
                epochdates.remove(ep)
        epochdatescopy = epochdates.copy()
        for imdd in epochdatescopy:
            if len(fc.get_frame_files_date(frame, imdd))>0:
                continue  # if we find something in database, it just means there was this acquisition, so plot it
            if imdd>dt.date.today()-dt.timedelta(days=1):
                continue  # maybe not in CDSE database yet? keep it red then
            print('checking epoch '+str(imdd))
            # there is some overlap but does it have the same bursts?
            try:
                imagespd = s1.get_images_for_frame(frame, startdate = imdd-dt.timedelta(days=1), enddate = imdd+dt.timedelta(days=1), asf = False, outAspd=True)
                images = imagespd['title'].values.tolist()
                for im in images:
                    bursts = fc.lq.sqlout2list(fc.get_bursts_in_file(im))
                    if not bursts:
                        filepath = s1.get_neodc_path_images(im, file_or_meta=True)[0]
                        _ = fc.ingest_file_to_licsinfo(filepath, isfullpath=True)
                        bursts = fc.lq.sqlout2list(fc.get_bursts_in_file(im))
                    isinframe = False
                    for b in bursts:
                        if b in framebursts:
                            isinframe = True
                            # break
                    if not isinframe:
                        epochdates.remove(imdd)  # remove from getting plotted as red circles
                        epochdates_outburst.append(imdd)
            except:
                print('some error double checking epoch '+str(imdd)+'. keeping it')
        if epochdates_outburst:
            epochdates_outburst.sort()
            # store the bursts without coverage to external file for fast-loading it later
            try:
                pd.DataFrame(epochdates_outburst)[0].to_csv(temp_outbursts, header=False, index=False)
                os.system('chmod 777 '+temp_outbursts)
            except:
                print('DEBUG: cannot save the temp data to '+temp_outbursts)
            ax.scatter(epochdates_outburst, np.zeros(len(epochdates_outburst)), facecolors='none', edgecolors='gray', label='existing acquisition with no frame burst (debug)')
    if epochdates:
        ax.scatter(epochdates,np.zeros(len(epochdates)), facecolors='none', edgecolors='red', label='existing acquisition')
    # adding timestamp
    timestamp = 'updated: '+str(dt.datetime.now().strftime("%Y-%m-%d %I:%M:%S"))
    plt.title(frame+', '+timestamp)
    ax.title.set_size(16)
    #plt.text(0.5,0.5,timestamp)
    plt.legend()
    ### Save
    plt.savefig(pngfile)
    plt.close()

if False:
    #%% File setting
    try:
        framedir = sys.argv[1]
        if framedir.endswith('/'):
            framedir=framedir[:-1]
        pngfile = sys.argv[2] 
        gapfile = sys.argv[3]
        try:
            islast = sys.argv[4]
            if islast == '1':
                check_common_bursts = True
                print('will check for the common bursts (more correct "red circles")')
        except:
            pass
    except:
        print('Usage: ')
        print('plot_network.py path_to_frame_directory out_png_file out_gaps_file [1]')
        print('(where the optional 1 will mean (long but correct) checking of the frame-related epochs based on bursts)')
        exit()

#framedir="/gws/nopw/j04/nceo_geohazards_vol1/public/LiCSAR_products.public/156/156D_11226_131313"
print(os.environ['LiCSAR_public'])
framedir=os.path.join(os.environ['LiCSAR_public'],"156","156D_11226_131313")
ifgdir = os.path.join(framedir, 'interferograms')
print(ifgdir)
bperp_file = os.path.join(framedir, 'metadata', 'baselines')
# try extract the frame id from folder name...
frame=os.path.basename(framedir)
frameprocdir = os.path.join(os.environ['LiCSAR_procdir'], str(int(frame[:3])), frame)
if os.path.exists(frameprocdir):
    temp_outbursts = os.path.join(frameprocdir, 'tmp.outburst_epochs.txt')
else:
    temp_outbursts = os.path.join(framedir, 'tmp.outburst_epochs.txt')

if not os.path.exists(ifgdir):
    # update to have it work in BATCH_CACHE_DIR
    ifgdir = os.path.join(framedir, 'GEOC')
    bperp_file = os.path.join(framedir, 'baselines')
    if not os.path.exists(ifgdir):
        print('error, no interferograms found for this frame')
        exit()
    else:
        print('generating baselines file in custom directory')
        cmd = 'cd {0}; mk_bperp_file.sh; mv baselines {1} 2>/dev/null'.format(framedir, bperp_file)
        rc = os.system(cmd)

#### TEST TEST  TEST   TEST    TEST ####
pngfile = "test.png"
gapfile= "test.txt"

if os.path.exists(pngfile):
    os.remove(pngfile)
if os.path.exists(gapfile):
   os.remove(gapfile)
#%%
ifgdates = tools_lib.get_ifgdates(ifgdir)
imdates = tools_lib.ifgdates2imdates(ifgdates)


if not os.path.exists(bperp_file):
    print('No baselines file exists. The Bperps will be estimated')
    frame = os.path.basename(framedir)
    bpd = fc.make_bperp_file(frame, bperp_file, donotstore=False)

# else:
# horrible fix but seems necessary...
rc = os.system("sed -i 's/\.0//g' "+bperp_file)
#    print('Make dummy bperp')
#    bperp_file = os.path.join(framedir,'baselines_tmp.txt')
#    io_lib.make_dummy_bperp(bperp_file, imdates)


try:
    bperp, ismissing = read_bperp_file(bperp_file, imdates, return_missflag = True)
    try:
        # just in case...
        bperp = np.array(bperp)
        bperp[np.isnan(bperp)] = 0
        absbp = np.abs(bperp)
        over = np.where(absbp>800)[0]
        if len(over)>0:
            print('WARNING, removing bperps that are over threshold of 800 m. These will be reestimated.')
            bperp[over]=0
            ismissing = True
    except:
        print('an error trying to remove bperps over 800 m')

    # double check missing - count zeroes
    if not ismissing:
        if len(bperp)>1:
            absbp=np.abs(bperp)
            absbp.sort()
            if absbp[1] == 0:
                ismissing = True
    if ismissing:
        print('some epochs have missing bperps, trying to find them through ASF')
        frame=os.path.basename(framedir)
        bperp=np.array(bperp)
        imdates=np.array(imdates)
        missingdates = imdates[bperp==0]
        missingdates2 = imdates[np.abs(bperp)>400]
        missingdates = np.concatenate((missingdates2, missingdates))
        missingdates2 = imdates[np.isnan(bperp)]
        missingdates = np.concatenate((missingdates2, missingdates))
        refdate = fc.get_master(frame)
        missingdates = missingdates[missingdates != refdate]
        # load existing
        prevbp = pd.read_csv(bperp_file, header=None, sep = ' ')
        prevbp.columns = ['ref_date', 'date', 'bperp', 'btemp']
        #print('TODO - remove missingepochs from prevbp')
        # get new - try first only from ASF (more accurate)
        bpd = fc.make_bperp_file(frame, bperp_file, asfonly = True, donotstore = True)
        stillmissing = []
        for m in missingdates:
            # first drop it from the prevbp:
            mint = int(m)
            prevbp = prevbp.drop(prevbp[prevbp.date == mint].index)
            mpd = bpd[bpd.date==m]
            if not mpd.empty:
                mbperp = mpd.bperp.mean()
                mbtemp = mpd.btemp.values[0]
                prevbp.loc[len(prevbp.index)] = [int(refdate), int(m), mbperp, int(mbtemp)] # new line
            else:
                #mbperp = 0
                #mbtemp = fc.datediff(refdate, m)
                print('no ASF information for epoch '+m+'. Adding for LiCSAR estimation.') #Storing only bperp=0')
                stillmissing.append(m)
                ''' NOT COMPLETE YET - SOMETHING IS WRONG IN THIS BELOW:
                print('no ASF information for epoch '+m+'. Estimating from LiCSAR db - slow way now') #Storing only bperp=0')
                try:
                    mepl, mbperpl = fc.get_bperp_estimates(frame, epochs = [m])
                    mbperp = round(mbperpl[0])
                except:
                    print('ERROR for epoch '+m+'. Setting zero.')
                    mbperp = 0
                '''
        if stillmissing:
            bperps = fc.estimate_bperps(frame, stillmissing, return_epochsdt=False)
            bperps = np.array(bperps).astype(int)
            i = 0
            for m in stillmissing:
                mbperp = bperps[i]
                mbtemp = fc.datediff(refdate, m)
                prevbp.loc[len(prevbp.index)] = [int(refdate), int(m), int(mbperp), int(mbtemp) ]
                i = i+1
        prevbp = prevbp.sort_values('btemp').reset_index(drop=True)
        #bpd.to_csv(bperp_file, sep = ' ', index = False, header = False)
        # bperps = bperps.astype(int)  # for some reason we still export as floats!
        for col in prevbp.columns:
            prevbp[col] = prevbp[col].astype(int)
        prevbp.to_csv(bperp_file, sep = ' ', index = False, header = False)
        bperp = read_bperp_file(bperp_file, imdates)
except:
    print('error reading baselines file! trying to fully recreate through ASF')
    try:
        if os.path.exists(bperp_file):
            os.remove(bperp_file)
        frame=os.path.basename(framedir)
        rc = fc.make_bperp_file(frame, bperp_file)
        bperp = read_bperp_file(bperp_file, imdates)
    except:
        print('some error occurred. Making dummy bperp')
        bperp_file = os.path.join(framedir,'baselines_tmp.txt')
        io_lib.make_dummy_bperp(bperp_file, imdates)
        bperp = read_bperp_file(bperp_file, imdates)

def LiCSAR_0_getFiles_inlist(frameName, imdates, zipListFile):
    if frameName == None:
        raise noFrameGivenError(frameName)
    if not lq.check_frame(frameName):
        raise undefinedFrameError(frameName)

    startDate = dt.datetime.strptime(imdates[0], '%Y%m%d')
    endDate = dt.datetime.strptime(imdates[-1], '%Y%m%d')

    print("Found frame definition in LiCS database - reading file list")

    ############################## Check files using scihub -> NLA

    print('checking for S1 data not ingested to licsinfo db')
    s1dataa = s1data.check_and_import_to_licsinfo(frameName, startDate.date(), endDate.date())
    print('check for existing S1 data finished')
    #if not s1dataa:
    #    print('no data to download found, quitting')
    #    return False

    ############################## Get file list
    print('getting file list')
    frameFilesTable = lq.get_frame_files_period(frameName,startDate.strftime('%Y-%m-%d'),endDate.strftime('%Y-%m-%d'))

    print("Stripping file list down to unique zipfiles")

    acq_dates = [f[1] for f in frameFilesTable]
    files = [f[3] for f in frameFilesTable]
    zipFiles = [re.sub('.metadata_only','',fI) for fI in files]
    
    if s1dataa:
        print('correcting paths for {} missing files'.format(len(s1dataa)))
        for s1f in s1dataa:
            s1neodc = s1data.get_neodc_path_images(s1f.split('.')[0])[0]
            if path.exists(s1neodc.replace('.zip','.manifest')):
                zipFiles.append(s1neodc)
                #files.append(s1neodc)
                s1f_date = dt.datetime.strptime(s1f.split('_')[5].split('T')[0],"%Y%m%d")
                acq_dates.append(s1f_date.date())

    #fix for zipFiles that are not in /neodc:
    for zipf in zipFiles:
        if 'neodc' not in zipf:
            removeddate = acq_dates.pop(zipFiles.index(zipf))
            zipFiles.remove(zipf)


    filesDF = pd.DataFrame({'files':zipFiles,'onTape':False},index=pd.to_datetime(acq_dates))
    filesDF = filesDF.drop_duplicates()

    print(filesDF)

    filesDF = filesDF[filesDF.index.isin(pd.to_datetime(imdates))]
    
    # this is to correct for duplicate images, see explanation at lq.get_frame_files_period
    pom=''
    pomDF=filesDF
    for index in pomDF.index.unique():
        for file in pomDF.loc[index]['files']:
            #if the previous field had the same base-name, drop this one
            if pom==file[:-9]:
                filesDF=filesDF[filesDF.files != file]
            else: pom=file[:-9]
    ############################## Write out file list

    print("Writing zip file list to {0}".format(zipListFile))
    zipdir = os.path.dirname(os.path.realpath(zipListFile))
    if not os.path.exists(zipdir):
        os.mkdir(zipdir)
    with open(zipListFile,'w') as f:
        # for zipFile in zipFiles:
        for date,zipFile in filesDF['files'].items():
            f.write(zipFile+"\n")

def save_preposed_ifgs(preposed, prepose_file="preposed_IFG_list.txt", save_epochs=False, epochs_file='db_quiry.List', ):
    with open(prepose_file, 'w') as f:
        for p in preposed:
            print(p, file=f)

    if save_epochs and False:
        epochs = set()
        for p in preposed:
            im1, im2 = p.split('_')
            epochs.add(im1)
            epochs.add(im2)
        epochs = list(epochs)
        epochs.sort()
        LiCSAR_0_getFiles_inlist(frame, epochs, epochs_file)

def prepose_by_bperp_and_time(ifgdates,imdates_all, bperp, bperp_diff_max = 5, days_diff_max = 365):
    preposed=[]
    imdates_all = tools_lib.ifgdates2imdates(ifgdates)
    imdates_dt_all = np.array(([dt.datetime.strptime(imd, '%Y%m%d') for imd in imdates_all])) ##datetime

    print(f"len bperp: {len(bperp)}")
    print(f"len imdates: {len(imdates)}")
    print(f"len imdates_all: {len(imdates_all)}")

    for i, imd in enumerate(imdates_dt_all):
        for j, imd_2 in enumerate(imdates_dt_all[i+1:], start=i+1):
            bperp_diff = abs(bperp[i]-bperp[j])
            days_diff = abs((imd-imd_2).days)

            if bperp_diff <= bperp_diff_max and days_diff <= days_diff_max:# if within user defined distance
                if f"{imd}_{imd_2}" not in ifgdates:
                    preposed.append(f"{imdates_all[i]}_{imdates_all[j]}")

    return preposed

def check_within_time(date1, date2, seperation, tolerance):
    delta = abs((date2 - date1).days)
    if abs(delta - seperation) <= tolerance:
        return True
    else:
        return False

def check_avoid_months(date1, date2, avoid_months):
    if date1.month in avoid_months or date2.month in avoid_months:
        return True
    else:
        return False

def check_bperp_difference(bperp1, bperp2, bperp_diff_max):
    if abs(bperp1 - bperp2) <= bperp_diff_max:
        return True
    else:
        return False

def prepose_by_length(ifgdates,imdates_all, bperp, seperation=365, tolerance=35, avoid_months=[], bperp_diff_max = 25,start_date = False, end_date = False):
    preposed=[]
    imdates_all = tools_lib.ifgdates2imdates(ifgdates)
    imdates_dt_all = np.array(([dt.datetime.strptime(imd, '%Y%m%d') for imd in imdates_all])) ##datetime

    if start_date:
        start_date_dt = dt.datetime.strptime(start_date, '%Y%m%d')
        imdates_dt_all = imdates_dt_all[imdates_dt_all >= start_date_dt]
    if end_date:
        end_date_dt = dt.datetime.strptime(end_date, '%Y%m%d')
        imdates_dt_all = imdates_dt_all[imdates_dt_all <= end_date_dt]

    print(f"len bperp: {len(bperp)}")
    print(f"len imdates: {len(imdates)}")
    print(f"len imdates_all: {len(imdates_all)}")

    for i, imd in enumerate(imdates_dt_all):
        for j, imd_2 in enumerate(imdates_dt_all[i+1:], start=i+1):
            if check_avoid_months(imd, imd_2, avoid_months):
                continue
            if not check_within_time(imd, imd_2, seperation, tolerance):
                continue
            if not check_bperp_difference(bperp[i], bperp[j], bperp_diff_max):
                continue

            if f"{imd}_{imd_2}" not in ifgdates:
                preposed.append(f"{imdates_all[i]}_{imdates_all[j]}")

    return preposed

def prepose_by_length_and_frequency(ifgdates,imdates_all, bperp, seperation=365, tolerance=35, avoid_months=[], month_frequency=4, bperp_diff_max = 35, start_date = False, end_date = False, reduce_for_existing = True):
    from collections import defaultdict
    preposed=[]
    imdates_all = tools_lib.ifgdates2imdates(ifgdates)
    imdates_dt_all = np.array(([dt.datetime.strptime(imd, '%Y%m%d') for imd in imdates_all])) ##datetime

    if start_date:
        start_date_dt = dt.datetime.strptime(str(start_date), '%Y%m%d')
        im_to_keep = imdates_dt_all >= start_date_dt

        imdates_dt_all = imdates_dt_all[im_to_keep]
        imdates_all = np.array(imdates_all)[im_to_keep]
        bperp = np.array(bperp)[im_to_keep]
        
        print(imdates_dt_all[imdates_dt_all < start_date_dt])
    if end_date:
        end_date_dt = dt.datetime.strptime(str(end_date), '%Y%m%d')
        im_to_keep = imdates_dt_all <= end_date_dt

        imdates_dt_all = imdates_dt_all[im_to_keep]
        imdates_all = np.array(imdates_all)[im_to_keep]
        bperp = np.array(bperp)[im_to_keep]

    
    # Group dates by (year, month)
    grouped = defaultdict(list)
    grouped_indices = defaultdict(list)
    
    for idx, date_time in enumerate(imdates_dt_all):
        key = (date_time.year, date_time.month)
        grouped[key].append(date_time)
        grouped_indices[key].append(idx)


    # Convert to a 2D list sorted by year and month
    sorted_keys = sorted(grouped.keys())  # [(2020,1), (2020,2), ..., (2021,12)]
    two_d_list = [grouped[key] for key in sorted_keys]
    two_d_indices = [grouped_indices[key] for key in sorted_keys]

    print(two_d_list)

    for month_num, month_dates in enumerate(two_d_list):
        month_preposed = []
        current_month_freq = month_frequency
        for i, imd in enumerate(month_dates):
            index_i = two_d_indices[month_num][i]
            for j, imd_2 in enumerate(imdates_dt_all[index_i+1:], start=index_i+1):
                if check_avoid_months(imd, imd_2, avoid_months):
                    continue
                if not check_within_time(imd, imd_2, seperation, tolerance):
                    continue
                if not check_bperp_difference(bperp[index_i], bperp[j], bperp_diff_max):
                    continue
                if f"{imd}_{imd_2}" not in ifgdates:
                    month_preposed.append([[imdates_all[index_i],imdates_all[j]], abs(bperp[index_i]-bperp[j])])
                elif reduce_for_existing:
                    current_month_freq = current_month_freq - 1

        if len(month_preposed) <= month_frequency:
            for candidate in month_preposed:
                preposed.append(f"{candidate[0][0]}_{candidate[0][1]}")
            continue
        # Sort month_preposed by bperp difference
        month_preposed.sort(key=lambda x: x[1])
        month_preposed = [prep[0] for prep in month_preposed]  # Remove bperp difference after sorting
        month_preposed = np.array(month_preposed)
        if current_month_freq <= 0:
            stop = True
        else:
            stop = False
        count = 0
        preposed_to_append = []
        month_doubles = []
        while not stop and count < len(month_preposed):
            candidate = month_preposed[count]
            if (candidate[0] not in month_preposed[:count,0]) and (candidate[1] not in month_preposed[:count,1]):
                #print(candidate[0], month_preposed[:count,0])#,0])#need to remove [:count,1] - can I split after sorting?
                preposed_to_append.append(candidate[0] + '_' + candidate[1])
            else:
                month_doubles.append(candidate[0] + '_' + candidate[1])
            if len(preposed_to_append) == current_month_freq:
                stop = True
            count += 1

        while len(preposed_to_append) < current_month_freq and len(month_doubles) > 0:
            preposed_to_append.append(month_doubles.pop(0))

        #if i % 5 == 0:
        print(f"Month {month_num+1}/{len(two_d_list)}: Appending {len(preposed_to_append)} preposed IFGs")
        print("Month Preposed IFGs:", month_preposed)
        print("Appended IFGs:", preposed_to_append)
        print("rejected IFGs:", month_doubles)
        print("Looking for", current_month_freq, "IFGs this month.")
        print("\n++++++++++++++++++++++++++++++++++\n")

        for p in preposed_to_append:
            preposed.append(p)

    print(preposed)
                
    return preposed

start_6 = 20170201
end_6 = 20211227

preposed_early = prepose_by_length_and_frequency(ifgdates, imdates, bperp, seperation=365, tolerance=50, bperp_diff_max = 45, month_frequency = 2, end_date = start_6+10000) #rest of year
preposed_6 = prepose_by_length_and_frequency(ifgdates, imdates, bperp, seperation=365, tolerance=20, bperp_diff_max = 35, start_date = start_6, end_date = end_6+10000) #June, July, August, September is Snowwy :))) APRIL, MArch??????
preposed_12 = prepose_by_length_and_frequency(ifgdates, imdates, bperp, seperation=365, tolerance=35, bperp_diff_max = 35, start_date = end_6) #rest of year

#preposed = preposed_early + preposed_6 + preposed_12 + ['20141016_20150613', '20141016_20150426', '20141203_20150426']
preposed = preposed_12
save_preposed_ifgs(preposed, save_epochs=True)


#print(preposed)
#print(len(preposed))
#print(len(ifgdates))
#print(ifgdates)
### 
frame = os.path.basename(framedir)
plot_preposed_network(ifgdates, bperp, frame, pngfile, preposed)
os.system('chmod 777 '+pngfile+' 2>/dev/null')
if False:
    os.system('chmod 777 '+bperp_file+' 2>/dev/null')
    rc = os.system("sed -i 's/\.0//g' "+bperp_file)  # just in case...
    ## Identify gaps
    G = inv_lib.make_sb_matrix(ifgdates)
    ixs_inc_gap = np.where(G.sum(axis=0)==0)[0]
    if ixs_inc_gap.size!=0:
        with open(gapfile, 'w') as f:
            for ix in ixs_inc_gap:
                print("{}_{}".format(imdates[ix], imdates[ix+1]), file=f)
