#!/bin/bash

################## Script Information & Default Configuration ##################

# macOS Forensic Imaging Script
# Copyright 2022 City of Phoenix and Joshua Bodine
# Written by Joshua Bodine <joshua.bodine@phoenix.gov>

# On August 16, 2022, Assistant City Attorney Eric Thornhill and Digital
# Forensics Investigative Unit supervisor Sergeant Ryan Moskop granted approval
# for this script to be shared on an open-source basis.  This script is
# therefore released under the terms of the MIT license.  Please refer to the
# included file "COPYING.txt" for further information.

# Please refer to the included file "README.txt" for information regarding
# script features and usage.  Please especially note the recommendation to use
# another tool to inhibit mounts (or set new mounts to read-only) prior to
# connecting any evidentiary device(s) for imaging using this script.

SCRIPT_VERSION=2

SOURCE_PATH=
DESTINATION_PATH=
IMAGE_NAME=

REHASH_SOURCE=
BLOCK_SIZE=

# internal use only, not advertised in usage
ORIGINAL_UID=
ORIGINAL_GID=
NO_CONFIRM=

######################## Argument Parsing & Validation #########################

print_usage() {
	echo "Usage: macOS\\ Forensic\\ Imaging\\ Script.command" 1>&2
	echo "               [--rehash-source] [--block-size=<number>]" 1>&2
	echo "               [<source path>] [<destination path>] [<image name>]" 1>&2
}

# Inspired by this StackOverflow answer: https://stackoverflow.com/a/14203146
POSITIONAL_ARGUMENTS=()
for ARGUMENT in "$@" ; do
	case $ARGUMENT in
		--rehash-source)
			REHASH_SOURCE=1
			;;
		--block-size=*)
			BLOCK_SIZE="$(echo "$ARGUMENT" | sed 's/[^=]*=//')"
			;;
		--original-uid=*)
			ORIGINAL_UID="$(echo "$ARGUMENT" | sed 's/[^=]*=//')"
			;;
		--original-gid=*)
			ORIGINAL_GID="$(echo "$ARGUMENT" | sed 's/[^=]*=//')"
			;;
		--no-confirm)
			NO_CONFIRM=1
			;;
		--help|-help|-h)
			print_usage
			exit
			;;
		--*|-*)
			echo "Unknown argument: $ARGUMENT"
			print_usage
			exit 1
			;;
		*)
			POSITIONAL_ARGUMENTS+=("$ARGUMENT")
			;;
	esac
done
set -- "${POSITIONAL_ARGUMENTS[@]}"
if [ "$#" -gt 3 ] ; then
	echo "Too many arguments."
	print_usage
	exit 1
fi

# if all positional arguments were provided (and this is not a recursive run),
# disable prompting the user to confirm the arguments prior to imaging; if this
# is a recursive run, this was already set (if applicable) by the previous
# iteration via --no-confirm
if [ -z "$ORIGINAL_UID" ] && [ -z "$ORIGINAL_GID"] && [ "$#" -eq 3 ] ; then
	NO_CONFIRM=1
fi

# print the script information header (if this is not a recursive run)
if [ -z "$ORIGINAL_UID" ] && [ -z "$ORIGINAL_GID" ] ; then
	INFO_HEADER="macOS Forensic Imaging Script, Version $SCRIPT_VERSION"
	echo $INFO_HEADER
	NUM_CHARS="$(echo -n "$INFO_HEADER" | wc -c)"
	while [ "$NUM_CHARS" -gt 0 ] ; do printf "-" ; NUM_CHARS="$(($NUM_CHARS - 1))" ; done ; echo
fi

# check that the block size from the arguments (if set) is a positive integer
# (inspired by this StackOverflow answer: https://stackoverflow.com/a/3951175)
case $BLOCK_SIZE in
	*[!0-9]*)
		echo "Block size \"$BLOCK_SIZE\" is invalid.  Exiting."
		exit 1
		;;
esac

# parse the source path from the arguments or else prompt for it, and then
# verify it exists as a regular file, block device, or character device
if [ "$#" -gt 0 ] ; then
	SOURCE_PATH="$1"
else
	echo -n "Source Path: "
	read SOURCE_PATH
	if [ -z "$SOURCE_PATH" ] ; then
		echo "No imaging source specified.  Exiting."
		exit 1
	fi
fi
if [ ! -f "$SOURCE_PATH" ] && [ ! -b "$SOURCE_PATH" ] && [ ! -c "$SOURCE_PATH" ] ; then
	echo "The source \"$SOURCE_PATH\" cannot be opened as a file, block device, or character device.  Exiting."
	exit 1
fi

# parse the destination path from the arguments or else prompt for it, and then
# verify it exists as a directory and is writable
if [ "$#" -gt 1 ] ; then
	DESTINATION_PATH="$2"
else
	echo -n "Destination Path: "
	read DESTINATION_PATH
	if [ -z "$DESTINATION_PATH" ] ; then
		echo "No destination directory specified.  Exiting."
		exit 1
	fi
fi
if [ ! -d "$DESTINATION_PATH" ] ; then
	echo "The destination directory \"$DESTINATION_PATH\" cannot be opened as a directory.  Exiting."
	exit 1
fi
if [ ! -w "$DESTINATION_PATH" ] ; then
	echo "The destination directory \"$DESTINATION_PATH\" is not writable.  Exiting."
	exit 1
fi

# parse the image name from the arguments or else prompt for it, and then verify
# it does not already exist
if [ "$#" -gt 2 ] ; then
	IMAGE_NAME="$3"
else
	echo -n "Image Name: "
	read IMAGE_NAME
	if [ -z "$IMAGE_NAME" ] ; then
		echo "No image name specified.  Exiting."
		exit 1
	fi
fi
IMAGE_DIR="$DESTINATION_PATH/$IMAGE_NAME"
if [ -e "$IMAGE_DIR" ] ; then
	echo "The file or directory \"$IMAGE_DIR\" already exists.  Exiting."
	exit 1
fi

##################### Permissions Check & Imaging Summary ######################

# print an extra newline if this is a recursive execution using sudo or if we
# prompted the user for any arguments
if [ ! -z "$ORIGINAL_UID" ] && [ ! -z "$ORIGINAL_GID" ] || [ "$#" -lt 3 ] ; then echo ; fi

# check whether the source is readable; if not, try to escalate to root
# privileges using sudo and then start over from the beginning (passing existing
# arguments through); if we are already root and still cannot read the source,
# then fail and exit
if [ ! -r "$SOURCE_PATH" ] ; then
	if [ "$(id -u)" -ne 0 ] ; then
		echo "Unable to read the source file or device.  Attempting to escalate to root"
		echo "privileges using sudo.  You may be prompted for your password."

		ARG_REHASH_SOURCE= ; if [ ! -z "$REHASH_SOURCE" ] ; then ARG_REHASH_SOURCE=" --rehash-source" ; fi
		ARG_BLOCK_SIZE= ; if [ ! -z "$BLOCK_SIZE" ] ; then ARG_BLOCK_SIZE=" --block-size=$BLOCK_SIZE" ; fi
		ARG_NO_CONFIRM= ; if [ ! -z "$NO_CONFIRM" ] ; then ARG_NO_CONFIRM=" --no-confirm" ; fi
		sudo "$0" $ARG_REHASH_SOURCE $ARG_BLOCK_SIZE $ARG_NO_CONFIRM --original-uid=$(id -u) --original-gid=$(id -g) "$SOURCE_PATH" "$DESTINATION_PATH" "$IMAGE_NAME"
		exit $?
	else
		echo "The source \"$SOURCE_PATH\" exists but is not readable.  Exiting."
		exit 1
	fi
fi

# show the imaging settings summary, and prompt the user to continue or cancel
# (unless all required arguments were provided on the command line)
echo Imaging will now proceed with the following settings:
echo -----------------------------------------------------
echo "Source Path:       $SOURCE_PATH"
echo "Destination Path:  $DESTINATION_PATH"
echo "Image Name:        $IMAGE_NAME"
if [ ! -z $REHASH_SOURCE ] ; then
	echo "Re-hash Source:    Yes"
else
	echo "Re-hash Source:    No"
fi
if [ ! -z $BLOCK_SIZE ] ; then
	echo "Block Size:        $BLOCK_SIZE"
elif [ ! -z "$(echo "$SOURCE_PATH" | grep -E '^/dev/(r)?disk[0-9]+(s[0-9]+)?$')" ] ; then
	echo "Block Size:        (From Device)"
fi
if [ -z "$NO_CONFIRM" ] ; then
	echo
	echo Press enter to continue, or Ctrl-C to cancel.
	read -rs
fi
echo

############################# Imaging Preparation ##############################

# attempt to create the output directory and the subdirectory for logs
mkdir "$IMAGE_DIR" 2> /dev/null
if [ "$?" -ne 0 ] ; then
	echo "The directory \"$IMAGE_DIR\" could not be created.  Exiting."
	exit 1
fi
LOGS_DIR=$IMAGE_DIR/.Logs
mkdir "$LOGS_DIR" 2> /dev/null
if [ "$?" -ne 0 ] ; then
	echo "The directory \"$LOGS_DIR\" could not be created.  Exiting."
	rm -r "$IMAGE_DIR" 2> /dev/null
	exit 1
fi

# use the specified block size if applicable; otherwise, if the source is a
# block or character device, try to determine its block size
if [ "$BLOCK_SIZE" ] ; then
	ARG_DD_BLOCK_SIZE="bs=$BLOCK_SIZE"
elif [ ! -z "$(echo "$SOURCE_PATH" | grep -E '^/dev/(r)?disk[0-9]+(s[0-9]+)?$')" ] ; then
	ARG_DD_BLOCK_SIZE="bs=$(diskutil info $SOURCE_PATH | grep -i "Device Block Size" | awk '{print $4}')"
else
	ARG_DD_BLOCK_SIZE=
fi

# perform a test read of the first block of the source
dd conv=sync,noerror $ARG_DD_BLOCK_SIZE count=1 if="$SOURCE_PATH" of=/dev/null 2>> "$LOGS_DIR/Test Read (dd).txt"
if [ "$?" -ne 0 ] ; then
	echo "*** ERROR READING SOURCE ***  The source may be in use or it may have been"
	echo "disconnected or removed.  If the source is a disk partition containing a volume"
	echo "which is currently mounted, you should unmount the volume and run this script"
	echo "again.  The following error was reported:"
	echo
	cat "$LOGS_DIR/Test Read (dd).txt"
	echo
	echo "Unable to read source.  Exiting."
	rm -r "$IMAGE_DIR" 2> /dev/null
	exit 1
fi

# add the script and configuration information to the log
MAIN_LOG_FILE="$IMAGE_DIR/$IMAGE_NAME.txt"
echo Log output of macOS Forensic Imaging Script, Version $SCRIPT_VERSION > "$MAIN_LOG_FILE"
echo >> "$MAIN_LOG_FILE"
echo Configuration >> "$MAIN_LOG_FILE"
echo ------------- >> "$MAIN_LOG_FILE"
echo "Source Path:       $SOURCE_PATH" >> "$MAIN_LOG_FILE"
echo "Destination Path:  $DESTINATION_PATH" >> "$MAIN_LOG_FILE"
echo "Image Name:        $IMAGE_NAME" >> "$MAIN_LOG_FILE"
if [ ! -z $REHASH_SOURCE ] ; then
	echo "Re-hash Source:    Yes" >> "$MAIN_LOG_FILE"
else
	echo "Re-hash Source:    No" >> "$MAIN_LOG_FILE"
fi
if [ ! -z $BLOCK_SIZE ] ; then
	echo "Block Size:        $BLOCK_SIZE" >> "$MAIN_LOG_FILE"
elif [ ! -z "$(echo "$SOURCE_PATH" | grep -E '^/dev/(r)?disk[0-9]+(s[0-9]+)?$')" ] ; then
	echo "Block Size:        (From Device)" >> "$MAIN_LOG_FILE"
fi
echo >> "$MAIN_LOG_FILE"

# if the source is a whole disk or partition, add the diskutil info to the log
if [ ! -z "$(echo "$SOURCE_PATH" | grep -E '^/dev/(r)?disk[0-9]+(s[0-9]+)?$')" ] ; then
	echo Disk Information >> "$MAIN_LOG_FILE"
	echo ---------------- >> "$MAIN_LOG_FILE"
	echo diskutil info $SOURCE_PATH >> "$MAIN_LOG_FILE"
	diskutil info $SOURCE_PATH >> "$MAIN_LOG_FILE"
	# a blank line is already printed at the end of the command output
fi

# suggest a command for monitoring progress during the image acquisition
echo "During the imaging process, you can monitor progress by checking the current"
echo "image size with the following command (in a separate terminal window):"
echo
echo "du -h \"$IMAGE_DIR/$IMAGE_NAME.dd\""
echo

####################### Image Acquisition & Verification #######################

# acquire the image
ACQUISITION_START="$(date +%s)"
echo -n "Acquiring image... "
dd conv=sync,noerror $ARG_DD_BLOCK_SIZE if="$SOURCE_PATH" 2>> "$LOGS_DIR/Acquisition (dd).txt" | tee >(md5 > "$LOGS_DIR/Acquisition (MD5).txt") >(shasum -a 1 > "$LOGS_DIR/Acquisition (SHA1).txt") > "$IMAGE_DIR/$IMAGE_NAME.dd"
echo "done."
ACQUISITION_END="$(date +%s)"

# append the individual acquisition log files to the main log
append_log () {
	# wait for tee and md5/shasum to finish writing
	while [ "$(cat "$LOGS_DIR/$1 (MD5).txt" | wc -c)" -eq 0 ] ; do sleep 0.1 ; done
	while [ "$(cat "$LOGS_DIR/$1 (SHA1).txt" | wc -c)" -eq 0 ] ; do sleep 0.1 ; done

	# append the designated log files to the main log
	echo "$1" >> "$MAIN_LOG_FILE"
	NUM_CHARS="$(echo -n $1 | wc -c)" ; while [ "$NUM_CHARS" -gt 0 ] ; do printf "-" >> "$MAIN_LOG_FILE" ; NUM_CHARS="$(($NUM_CHARS - 1))" ; done ; echo >> "$MAIN_LOG_FILE"
	cat "$LOGS_DIR/$1 (dd).txt" >> "$MAIN_LOG_FILE"
	printf "MD5:   %s\n" $(cat "$LOGS_DIR/$1 (MD5).txt") >> "$MAIN_LOG_FILE"
	printf "SHA1:  %s\n\n" $(cat "$LOGS_DIR/$1 (SHA1).txt" | awk '{print $1}') >> "$MAIN_LOG_FILE" # omit filename, which is just STDIN
}
append_log "Acquisition"

# calculate post-imaging hashes of the source (if applicable) and the image, and
# append them to the log
echo -n "Calculating " ; if [ ! -z "$REHASH_SOURCE" ] ; then echo -n "source verification and " ; fi ; echo -n "image verification hashes... "
if [ ! -z "$REHASH_SOURCE" ] ; then
	( dd conv=sync,noerror $ARG_DD_BLOCK_SIZE if="$SOURCE_PATH" 2>> "$LOGS_DIR/Source Verification (dd).txt" | tee >(md5 > "$LOGS_DIR/Source Verification (MD5).txt") >(shasum -a 1 > "$LOGS_DIR/Source Verification (SHA1).txt") > /dev/null ) &
fi
( dd conv=sync,noerror $ARG_DD_BLOCK_SIZE if="$IMAGE_DIR/$IMAGE_NAME.dd" 2>> "$LOGS_DIR/Image Verification (dd).txt" | tee >(md5 > "$LOGS_DIR/Image Verification (MD5).txt") >(shasum -a 1 > "$LOGS_DIR/Image Verification (SHA1).txt") > /dev/null ) &
wait
echo "done."
VERIFICATION_END="$(date +%s)"

# append the verification log file(s) to the main log
if [ ! -z "$REHASH_SOURCE" ] ; then append_log "Source Verification" ; fi
append_log "Image Verification"

############################ Final Checks & Logging ############################

# check for any mismatched hashes and report the result, and also report the
# pertinent start and end times
echo Summary >> "$MAIN_LOG_FILE"
echo ------- >> "$MAIN_LOG_FILE"
echo
if [ ! -z "$(cmp "$LOGS_DIR/Source Verification (MD5).txt" "$LOGS_DIR/Acquisition (MD5).txt" 2> /dev/null)" ] || # ignore error in case we aren't re-hashing the source
   [ ! -z "$(cmp "$LOGS_DIR/Source Verification (SHA1).txt" "$LOGS_DIR/Acquisition (SHA1).txt" 2> /dev/null)" ] ||
   [ ! -z "$(cmp "$LOGS_DIR/Image Verification (MD5).txt" "$LOGS_DIR/Acquisition (MD5).txt")" ] ||
   [ ! -z "$(cmp "$LOGS_DIR/Image Verification (SHA1).txt" "$LOGS_DIR/Acquisition (SHA1).txt")" ] ; then
	echo "*** HASH MISMATCH DETECTED ***  Please check the log file for further details."
	echo "Hash Comparison:    Mismatch" >> "$MAIN_LOG_FILE"
else
	echo "All hashes match."
	echo "Hash Comparison:    Match" >> "$MAIN_LOG_FILE"
fi
ACQUISITION_DURATION=$(($ACQUISITION_END - $ACQUISITION_START))
VERIFICATION_DURATION=$(($VERIFICATION_END - $ACQUISITION_END))
echo "Acquisition Start:  $(date -r $ACQUISITION_START +"%Y-%m-%d %T %Z")" >> "$MAIN_LOG_FILE"
echo -n "Acquisition Done:   $(date -r $ACQUISITION_END +"%Y-%m-%d %T %Z") (" >> "$MAIN_LOG_FILE"
printf "Duration: %d:%02d:%02d)\n" $(($ACQUISITION_DURATION / 3600)) $(($ACQUISITION_DURATION % 3600 / 60)) $(($ACQUISITION_DURATION % 60)) >> "$MAIN_LOG_FILE"
echo -n "Verification Done:  $(date -r $VERIFICATION_END +"%Y-%m-%d %T %Z") (" >> "$MAIN_LOG_FILE"
printf "Duration: %d:%02d:%02d)\n" $(($VERIFICATION_DURATION / 3600)) $(($VERIFICATION_DURATION % 3600 / 60)) $(($VERIFICATION_DURATION % 60)) >> "$MAIN_LOG_FILE"

# clean up
rm -rf "$LOGS_DIR" 2> /dev/null # the individual command outputs have already been incorporated into the main log file
if [ ! -z "$ORIGINAL_UID" ] && [ ! -z "$ORIGINAL_GID" ] ; then
	chown -R $ORIGINAL_UID:$ORIGINAL_GID "$IMAGE_DIR" # restore the original owner and group (if we escalated to root privileges)
fi
chflags uchg "$IMAGE_DIR/$IMAGE_NAME.dd" # lock the image file to to prevent inadvertent changes

echo
echo Process complete.

exit
