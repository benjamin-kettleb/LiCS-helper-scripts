#!/usr/bin/env python3

import getopt, sys
import os
import glob
from osgeo import gdal
import numpy as np
from time import sleep

def save_sorted(arr, savename, lowest_at_top = True, testing=False, save_values = False):
    sorted_arr = np.sort(arr, order='list_value')
    if not(lowest_at_top):
        sorted_arr = sorted_arr[::-1]
    if testing and not save_values:
        file_base, ext = os.path.splitext(savename)
        testing_savename = file_base+"_testing"+ext
        np.savetxt(testing_savename, sorted_arr, fmt="%s", delimiter="\t")
    if save_values:
        np.savetxt(savename, sorted_arr, fmt="%s", delimiter="\t")
    else:
        np.savetxt(savename, sorted_arr['IFG_dates'], fmt="%s")

args = sys.argv[1:]
options="nsri:htvl:"
long_options = ["nan", "speckel", "ramp", "ifg_dir=", "save_name=", "testing", "no_values", "input_list="]

do_nans = False
do_speckel = False
do_ramp = False
testing = False
save_values = True
input_list = False

ifgdir = False
save_name = False

try:
    arguments, values = getopt.getopt(args, options, long_options)
    print(f"arguments:\n{arguments}\nvalues:\n{values}")
    for currentArg, currentVal in arguments:
        if currentArg == "-h":
            print("Help placeholder")
        if currentArg in ("-n","--nan"):
            do_nans = True
            print(f"Detected {currentArg} Flag. do_nans set to {do_nans}")
        if currentArg in ("-s","--speckel"):
            do_speckel = True
            print(f"Detected {currentArg} Flag. do_speckel set to {do_speckel}")
        if currentArg in ("-r","--ramp"):
            do_ramp = True
            print(f"Detected {currentArg} Flag. do_ramp set to {do_ramp}")
        if currentArg in ("-i","--ifg_dir"):
            ifgdir = currentVal
            print(f"Detected {currentArg} Flag. ifgdir set to {ifgdir}")
        if currentArg == "--save_name":
            save_name = currentVal
            print(f"Detected {currentArg} Flag. save_name set to {save_name}")
        if currentArg in ("-t", "--testing"):
            testing = True
            print(f"Detected {currentArg} Flag. testing set to {testing}")
        if currentArg in ("-v", "--no_values"):
            save_values = False
            print(f"Detected {currentArg} Flag. save_values set to {save_values}")
        if currentArg in ("-l", "--input_list"):
            input_list = currentVal
            print(f"Detected {currentArg} Flag. input_list to {input_list}")
except getopt.error as err:
    print(str(err))

print("Starting Program in 5ive seconds...")
sleep(5)
print("Begining to read .tiffs")

if do_nans or do_speckel or do_ramp:
    if ifgdir == False:
        frame_name = os.path.basename(os.getcwd())
        track=frame_name[:3]
        LiCSAR_public = os.environ["LiCSAR_public"]
        ifgdir=os.path.join(LiCSAR_public, track, frame_name, "interferograms")
    if input_list:
       
        with open(input_list) as f:
             dirs_to_open = [line.strip() for line in f if line.strip()]

        # Collect all matching files
        unwr = []
        for d in dirs_to_open:
            pattern = os.path.join(ifgdir, d, "*.geo.unw.tif")
            unwr.extend(glob.glob(pattern))

    else:
       unwr = glob.glob(os.path.join(ifgdir, "*", "*.geo.unw.tif"))
    

    n_ifg = len(unwr)

    list_dtype = [('IFG_dates', 'U17'),('list_value', float)]

    num_nans = []
    grad_ramp = []
    std_speckel = []
    for ifg_num, ifg_tif in enumerate(unwr):
        try:
            # Open in read-only mode
            ifg_ds = gdal.Open(ifg_tif, gdal.GA_ReadOnly)
            ifg = ifg_ds.GetRasterBand(1).ReadAsArray()
            ifg[ifg==0] = np.nan
            ifg_name = os.path.basename(os.path.dirname(ifg_tif))
        except:
            continue
        if do_nans:
            num_nans.append((ifg_name,np.isnan(ifg).sum()))
        if ifg_num==20 and testing:
            break
    num_nans = np.array(num_nans, dtype = list_dtype)
    if save_name == False:
        save_name = frame_name + ".sorted_ifgs"
        if save_values:
            save_name += "_and_values"
    save_sorted(num_nans, save_name+".nans", lowest_at_top = False, testing=testing, save_values = save_values)
