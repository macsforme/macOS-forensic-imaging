#!/bin/bash

# macOS Forensic Imaging Script
# By Joshua Bodine #9544 (joshua.bodine@phoenix.gov), Phoenix Police Department
SCRIPT_VERSION=0

# To-do
# -----
# check whitespace usage
# quotes around all "$1" etc.? https://stackoverflow.com/questions/10067266/when-should-i-wrap-quotes-around-a-shell-variable
# do paths really needed to be quoted or escaped? maybe just on the command line?
# decide on consistent terminology for destination/target/image/etc.
# check that script works in zsh as well as bash, and change first line to /bin/sh?
# remove 123... space checks
# re-test all paths of execution
# Version 0 => Version 1

if [ "$#" -eq 4 ] && [ "$4" != "rehashsource" ] || [ "$#" -gt 4 ] ; then
	echo "Usage: [source path] [destination path] [image name] [rehashsource]"
	exit
fi

# show some information about this script (if called without arguments)
if [ "$#" -eq 0 ] ; then
#            "01234567890123456789012345678901234567890123456789012345678901234567890123456789"
	echo "macOS Forensic Imaging Script, Version $SCRIPT_VERSION"
	echo "By Joshua Bodine #9544 (joshua.bodine@phoenix.gov), Phoenix Police Department"
	echo "-----------------------------------------------------------------------------"
	echo "This script creates a binary image of a file or block device (e.g., /dev/disk3)"
	echo "on a system running macOS.  When creating an image of an external device (such"
	echo "as another computer in target disk mode, or a storage device connected via USB,"
	echo "Thunderbolt, FireWire, etc.), it is recommended to use a tool such as Disk"
	echo "Arbitrator by Aaron Burghardt (https://github.com/aburgh/Disk-Arbitrator) to"
	echo "set new mounts to read-only mode (or block new mounts) prior to connecting the"
	echo "device(s) to be imaged.  If your imaging destination is an external drive, be"
	echo "sure to connect your destination drive before doing so, and also ensure that"
	echo "your destination drive has enough available capacity to store the binary image."
	echo
	echo "Any paths with spaces in them must be properly quoted (e.g., \"Path with Spaces\")"
	echo "or escaped (e.g., Path\\ with\\ Spaces).  This is done automatically by macOS if"
	echo "you provide the paths by dragging and dropping the folders into this terminal"
	echo "window.  Please also provide absolute paths (e.g., /Users/<username>/Documents)"
	echo "rather than relative paths (e.g., ~/Documents or ../Documents)."
#            "01234567890123456789012345678901234567890123456789012345678901234567890123456789"
	echo
fi

# set the imaging source (if provided on the command line) or else prompt for
# it, and then verify it exists as a block device or file
if [ "$#" -gt 0 ] ; then
	IMAGING_SOURCE=$1
else
	echo -n "Source Path: "
	read IMAGING_SOURCE
	if [ -z "$IMAGING_SOURCE" ] ; then
		echo "No imaging source specified.  Exiting."
		exit
	fi
fi
if [ ! -b "$IMAGING_SOURCE" ] && [ ! -f "$IMAGING_SOURCE" ] ; then 
	echo "The source \"$IMAGING_SOURCE\" cannot be opened as a file or block device.  Exiting."
	exit
fi

# set the destination directory (if provided on the command line) or else prompt
# for it, and verify it exists as a directory and is writable
if [ "$#" -gt 1 ] ; then
	DEST_DIR=$2
else
	echo -n "Destination Path: "
	read DEST_DIR
	if [ -z "$DEST_DIR" ] ; then
		echo "No destination directory specified.  Exiting."
		exit
	fi
fi
if [ ! -d "$DEST_DIR" ] ; then
	echo "The destination directory \"$DEST_DIR\" cannot be opened as a directory.  Exiting."
	exit
fi
if [ ! -w "$DEST_DIR" ] ; then
	echo "The destination directory \"$DEST_DIR\" is not writable.  Exiting."
	exit
fi

# set the image name to use for the directory and image file (if provided on the
# command line) or else prompt for it, and verify it does not exist already
if [ "$#" -gt 2 ] ; then
	IMAGE_NAME=$3
else
	echo -n "Image Name: "
	read IMAGE_NAME
	if [ -z "$IMAGE_NAME" ] ; then
		echo "No image name specified.  Exiting."
		exit
	fi
fi
IMAGE_DIR="$DEST_DIR/$IMAGE_NAME"
if [ -e "$IMAGE_DIR" ] ; then
	echo "The file or directory \"$IMAGE_DIR\" already exists.  Exiting."
	exit
fi

# determine whether we will re-hash the source after imaging it (either using
# the command-line argument, or else prompt for it)
if [ ! -z "$REHASH_SOURCE" ] && [ "$REHASH_SOURCE" = "Yes" ] || [ "$#" -eq 4 ] ; then
	REHASH_SOURCE=Yes # we already verified that $4 is "rehashsource" if it exists
elif [ "$#" -eq 3 ] ; then
	REHASH_SOURCE=No # if the other three arguments were specified, the default behavior is not to re-hash the source
else
	echo -n "Re-hash source after imaging? (y/N): "
	read REHASH_SOURCE
	if [ "$REHASH_SOURCE" = "" ] ||
	   [ "$(echo $REHASH_SOURCE | awk '{print tolower($0)}')" = "n" ] ||
	   [ "$(echo $REHASH_SOURCE | awk '{print tolower($0)}')" = "no" ] ; then
		REHASH_SOURCE=No
	elif [ "$(echo $REHASH_SOURCE | awk '{print tolower($0)}')" = "y" ] ||
	     [ "$(echo $REHASH_SOURCE | awk '{print tolower($0)}')" = "yes" ] ; then
		REHASH_SOURCE=Yes
	else
		echo "Unknown response.  Exiting."
	fi
fi

# print an extra newline if we prompted the user for any arguments, of if this
# is a recursive execution using sudo
if [ "$#" -lt 3 ] || [ ! -z "$RECURSIVE_RUN" ] ; then echo ; fi

# check whether the imaging source is readable; if not, try to escalate to root
# privileges (if we are not already root) using sudo and re-run the script; if
# so, fail and exit
if [ ! -r "$IMAGING_SOURCE" ] ; then
	if [ "$(id -u)" -ne 0 ] ; then
		echo "Unable to read the source file or device.  Attempting to escalate to root"
		echo "privileges using sudo.  You may be prompted for your password."
		sudo RECURSIVE_RUN=1 PREV_ARGS_COUNT=$# REHASH_SOURCE=$REHASH_SOURCE "$0" "$IMAGING_SOURCE" "$DEST_DIR" "$IMAGE_NAME"
		exit
	else
		echo "The source \"$IMAGING_SOURCE\" exists but is not readable.  Exiting."
		exit
	fi
fi

# show the imaging settings summary, and prompt the user to continue or cancel
# (unless all required arguments were provided on the command line)
echo Imaging will now proceed with the following settings:
echo -----------------------------------------------------
echo "Source Path:       $IMAGING_SOURCE"
echo "Destination Path:  $DEST_DIR"
echo "Image Name:        $IMAGE_NAME"
echo "Re-hash Source:    $REHASH_SOURCE"
if [ ! -z "$PREV_ARGS_COUNT" ] && [ "$PREV_ARGS_COUNT" -lt 3 ] || [ "$#" -lt 3 ] ; then
	echo
	echo Press enter to continue, or Ctrl-C to cancel.
	read -rs
fi

# attempt to create the output directory and the subdirectory for logs
mkdir "$IMAGE_DIR" 2> /dev/null
if [ "$?" -ne 0 ] ; then
	echo "The directory \"$IMAGE_DIR\" could not be created.  Exiting."
 	exit
fi
LOGS_DIR=$IMAGE_DIR/Logs
mkdir "$LOGS_DIR" 2> /dev/null
if [ "$?" -ne 0 ] ; then
	echo "The directory \"$LOGS_DIR\" could not be created.  Exiting."
 	exit
fi

# add the script and configuration information to the log
echo macOS Forensic Imaging Script, Version $SCRIPT_VERSION > "$IMAGE_DIR/$IMAGE_NAME.txt"
echo >> "$IMAGE_DIR/$IMAGE_NAME.txt"
echo Configuration >> "$IMAGE_DIR/$IMAGE_NAME.txt"
echo ------------- >> "$IMAGE_DIR/$IMAGE_NAME.txt"
echo "Source Path:       $IMAGING_SOURCE" >> "$IMAGE_DIR/$IMAGE_NAME.txt"
echo "Destination Path:  $DEST_DIR" >> "$IMAGE_DIR/$IMAGE_NAME.txt"
echo "Image Name:        $IMAGE_NAME" >> "$IMAGE_DIR/$IMAGE_NAME.txt"
echo >> "$IMAGE_DIR/$IMAGE_NAME.txt"

# acquire the image
ACQUISITION_START=$(date +%s)
echo
echo -n "Acquiring image... "
dd conv=sync,noerror if="$IMAGING_SOURCE" 2>> "$LOGS_DIR/Acquisition (dd).txt" | tee >(md5 > "$LOGS_DIR/Acquisition (MD5).txt") >(shasum -a 1 > "$LOGS_DIR/Acquisition (SHA1).txt") > "$IMAGE_DIR/$IMAGE_NAME.dd"
echo "done."
ACQUISITION_END=$(date +%s)

# calculate post-imaging hashes of the source (if applicable) and the image, and
# append them to the log
echo -n "Calculating "
if [ "$REHASH_SOURCE" = Yes ] ; then echo -n "source verification and " ; fi
echo -n "image verification hashes... "
if [ "$REHASH_SOURCE" = Yes ] ; then
	( dd conv=sync,noerror if="$IMAGING_SOURCE" 2>> "$LOGS_DIR/Source Verification (dd).txt" | tee >(md5 > "$LOGS_DIR/Source Verification (MD5).txt") >(shasum -a 1 > "$LOGS_DIR/Source Verification (SHA1).txt") > /dev/null ) &
fi
( dd conv=sync,noerror if="$IMAGE_DIR/$IMAGE_NAME.dd" 2>> "$LOGS_DIR/Image Verification (dd).txt" | tee >(md5 > "$LOGS_DIR/Image Verification (MD5).txt") >(shasum -a 1 > "$LOGS_DIR/Image Verification (SHA1).txt") > /dev/null ) &
wait
echo "done."
VERIFICATION_END=$(date +%s)

# append the individual log files (as applicable) to the main log
append_log () {
	# wait for tee and md5/shasum to finish writing
	while [ "$(cat "$LOGS_DIR/$1 (MD5).txt" | wc -c)" -eq 0 ] ; do sleep 0.1 ; done
	while [ "$(cat "$LOGS_DIR/$1 (SHA1).txt" | wc -c)" -eq 0 ] ; do sleep 0.1 ; done

	# append the designated log files to the main log
	echo $1 >> "$IMAGE_DIR/$IMAGE_NAME.txt"
	NUM_CHARS="$(echo -n $1 | wc -c)" ; while [ $NUM_CHARS -gt 0 ] ; do printf "-" >> "$IMAGE_DIR/$IMAGE_NAME.txt" ; NUM_CHARS=$(($NUM_CHARS - 1)) ; done ; echo >> "$IMAGE_DIR/$IMAGE_NAME.txt"
	cat "$LOGS_DIR/$1 (dd).txt" >> "$IMAGE_DIR/$IMAGE_NAME.txt"
	printf "MD5:   %s\n" $(cat "$LOGS_DIR/$1 (MD5).txt") >> "$IMAGE_DIR/$IMAGE_NAME.txt"
	printf "SHA1:  %s\n\n" $(cat "$LOGS_DIR/$1 (SHA1).txt" | awk '{print $1}') >> "$IMAGE_DIR/$IMAGE_NAME.txt" # omit filename, which is just STDIN
}
append_log "Acquisition"
if [ "$REHASH_SOURCE" = Yes ] ; then append_log "Source Verification" ; fi
append_log "Image Verification"

# check for any mismatched hashes and report the result, and also report the
# pertinent start and end times
echo Summary >> "$IMAGE_DIR/$IMAGE_NAME.txt"
echo ------- >> "$IMAGE_DIR/$IMAGE_NAME.txt"
echo
if [ ! -z "$(cmp "$LOGS_DIR/Source Verification (MD5).txt" "$LOGS_DIR/Acquisition (MD5).txt" 2> /dev/null)" ] || # ignore error in case we aren't re-hashing the source
   [ ! -z "$(cmp "$LOGS_DIR/Source Verification (SHA1).txt" "$LOGS_DIR/Acquisition (SHA1).txt" 2> /dev/null)" ] ||
   [ ! -z "$(cmp "$LOGS_DIR/Image Verification (MD5).txt" "$LOGS_DIR/Acquisition (MD5).txt")" ] ||
   [ ! -z "$(cmp "$LOGS_DIR/Image Verification (SHA1).txt" "$LOGS_DIR/Acquisition (SHA1).txt")" ] ; then
	echo "*** HASH MISMATCH DETECTED ***  Please check the log file for further details."
	echo "Hash Comparison:    Mismatch" >> "$IMAGE_DIR/$IMAGE_NAME.txt"
else
	echo "All hashes match."
	echo "Hash Comparison:    Match" >> "$IMAGE_DIR/$IMAGE_NAME.txt"
fi
ACQUISITION_DURATION=$(($ACQUISITION_END - $ACQUISITION_START))
VERIFICATION_DURATION=$(($VERIFICATION_END - $ACQUISITION_END))
echo "Acquisition Start:  $(date -r $ACQUISITION_START +"%Y-%m-%d %T %Z")" >> "$IMAGE_DIR/$IMAGE_NAME.txt"
echo -n "Acquisition Done:   $(date -r $ACQUISITION_END +"%Y-%m-%d %T %Z") (" >> "$IMAGE_DIR/$IMAGE_NAME.txt"
printf "%d:%02d:%02d" $(($ACQUISITION_DURATION / 3600)) $(($ACQUISITION_DURATION % 3600 / 60)) $(($ACQUISITION_DURATION % 60)) >> "$IMAGE_DIR/$IMAGE_NAME.txt"
echo \) >> "$IMAGE_DIR/$IMAGE_NAME.txt"
echo -n "Verification Done:  $(date -r $VERIFICATION_END +"%Y-%m-%d %T %Z") (" >> "$IMAGE_DIR/$IMAGE_NAME.txt"
printf "%d:%02d:%02d" $(($VERIFICATION_DURATION / 3600)) $(($VERIFICATION_DURATION % 3600 / 60)) $(($VERIFICATION_DURATION % 60)) >> "$IMAGE_DIR/$IMAGE_NAME.txt"
echo \) >> "$IMAGE_DIR/$IMAGE_NAME.txt"

echo
echo Process complete.
