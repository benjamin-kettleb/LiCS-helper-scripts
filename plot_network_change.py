#!/usr/bin/env python3

import getopt, sys
import LiCSBAS_plot_lib as plot_lib
import LiCSBAS_tools_lib as tools_lib
import LiCSBAS_io_lib as io_lib
import LiCSBAS_inv_lib as inv_lib

import warnings
import numpy as np
import os
import datetime as dt

import warnings
import matplotlib as mpl
with warnings.catch_warnings(): ## To silence user warning
    warnings.simplefilter('ignore', UserWarning)
    mpl.use('Agg')
from matplotlib import pyplot as plt
from matplotlib import dates as mdates
from matplotlib import colors



args = sys.argv[1:]
options="hi:s:l:f:b:p:t:e:o:a:r"
long_options = ["=ifgs", "=second_ifgs", "=label", "=frame", "=bperp", "=png_file", "=scale_time", "=scale_bperp", "=font_size", "=label_font"]

ifg_file = False
bad_ifgs = False
bad_ifgs_label = False
frame_name = False
bperp_filename = False
png_img = False
scale_time = 1
scale_bperp = 1
font_size = 12
label_font_size = 10
plot_right = False

try:
    arguments, values = getopt.getopt(args, options, long_options)
    for currentArg, currentVal in arguments:
        if currentArg == "-h":
            print("Help placeholder")
        if currentArg in ("-i","--ifgs"):
            ifg_file = currentVal
        if currentArg in ("-s","--second_ifgs"):
            bad_ifgs = currentVal
        if currentArg in ("-l","--label"):
            bad_ifgs_label = currentVal
        if currentArg in ("-f","--frame"):
            frame_name = currentVal
        if currentArg in ("-b","--bperp"):
            bperp_filename = currentVal
        if currentArg in ("-p","--png_file"):
            png_img = currentVal
        if currentArg in ("-t","--scale_time"):
            scale_time = float(currentVal)
        if currentArg in ("-e","--scale_bperp"):
            scale_bperp = float(currentVal)
        if currentArg in ("-o", "--font_size"):
            font_size = float(currentVal)
        if currentArg in ("-a", "--label_font"):
            label_font_size = float(currentVal)
        if currentArg in ("-r", "--plot_right"):
            plot_right = True
except getopt.error as err:
    print(str(err))

if frame_name and ifg_file:
    if bperp_filename:
        raise exception("Frame cannot be user defined if both ifgs and perp file are")
    else:
        raise warnings.warn("Both frame and ifgs defined. Proceeding only using the frame to import bperp file and not ifgs")
elif frame_name and bperp_filename:
    raise warnings.warn("Both frame and bperp are define (but ifgs are not). This is a wierd but valid usecase. Proceeding only using the frame to import ifgs but not bperp file")

if frame_name == False:
    frame_name = os.path.basename(os.getcwd())
    track=frame_name[:3]
    LiCSAR_public = os.environ["LiCSAR_public"]
    ifgdir=os.path.join(LiCSAR_public, track, frame_name, "interferograms")
    metadir=os.path.join(LiCSAR_public, track, frame_name, "metadata")

if ifg_file == False:
    ifgdates = tools_lib.get_ifgdates(ifgdir)
else:
    ifgdates=[]
    with open(ifg_file, 'r', encoding='utf-8') as file:
        # Strip newline characters and ignore empty trailing lines
        ifgdates = [line.rstrip('\n') for line in file] 

imdates = tools_lib.ifgdates2imdates(ifgdates)


if bperp_filename == False:
    bperp_filename = os.path.join(metadir,"baselines")
    print(bperp_filename)

if os.path.exists(bperp_filename): ###This if statement from LiCSBAS
    with open(bperp_filename, 'r') as f:
        lines = [line.strip() for line in f if line.strip()]  # Remove empty lines
    if len(lines) >= len(imdates):  # Ensure enough entries
        bperp = io_lib.read_bperp_file(bperp_filename, imdates)
    else:
        ##baselines file contain fewer entries than the number of ifgs, so dummy values will be used
        bperp = np.random.random(len(imdates)).tolist()
else:  # Generate dummy baselines if file doesn't exist
    print(f"WARNING: Baselines file not found. Using dummy values.")
    bperp = np.random.random(len(imdates)).tolist()

if bad_ifgs == False:
    bad_ifgdates = ifgdates[:2]
    plot_bad = False
else:
    plot_bad = True
    bad_ifgdates=[]
    with open(bad_ifgs, 'r', encoding='utf-8') as file:
        # Strip newline characters and ignore empty trailing lines
        bad_ifgdates = [line.rstrip('\n') for line in file]


if bad_ifgs_label == False:
    bad_ifgs_label = "Removed IFG"

if png_img == False:
    png_img = os.path.join(os.getcwd(),"network_rmv.png")
print(png_img)

print(f"ifgdates:{ifgdates}")

#plot_lib.plot_network(ifgdates, bperp, bad_ifgdates, png_img, plot_bad, bad_ifgs_label)

def plot_network(ifgdates, bperp, rm_ifgdates, pngfile, plot_bad=True, label_name='Removed IFG',scale_time=1, scale_bperp = 1, plot_right = False):
    """
    Plot network of interferometric pairs. FROM LiCSBAS

    bperp can be dummy (-1~1).
    Suffix of pngfile can be png, ps, pdf, or svg.
    plot_bad
        True  : Plot bad ifgs by red lines
        False : Do not plot bad ifgs
    """
    if label_name is None:
        label_name = 'Removed IFG'

    imdates_all = tools_lib.ifgdates2imdates(ifgdates)
    n_im_all = len(imdates_all)
    imdates_dt_all = np.array(([dt.datetime.strptime(imd, '%Y%m%d') for imd in imdates_all])) ##datetime

    ifgdates = list(set(ifgdates)-set(rm_ifgdates))
    ifgdates.sort()
    imdates = tools_lib.ifgdates2imdates(ifgdates)
    n_im = len(imdates)
    imdates_dt = np.array(([dt.datetime.strptime(imd, '%Y%m%d') for imd in imdates])) ##datetime

    ### Identify gaps
    G = inv_lib.make_sb_matrix(ifgdates)
    ixs_inc_gap = np.where(G.sum(axis=0)==0)[0]

    ### Plot fig
    figsize_x = np.round(((imdates_dt_all[-1]-imdates_dt_all[0]).days)/80)+2

    print(f"figsize_x: {figsize_x} - {type(figsize_x)}")
    print(f"scale_time: {scale_time} - {type(scale_time)}")
    fig = plt.figure(figsize=(figsize_x * scale_time, 6 * scale_bperp))
    ax = fig.add_axes([0.06, 0.12, 0.92,0.85])

    ### IFG blue lines
    for i, ifgd in enumerate(ifgdates):
        ix_m = imdates_all.index(ifgd[:8])
        ix_s = imdates_all.index(ifgd[-8:])
        label = 'IFG' if i==0 else '' #label only first
        plt.plot([imdates_dt_all[ix_m], imdates_dt_all[ix_s]], [bperp[ix_m],
                bperp[ix_s]], color='b', alpha=0.6, zorder=2, label=label)

    ### IFG bad red lines
    if plot_bad:
        for i, ifgd in enumerate(rm_ifgdates):
            ix_m = imdates_all.index(ifgd[:8])
            ix_s = imdates_all.index(ifgd[-8:])
            label = label_name if i==0 else '' #label only first
            plt.plot([imdates_dt_all[ix_m], imdates_dt_all[ix_s]], [bperp[ix_m],
                    bperp[ix_s]], color='r', alpha=0.6, zorder=6, label=label)

    ### Image points and dates
    ax.scatter(imdates_dt_all, bperp, alpha=0.6, zorder=4)
    for i in range(n_im_all):
        if bperp[i] > np.median(bperp): va='bottom'
        else: va = 'top'
        ax.annotate(imdates_all[i][4:6]+'/'+imdates_all[i][6:],
                    (imdates_dt_all[i], bperp[i]), ha='center', va=va, zorder=8, fontsize=label_font_size)

    ### gaps
    if len(ixs_inc_gap)!=0:
        gap_dates_dt = []
        for ix_gap in ixs_inc_gap:
            ddays_td = imdates_dt[ix_gap+1]-imdates_dt[ix_gap]
            gap_dates_dt.append(imdates_dt[ix_gap]+ddays_td/2)
        plt.vlines(gap_dates_dt, 0, 1, transform=ax.get_xaxis_transform(),
                   zorder=1, label='Gap', alpha=0.6, colors='k', linewidth=3)

    ### Locater
    # loc = ax.xaxis.set_major_locator(mdates.AutoDateLocator())
    locator = mdates.AutoDateLocator()
    ax.xaxis.set_major_locator(locator)
    try:  # Only support from Matplotlib 3.1
        # locator.axis = ax.xaxis # not sure if this needed?
        ax.xaxis.set_major_formatter(mdates.ConciseDateFormatter(locator))
    except:
        ax.xaxis.set_major_formatter(mdates.DateFormatter('%Y/%m/%d'))
        for label in ax.get_xticklabels():
            label.set_rotation(20)
            label.set_horizontalalignment('right')
    ax.grid(which='major')

    ### Add bold line every 1yr
    ax.xaxis.set_minor_locator(mdates.YearLocator())
    ax.grid(which='minor', linewidth=2)

    ax.set_xlim((imdates_dt_all[0]-dt.timedelta(days=10),
                 imdates_dt_all[-1]+dt.timedelta(days=10)))

    ### Labels and legend
    plt.xlabel('Time', fontsize=font_size)
    if np.all(np.abs(np.array(bperp))<=1): ## dummy
        plt.ylabel('dummy', fontsize=font_size)
    else:
        plt.ylabel('Bperp [m]', fontsize=font_size)

    plt.legend(fontsize=font_size)
    plt.xticks(fontsize=font_size)
    plt.yticks(fontsize=font_size)

    if plot_right:
        print("Plotting right!!")
        ax.yaxis.tick_right()
        ax.yaxis.set_label_position("right")

    ### Save
    try:
        plt.savefig(pngfile) #, bbox_inches='tight')
    except:
        print('WARNING, generating network plot failed - new matplotlib changes?')
    plt.close()

    return len(ixs_inc_gap)


plot_network(ifgdates, bperp, bad_ifgdates, png_img, plot_bad, bad_ifgs_label, scale_time, scale_bperp, plot_right)
