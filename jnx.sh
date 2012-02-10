#!/bin/bash

#IMAGE=top25-grenoble.jpg
#NORTH=45.236345982245915
#SOUTH=45.015576018020703
#EAST=5.886258718271238
#WEST=5.565537433019793
JPEGQUALITY=75

usage() {
	cat <<EOF
Usage
 $0 -i <source image> -N <higher lat> -S <lower lat> -E <higher lon> -W <lower lon> [-o <output name>]
   The source image must be a JPEG. Width and height must be a multiple of 1024.
   Latitude and Longitude must be given in the WGS84 projection system.
Example: 
 $0 -i top25-grenoble.jpg -N 45.236345982245915 -S 45.015576018020703 -E 5.886258718271238 -W 5.565537433019793
Options:
   -i source image
   -N	North
   -S	South 
   -E	East
   -W	West
   -o output name
   -K	Keep tiff file
   -h	Print this message
EOF
exit 1
}
while getopts "i:o:N:S:E:W:x:j:t:kKRfh" OPTION; do
	case $OPTION in
		i)
		IMAGE=$OPTARG
		;;
		o)
		DEST=$OPTARG
		;;
		N)
		NORTH=$OPTARG
		;;
		S)
		SOUTH=$OPTARG
		;;
		E)
		EAST=$OPTARG
		;;
		W)
		WEST=$OPTARG
		;;
		K)
		KEEPTIF=1
		;;
		h)
		usage
		;;
	esac
done
if [ ! -r "$IMAGE" ] || [ -z "$IMAGE" ] || [ -z "$NORTH" ] || [ -z "$SOUTH" ] || [ -z "$EAST" ] || [ -z "$WEST" ]; then
	usage	
fi

IMAGEPREFIX=${IMAGE%.*}
[ -z "$DEST" ] && DEST=${IMAGEPREFIX##*/}

echo "*** Georeferencing $IMAGE:"
gdal_translate -a_srs WGS84 -a_ullr $WEST $NORTH $EAST $SOUTH $IMAGE $DEST.tif || exit 1
echo "*** Generate JNX $DEST.jnx:"
map2jnx -n $DEST -q 85 $DEST.tif $DEST.jnx

if [ -z "$KEEPTIF" ]; then
	rm $DEST.tif
fi
echo "*** Done !"
