#!/bin/bash

DIR=$1
FILE=$2
SIZ=150
TYP=gif

if [ ! -d $DIR ]; then
	echo `date` " $DIR didn't exist!"
	mkdir $DIR
	exit 0
fi
cd $DIR

chmod 664 mk_thumbnail.log
echo `date` " DIR: $DIR File: $FILE" >> mk_thumbnail.log

if [ ! -e $FILE ]; then
	echo `date` " $FILE didn't exist!"
	exit 0
fi

NEWFILE=tn_"${FILE%.*}".$TYP
convert -thumbnail ${SIZ}x${SIZ} $FILE -auto-orient -background transparent -gravity center -extent ${SIZ}x${SIZ} $NEWFILE

