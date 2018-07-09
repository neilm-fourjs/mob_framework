#!/bin/bash

DIR=$1
FILE=$2
SIZ=150
TYP=gif
LOG=../mk_thumbnail.log

if [ ! -d $DIR ]; then
	echo `date` " $DIR didn't exist!"
	mkdir $DIR
	exit 0
fi
cd $DIR
chmod 664 $LOG
chmod 755 . 2>> $LOG

FILENAM=${FILE%.*}
EXT=${FILE##*.}

echo `date` " DIR: $DIR File: $FILE Ext: $EXT" >> $LOG

if [ ! -e $FILE ]; then
	echo `date` " $FILE didn't exist!"
	exit 0
fi

if [ "$EXT" == "mp4" ] || [ "$EXT" == "mov" ]; then
	convert -quiet $FILE[1] ${FILENAM}.$TYP 2>> $LOG
	FILE=${FILENAM}.$TYP
fi

NEWFILE=tn_"${FILE%.*}".$TYP
convert -thumbnail ${SIZ}x${SIZ} $FILE -auto-orient -background transparent -gravity center -extent ${SIZ}x${SIZ} $NEWFILE 2>> $LOG

if [ "$EXT" == "mp4" ] || [ "$EXT" == "mov" ]; then
	rm ${FILENAM}.$TYP
fi

chmod 644 * 2>> $LOG
