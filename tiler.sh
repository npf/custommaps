#!/bin/bash

#IMAGE=top25-grenoble.jpg
#NORTH=45.236345982245915
#SOUTH=45.015576018020703
#EAST=5.886258718271238
#WEST=5.565537433019793
MAXTILE=10
TILESIZE=1024
JPEGQUALITY=75
DOC=doc.kml
FILES=files

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
   -o output name (the .kmz extension will be suffixed)
   -f Overwrite the .kmz file if it already exists
   -x tiles to exclude (eg: "3-2 4-1")
   -j	JPEG quality (default: $JPEGQUALITY)
   -t	Size of the tiles (default: $TILESIZE)
   -k	Keep the kml
   -K	Keep and reuse the geolocalised tiff file
   -R	Reuse the geolocalised tiff file if it exists
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
		x)
		EXCLUDE=$OPTARG
		;;
		j)
		JPEGQUALITY=$OPTARG
		;;
		t)
		TILESIZE=$OPTARG
		;;
		k)
		KEEPKML=1
		;;
		K)
		KEEPTIF=1
		;;
		R)
		REUSETIF=1
		;;
		f)
		FORCE=1
		;;
		h)
		usage
		;;
	esac
done
if [ ! -r "$IMAGE" ] || [ -z "$IMAGE" ] || [ -z "$NORTH" ] || [ -z "$SOUTH" ] || [ -z "$EAST" ] || [ -z "$WEST" ]; then
	usage	
fi

IMAGESIZE=$(jhead -c $IMAGE | grep -o "[[:digit:]]\+x[[:digit:]]\+");
IMAGEWIDTH=${IMAGESIZE%x*}
IMAGEHEIGHT=${IMAGESIZE#*x}
if [ $((IMAGEWIDTH / TILESIZE)) -gt $MAXTILE -o $((IMAGEHEIGHT / TILESIZE)) -gt $MAXTILE ]; then
	echo "Source image width or height too large for the tile size (max $((10 * TILESIZE)))"
	exit 1
fi
IMAGEPREFIX=${IMAGE%.*}
[ -z "$DEST" ] && DEST=${IMAGEPREFIX##*/}

if [ -z "$FORCE" -a -e "$DEST.kmz" ];then
	echo "$DEST.kmz already exist, aborting."
	exit 1
fi
echo "*** Georeferencing $IMAGE:"
mkdir -p $DEST
if [ -e "$DEST/0.tif" -a -n "$REUSETIF" ]; then
	echo "Georeferenced file $DEST/0.tif already there, using it as is"
else
	gdal_translate -a_srs WGS84 -a_ullr $WEST $NORTH $EAST $SOUTH $IMAGE $DEST/0.tif || exit 1
fi
if [ -e "$DEST/$DOC" -o -e "$DEST/$FILES" ]; then
	echo "Wiping out old kml files..."
	rm -rf $DEST/$DOC $DEST/$FILES
fi
cat <<EOF > $DEST/$DOC
<?xml version="1.0" encoding="utf-8"?>
<kml xmlns="http://earth.google.com/kml/2.1">
  <Document>
    <name>$DEST</name>
    <description>Source: $IMAGE $NORTH $SOUTH $EAST $WEST</description>
    <Style>
      <ListStyle id="hideChildren">
        <listItemType>checkHideChildren</listItemType>
      </ListStyle>
    </Style>
EOF
mkdir -p $DEST/$FILES
for ((i=0;i < $((IMAGEWIDTH / TILESIZE));i++)); do
	for ((j=0;j < $((IMAGEHEIGHT / TILESIZE));j++)); do
		if [[ " $EXCLUDE " =~ " $i-$j " ]]; then
			echo "Tile $i-$j: skipped"
			continue;
		fi
		gdal_translate -srcwin $((i * TILESIZE)) $((j * TILESIZE)) $TILESIZE $TILESIZE $DEST/0.tif $DEST/$FILES/$i-$j.tif > /dev/null || exit 1
		convert -quality $JPEGQUALITY $DEST/$FILES/$i-$j.{tif,jpg} 2> /dev/null || exit 1
		tmpbuf=$(gdal_list_corners $DEST/$FILES/$i-$j.tif | grep -A 17 "geometry_ll:")
		rm $DEST/$FILES/$i-$j.tif
		north=$(echo $tmpbuf | grep -o "upper_left_lat: [[:digit:].]\+" | sed -e 's/.*: //')
		south=$(echo $tmpbuf | grep -o "lower_right_lat: [[:digit:].]\+" | sed -e 's/.*: //')
		east=$(echo $tmpbuf | grep -o "lower_right_lon: [[:digit:].]\+" | sed -e 's/.*: //')
		west=$(echo $tmpbuf | grep -o "upper_left_lon: [[:digit:].]\+" | sed -e 's/.*: //')
		echo "Tile $i-$j: $north $south $east $west"
#		if [ $j -eq 0 ]; then z=55; else z=54; fi
		z=55
		cat <<EOF >> $DEST/$DOC
      <GroundOverlay>
        <name>$i-$j</name>
        <Icon>
          <href>$FILES/$i-$j.jpg</href>
          <DrawOrder>$z</DrawOrder>
        </Icon>
        <LatLonBox>
          <north>$north</north>
          <south>$south</south>
          <east>$east</east>
          <west>$west</west>
        </LatLonBox>
      </GroundOverlay>
EOF
	done
done	
cat <<EOF >> $DEST/$DOC
  </Document>
</kml>
EOF
(cd $DEST && zip -r ../$DEST.kmz $DOC $FILES)
if [ -z "$KEEPKML" -a -z "$KEEPTIF" ]; then
	rm -rf $DEST
else
	if [ -z "$KEEPTIF" ]; then
		rm $DEST/0.tif
	else
		echo "Geolocalised tiff kept in $DEST/0.tif"
	fi
	if [ -z "$KEEPKML" ]; then
		rm -rf $DEST/$DOC $DEST/$FILES
	else
		echo "kml kept in $DEST"
	fi
fi
echo "*** Done !"
