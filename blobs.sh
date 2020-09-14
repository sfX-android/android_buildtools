#!/bin/bash
###########################################################################################
#
# find blob deps!
#
# Copyright (2020): steadfasterX <steadfasterX | gmail - com>
#
###########################################################################################

lib_lookup() {

	readelf -d $1 | grep NEEDED | cut -d "[" -f2 | cut -d"]" -f 1
	#readelf -d $1 | awk '/NEEDED/ {print $5}' | sed -e 's/\[\|\]//g'

}

so_search() {
	for file in `lib_lookup $1`; do
		find . -iname "$file" 2>/dev/null
	done
}

global_search() {
	RESULT=$(so_search $1 | egrep -v "^${FOUND}" | grep -v "libc.so\|libdl.so\|libc++.so\|libm.so\|liblog.so\|libcutils.so")
	for blob in `echo -n $RESULT`; do
                CNT=$((CNT+1))
		echo $blob
		FOUND=$1\|$FOUND
                BLOBS[1]+="$blob " 
		global_search $blob
                [ $CNT -gt 20 ] && break
	done
}

FOUND=$1
BLOBS=()

echo starting search on $1

global_search $1

echo finished search on $1
