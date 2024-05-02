macOS Forensic Imaging Script
Copyright 2022 - 2024 City of Phoenix and Joshua Bodine
Written by Joshua Bodine <joshua.bodine@phoenix.gov>
https://github.com/macsforme/macOS-forensic-imaging

----------------------------- License Information ------------------------------

On August 16, 2022, Assistant City Attorney Eric Thornhill and Digital
Forensics Investigative Unit supervisor Sergeant Ryan Moskop granted approval
for this script to be shared on an open-source basis.  This script is therefore
released under the terms of the MIT license.  Please refer to the included file
"COPYING.txt" for further information.

------------------------------------ Usage -------------------------------------

This script creates a binary (dd) image of a file or block device on a system
running macOS.  This is primarily useful when needing to acquire a forensic
image of another Apple computer connected via target disk mode, but may also be
used to acquire an image of an external storage device connected via USB,
Thunderbolt, FireWire, etc.  The steps used by the author to acquire an image
(given here as an example) are as follows:

1. Connect the target drive where the image will be saved (if not using
   internal storage), ensuring it has sufficient available capacity to store
   a full binary image of the source device or drive.
2. Block new devices from mounting (or set new mounts to read-only mode) using
   a tool such as Disk Arbitrator by Aaron Burghardt
   (https://github.com/aburgh/Disk-Arbitrator).
3. Connect your source device or drive.
4. Run this script.

The following optional arguments are available (these should be specified on the
command line when executing this script):

[--rehash-source]        A second hash of the source file, device, or drive
                         will be calculated after the image is acquired.

[--block-size=<number>]  Adjust the block size parameter (bs=n) passed to the
                         dd command (see the discussion below in the
                         "Optimization" section).

The following positional arguments may be specified on the command line, or they
may be entered later during script execution when prompted:

[<source path>]          Specify the source path from which the image will be
                         acquired (e.g., "/dev/rdisk3" or "/dev/disk2s1").

[<destination path>]     Specify the directory path where the image will be
                         saved (a new directory with the image name will be
                         created within this folder).

[<image name>]           Specify the name of the image as desired (e.g., "Item
                         #123456 Pink 2017 Apple MacBook Internal 256GB SSD").

Note that any paths specified on the command line which have spaces or special
characters in them must be properly quoted (e.g., "Path with Spaces") or
escaped (e.g., Path\ with\ Spaces).  This is done automatically by macOS if you
provide the paths by dragging and dropping the folders into the terminal window.
Please also provide absolute paths (e.g., /Users/<username>/Documents) rather
than relative paths (e.g., ~/Documents or ../Documents).

--------------------------------- Optimization ---------------------------------

This script internally uses the "dd" shell command, which is known to have
varied performance based on factors such as the specified block size, whether
the source is a "buffered block-special device" (/dev/disk node) or a
"character-special device" (/dev/rdisk node; see `man hdiutil` for further
information), etc.  By default, this script automatically detects the device
block size (usually 512 or 4096) and passes this block size to the dd command
This method is generally the safest option, although the imaging process may be
slower than ideal.  However, if time is of the essence (for example, the data
is considered exigent, or the source device has to be imaged while running on
battery power), optimizations may be possible.

The first optimization is to determine whether the /dev/disk node or the
/dev/rdisk node provides better performance.  In testing, each node type
performed better than the other in certain circumstances, so there is no firm
rule for which node type is preferable.  You can perform a benchmark by reading
a small amount of data from each node type and compare the durations.  WARNING:
the dd command is dangerous and is capable of overwriting data on your source
drive or device, so this is NOT recommended for those who are unfamiliar with
the dd command syntax!  Example:

user@host ~ % sudo dd bs=512 count=2097152 if=/dev/disk3 > /dev/null
1073741824 bytes transferred in 52.418817 secs (20483900 bytes/sec)

user@host ~ % sudo dd bs=512 count=2097152 if=/dev/rdisk3 > /dev/null
1073741824 bytes transferred in 396.669084 secs (2706896 bytes/sec)

The second optimization is to specify a larger block size so that more data is
read at a time.  You can use the command `diskutil info /dev/disk#`
(substituting the respective disk number), and find the "Device Block Size" as
well as the "Disk Size" in bytes.  Then, find a multiple of the device block
size which is an even divisor of the total number of bytes in the drive, and
pass this value to the script using the --block-size argument.  WARNING: if you
use a block size which is not an even divisor of the total number of bytes in
the drive (with no remainder), you will end up with extra empty bytes at the
end of your image, and your image size and hashes will not be correct!  Example:

251000193024 (disk size) / 32768 (specified block size) = 7659918 (okay)

1000555581440 (disk size) / 32768 (specified block size) = 30534533.125 (bad)

----------------------------------- Examples -----------------------------------

./macOS\ Forensic\ Imaging\ Script.command /dev/disk3 "/Volumes/Target Disk" \
    "Item #123456 Pink 2017 Apple MacBook Internal 256GB SSD"

./macOS\ Forensic\ Imaging\ Script.command /dev/rdisk3s2 /Volumes/Target\ Disk \
    "Raw Disk 3 Partition 2"

./macOS\ Forensic\ Imaging\ Script.command --rehash-source --block-size=32768 \
    /dev/rdisk2 "/Volumes/Target\ Disk" "Disk 2, Block Size 32768"

---------------------------------- Conclusion ----------------------------------

Please report any questions or issues to the author via the GitHub issue
tracker, or via email to the address listed at the top of this file.
