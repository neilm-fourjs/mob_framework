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

echo `date` " DIR: $DIR File: $FILE" >> $LOG

if [ ! -e $FILE ]; then
	echo `date` " $FILE didn't exist!"
	exit 0
fi

NEWFILE=tn_"${FILE%.*}".$TYP
convert -thumbnail ${SIZ}x${SIZ} $FILE -auto-orient -background transparent -gravity center -extent ${SIZ}x${SIZ} $NEWFILE 2>> $LOG
chmod 644 * 2>> $LOG
