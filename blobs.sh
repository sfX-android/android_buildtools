#!/bin/bash
###########################################################################################
#
# parses a blob and prints all its dependencies - and dependencies of those, too
#
# Copyright 2020-2023: steadfasterX <steadfasterX | gmail - com>
#
###########################################################################################

[ -z "$DEBUG" ] && DEBUG=0
spath="$1"
FOUND="$2"
BLOBS=()

if [ "$spath" ]||[ -f "$FOUND" ];then echo "ERROR. usage: $0 <search path> <full-path-to-blob>"; exit 4;fi

lib_lookup() {
    readelf -d $1 | grep NEEDED | cut -d "[" -f2 | cut -d"]" -f 1
}

so_search() {
    for file in `lib_lookup $1`; do
        find $spath -iname "$file" 2>/dev/null
    done
}

global_search() {
    RESULT=$(so_search $1 | grep -Ev "^${FOUND}" | grep -v "libc.so\|libdl.so\|libc++.so\|libm.so\|liblog.so\|libcutils.so")
    for blob in `echo -n $RESULT`; do
        CNT=$((CNT+1))
        echo $blob
        FOUND=$1\|$FOUND
        BLOBS[1]+="$blob "
        global_search $blob
        [ $CNT -gt 20 ] && break
    done
}

[ "$DEBUG" -eq 1 ] && echo starting search on $1
global_search $FOUND
[ "$DEBUG" -eq 1 ] && echo finished search on $1
