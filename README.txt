
By Joshua Bodine #9544 (joshua.bodine@phoenix.gov), Phoenix Police Department
-----------------------------------------------------------------------------
Describe licensing arrangement, etc.

This script creates a binary image of a file or block device (e.g., /dev/disk3)
on a system running macOS.  When creating an image of an external device (such
as another computer in target disk mode, or a storage device connected via USB,
Thunderbolt, FireWire, etc.), it is recommended to use a tool such as Disk
Arbitrator by Aaron Burghardt (https://github.com/aburgh/Disk-Arbitrator) to
set new mounts to read-only mode (or block new mounts) prior to connecting the
device(s) to be imaged.  If your imaging destination is an external drive, be
sure to connect your destination drive before doing so, and also ensure that
your destination drive has enough available capacity to store the binary image.

Any paths with spaces in them must be properly quoted (e.g., "Path with Spaces")
or escaped (e.g., Path with Spaces).  This is done automatically by macOS if
you provide the paths by dragging and dropping the folders into this terminal
window.  Please also provide absolute paths (e.g., /Users/<username>/Documents)
rather than relative paths (e.g., ~/Documents or ../Documents).

Note that when imaging a whole disk or disk partition, in some cases you can
increase performance by imaging the "raw" device node (e.g., /dev/rdisk#) rather
than the standard block device node (e.g., /dev/disk#).  However, in some cases
the inverse may be true, so for large disks you may wish to perform a benchmark
first (for example, by imaging a small partition on the drive, if available).

Make sure there's enough space on your device...