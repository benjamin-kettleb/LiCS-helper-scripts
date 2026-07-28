#!/usr/bin/env python3

import numpy as np
import sys, getopt
import matplotlib.pyplot as plt


args = sys.argv[1:]
options="hi:d:"
long_options = ["savename=", "delimiter=", "val_min=", "val_max="]

input_file = None
save_name= False
delim = "\t"
val_min = False
val_max = False


try:
    arguments, values = getopt.getopt(args, options, long_options)
    for currentArg, currentVal in arguments:
        if currentArg == "-h":
            print("Help placeholder")
        if currentArg == "-i":
            input_file = currentVal
        if currentArg == "--savename":
            save_name = currentVal
        if currentArg in ("-d", "--delimiter"):
            delim = currentVal
        if currentArg == "--val_min":
            val_min = int(currentVal)
            print(f"--val_min set to {val_min}. It is of dtype {type(val_min)}")
        if currentArg == "--val_max":
            val_max = int(currentVal)
    print(f"delimiter: {delim}")
except getopt.error as err:
    print(str(err))

if not(save_name):
    save_name="values_sumary.png"

ordered_list = np.loadtxt(input_file,dtype = [('IFG_dates', 'U17'),('list_value', float)],  delimiter=delim)

values=ordered_list['list_value']
print(ordered_list)
print(values)

if not(val_min):
    val_vmin=min(values)
if not(val_max):
    val_max=max(values)

print(f"val_min:{val_min}, val_max:{val_max}")

fig, ax = plt.subplots(3,1,figsize=(7,21))

ax[0].plot(values,np.arange(len(values)))
ax[0].set_ylabel("IFG #")
ax[0].set_xlabel("# nans")

ax[1].hist(values,bins=35,range=(val_min,val_max))
ax[1].set_xlabel("# nans")
ax[1].set_ylabel("Frequency")

threshold = np.linspace(val_min, val_max, 1000)
num_ifg = len(values)

percentage_below_t = []

for t in threshold:
    num_below=np.sum(values<=t)
    percentage_below_t.append(num_below/num_ifg*100)

ax[2].plot(threshold,percentage_below_t)
ax[2].set_xlabel("Threshold")
ax[2].set_ylabel("% ifg below threshold")

ax[0].set_xlim(val_min, val_max)
ax[1].set_xlim(val_min, val_max)
ax[2].set_xlim(val_min, val_max)

fig.savefig(save_name)
