#!/bin/bash

DIR=$1
FILE=$2

echo `date` " DIR: $DIR File: $FILE" >> mk_thumbnail.log

if [ ! -d $DIR ]; then
	echo `date` " $DIR didn't exist!"
	mkdir $DIR
	exit 0
fi
cd $DIR

if [ ! -e $FILE ]; then
	echo `date` " $FILE didn't exist!"
	exit 0
fi

NEWFILE=tn_"${FILE%.*}".gif
convert -thumbnail 100x100 $FILE -auto-orient -background transparent -gravity center -extent 100x100 $NEWFILE

