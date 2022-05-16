#!/bin/bash

if [ "$#" -gt 3 ] ; then
	echo "Too many arguments; format is: [source path] [destination path] [image name]"
	exit
fi

# show some information about this script (if called without arguments)
if [ "$#" -eq 0 ] ; then
	echo 01234567890123456789012345678901234567890123456789012345678901234567890123456789
	echo Some helpful information at the top. Make sure there is enough space on your
	echo destination device for the full image. We should not be reading the source three
	echo times; the post-imaging source hashes should be be tied into the same read
	echo operation if possible. Make sure to \(what did I forget?\)...
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
		echo "No imaging source specified. Exiting."
		exit
	fi
fi
if [ ! -b "$IMAGING_SOURCE" ] && [ ! -f "$IMAGING_SOURCE" ] ; then 
	echo "The source \"$IMAGING_SOURCE\" cannot be found. Exiting."
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
		echo "No destination directory specified. Exiting."
		exit
	fi
fi
if [ ! -d "$DEST_DIR" ] ; then
	echo "The destination directory \"$DEST_DIR\" cannot be found. Exiting."
	exit
fi
if [ ! -w "$DEST_DIR" ] ; then
	echo "The destination directory \"$DEST_DIR\" exists but is not writable. Exiting."
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
		echo "No image name specified. Exiting."
		exit
	fi
fi
if [ -e "$DEST_DIR/$IMAGE_NAME" ] ; then
	echo "The file or directory \"$DEST_DIR/$IMAGE_NAME\" already exists. Exiting."
	exit
fi

# print an extra newline if we prompted the user for any arguments, of if this
# is a recursive execution using sudo
if [ "$#" -lt 3 ] || [ ! -z "$RECURSIVE_RUN" ] ; then echo ; fi

# check whether the imaging source is readable; if not, try to escalate to root
# privileges (if we are not already root) using sudo and re-run the script; if
# so, fail and exit
if [ ! -r "$IMAGING_SOURCE" ] ; then
	if [ "$(id -u)" -ne 0 ] ; then
		echo "Unable to read the source file. Attempting to escalate to root privileges using"
		echo "sudo. You may be prompted for your password."
		sudo RECURSIVE_RUN=1 "$0" "$IMAGING_SOURCE" "$DEST_DIR" "$IMAGE_NAME"
		exit
	else
		echo "The source \"$IMAGING_SOURCE\" exists but is not readable. Exiting."
		exit
	fi
fi

# show the imaging settings summary, and prompt the user to continue or cancel
echo Imaging will now proceed with the following settings:
echo -----------------------------------------------------
echo Source Path: $IMAGING_SOURCE
echo Destination Path: $DEST_DIR
echo Image Name: $IMAGE_NAME
echo -----------------------------------------------------
echo Press enter to continue, or Ctrl-C to cancel.
#read -rs

# attempt to create the output directory
mkdir "$DEST_DIR/$IMAGE_NAME" 2> /dev/null
if [ "$?" -ne 0 ] ; then
	echo "The directory \"$DEST_DIR/$IMAGE_NAME\" could not be created. Exiting."
 	exit
fi

# acquire the image
echo
echo -n "Acquiring image (this may take some time)... "
dcfldd conv=sync,noerror status=off hash=md5,sha1 if="$IMAGING_SOURCE" of="$DEST_DIR/$IMAGE_NAME/$IMAGE_NAME.dd" 2> "$DEST_DIR/$IMAGE_NAME/$IMAGE_NAME.txt"
echo "done."

# calculate the post-imaging hashes and append them to the log file
echo -n "Calculating post-imaging hashes... "
echo >> "$DEST_DIR/$IMAGE_NAME/$IMAGE_NAME.txt"
echo "Post-Imaging Hashes" >> "$DEST_DIR/$IMAGE_NAME/$IMAGE_NAME.txt"
echo -n "    MD5 (Source):       " >> "$DEST_DIR/$IMAGE_NAME/$IMAGE_NAME.txt"
md5 -r "$IMAGING_SOURCE" >> "$DEST_DIR/$IMAGE_NAME/$IMAGE_NAME.txt"
echo -n "    MD5 (Destination):  " >> "$DEST_DIR/$IMAGE_NAME/$IMAGE_NAME.txt"
md5 -r "$DEST_DIR/$IMAGE_NAME/$IMAGE_NAME.dd" >> "$DEST_DIR/$IMAGE_NAME/$IMAGE_NAME.txt"
echo >> "$DEST_DIR/$IMAGE_NAME/$IMAGE_NAME.txt"
echo -n "    SHA1 (Source):      " >> "$DEST_DIR/$IMAGE_NAME/$IMAGE_NAME.txt"
shasum -a 1 "$IMAGING_SOURCE" >> "$DEST_DIR/$IMAGE_NAME/$IMAGE_NAME.txt"
echo -n "    SHA1 (Destination): " >> "$DEST_DIR/$IMAGE_NAME/$IMAGE_NAME.txt"
shasum -a 1 "$DEST_DIR/$IMAGE_NAME/$IMAGE_NAME.dd" >> "$DEST_DIR/$IMAGE_NAME/$IMAGE_NAME.txt"
echo "done."

echo
echo Process complete.
