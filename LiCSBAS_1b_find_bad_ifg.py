import os
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import shutil
import glob
from osgeo import gdal
import LiCSBAS_tools_lib as tools_lib
from matplotlib.widgets import Button

geocdir = './GEOC'
ifgdates = tools_lib.get_ifgdates(geocdir)
n_ifg = len(ifgdates)
"""
### First check if float already exist

for i, ifgd in enumerate(ifgdates):
    unw_tiffile = os.path.join(geocdir, ifgd, ifgd+'.geo.unw.tif')
    if not os.path.exists(unw_tiffile):
        print ('  No {} found. Skip'.format(ifgd+'.geo.unw.tif'), flush=True)
        break
    try:
        unw = gdal.Open(unw_tiffile).ReadAsArray()
        unw[unw==0] = np.nan
    except: ## if broken
        print ('  {} cannot open. Skip'.format(ifgd+'.geo.unw.tif'), flush=True)
        shutil.rmtree(ifgdir1)
        break
"""

# Initialize variables for animation
current_index = 0
paused = True
ifgdates2 = []

# Initialize lists for bad epochs and bad interferograms
bad_epoc = []
bad_ifg = []
deleted_ifg = []

review_mode = False  # Flag to indicate if we are reviewing bad_ifg
review_index = 0     # Index for reviewing bad_ifg

def update_plot(frame):
    global current_index, paused, review_mode
    if paused or review_mode:
        return
    if current_index >= len(ifgdates2):
        # Switch to review mode when the main animation ends
        review_mode = True
        current_index = 0
        print("Switching to review mode for bad_ifg list.")
        show_review_image()
        return
    # Use the show_image function to display the current image
    show_image(current_index)
    current_index += 1

def toggle_pause(event):
    global paused
    paused = not paused

def print_current_ifgd(event):
    global current_index, bad_epoc, bad_ifg
    if current_index > 0 and current_index <= len(ifgdates2):
        ifgd = ifgdates2[current_index]# - 1]
        print(f"Current Image: {ifgd}")
        
        # Split the ifg name into two dates
        date1, date2 = ifgd.split('_')
        
        # Append unique dates to bad_epoc
        if date1 not in bad_epoc:
            bad_epoc.append(date1)
        if date2 not in bad_epoc:
            bad_epoc.append(date2)
        
        # Append the full ifg name to bad_ifg
        if ifgd not in bad_ifg:
            bad_ifg.append(ifgd)

        # Print the updated lists for debugging
        print(f"Updated bad_epoc: {bad_epoc}")
        print(f"Updated bad_ifg: {bad_ifg}")

print("Checking Valid IFGS")
# Collect valid ifgdates
for i, ifgd in enumerate(ifgdates):
    unw_tiffile = os.path.join(geocdir, ifgd, ifgd + '.geo.unw.tif')
    if not os.path.exists(unw_tiffile):
        print('  No {} found. Skip'.format(ifgd + '.geo.unw.tif'), flush=True)
        continue
    try:
        unw = gdal.Open(unw_tiffile).ReadAsArray()
        unw[unw == 0] = np.nan
        ifgdates2.append(ifgd)
    except:
        print('  {} cannot open. Skip'.format(ifgd + '.geo.unw.tif'), flush=True)
        continue

# Create the plot
fig, ax = plt.subplots()
plt.subplots_adjust(bottom=0.2)

# Add buttons
ax_pause = plt.axes([0.7, 0.05, 0.1, 0.075])
btn_pause = Button(ax_pause, 'Pause')
btn_pause.on_clicked(toggle_pause)

ax_print = plt.axes([0.81, 0.05, 0.1, 0.075])
btn_print = Button(ax_print, 'Print')
btn_print.on_clicked(print_current_ifgd)

def show_image(index):
    """Helper function to display the image at the given index."""
    ifgd = ifgdates2[index]
    unw_tiffile = os.path.join(geocdir, ifgd, ifgd + '.geo.unw.tif')
    unw = gdal.Open(unw_tiffile).ReadAsArray()
    unw[unw == 0] = np.nan
    ax.clear()
    ax.imshow(unw, cmap='viridis')
    ax.set_title(f"Image: {ifgd}")
    
    # Check if the ifg contains an epoch in bad_epoc
    date1, date2 = ifgd.split('_')
    if date1 in bad_epoc or date2 in bad_epoc:
        ax.text(0.5, -0.1, "Ifg contains epoc in common with bad IFG", 
                color='red', fontsize=12, ha='center', transform=ax.transAxes)

def next_image(event):
    """Show the next image when paused."""
    global current_index
    if paused and current_index < len(ifgdates2) - 1:
        current_index += 1
        show_image(current_index)

def previous_image(event):
    """Show the previous image when paused."""
    global current_index
    if paused and current_index > 0:
        current_index -= 1
        show_image(current_index)

# Add "Next" and "Previous" buttons
ax_next = plt.axes([0.59, 0.05, 0.1, 0.075])
btn_next = Button(ax_next, 'Next')
btn_next.on_clicked(next_image)

ax_prev = plt.axes([0.48, 0.05, 0.1, 0.075])
btn_prev = Button(ax_prev, 'Previous')
btn_prev.on_clicked(previous_image)

def show_review_image():
    """Display the current interferogram from the bad_ifg list."""
    global review_index, deleted_fig
    if review_index < len(bad_ifg):
        ifgd = bad_ifg[review_index]
        unw_tiffile = os.path.join(geocdir, ifgd, ifgd + '.geo.unw.tif')
        unw = gdal.Open(unw_tiffile).ReadAsArray()
        unw[unw == 0] = np.nan
        ax.clear()
        ax.imshow(unw, cmap='viridis')
        # Set the title in red for review mode
        ax.set_title(f"Reviewing: {ifgd}", color='red')
    else:
        print("Review of bad_ifg list completed.")
        plt.close()  # Close the plot when review is done
        print("Saving deleted IFGs to deleted_ifg.txt")
        with open(filename, "w") as file:
            for to_del in deleted_ifg:
                file.write(f"{to_del}\n")

def keep_ifg(event):
    """Keep the current interferogram and move to the next one."""
    global review_index
    if review_index < len(bad_ifg):
        review_index += 1
        show_review_image()

def delete_ifg(event):
    """Delete the folder containing the current interferogram."""
    global review_index, deleted_ifg
    if review_index < len(bad_ifg):
        ifgd = bad_ifg[review_index]
        ifg_folder = os.path.join(geocdir, ifgd)
        try:
            shutil.rmtree(ifg_folder)  # Delete the folder
            print(f"Deleted folder for {ifgd}")
            deleted_ifg.append(ifgd)
        except Exception as e:
            print(f"Error deleting folder for {ifgd}: {e}")
        review_index += 1
        show_review_image()

# Reposition "Keep" and "Delete" buttons to the far left of the frame
ax_keep = plt.axes([0.05, 0.05, 0.1, 0.075])  # Adjusted position
btn_keep = Button(ax_keep, 'Keep')
btn_keep.on_clicked(keep_ifg)

ax_delete = plt.axes([0.16, 0.05, 0.1, 0.075])  # Adjusted position
btn_delete = Button(ax_delete, 'Delete')
btn_delete.on_clicked(delete_ifg)

print("Animating Now")

# Start animation
ani = animation.FuncAnimation(fig, update_plot, interval=1000, cache_frame_data=False)

# Display the animation
plt.show()