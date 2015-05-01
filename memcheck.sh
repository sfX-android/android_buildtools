#!/bin/bash
###########################################################################
#
# Simple RAM watcher for manually optimizing RAM usage
#
###########################################################################

OUT_OLD=0

while [ "1" == "1" ];do

	OUT=$(free -m |grep "buffers/cache"  |tr " " "." |cut -d"." -f9)
	if [ -z "$OUT" ];then 
	  echo nothing >> /dev/null
	else
	  if [ $OUT -gt $OUT_OLD ];then
		clear
		echo mem increased from $OUT_OLD MB to $OUT MB
		OUT_OLD=$OUT
	  fi
	fi
	sleep 2s

done
