#!/bin/bash
#################################################################
#
# wrapper to satisfy android builds with jenkins
#
#################################################################

echo "starting build wrapper $0 ..."
SRCPATH="$1"
RUNCMD="$@"


source ~/.profile
source ~/.bashrc

[ -z "$CCACHE_DIR" ] && export CCACHE_DIR=/ccache/$USER

echo -e "USE_CCACHE: $USE_CCACHE\nCCACHE_DIR: $CCACHE_DIR\nANDROID_JACK_VM_ARGS: $ANDROID_JACK_VM_ARGS\nSRCPATH: $SRCPATH\nRUNCMD: $RUNCMD"

f_help(){
  echo -e "\n\nUsage:\n $0 sources-path cmd-to-run\n"
}

[ -z "$RUNCMD" ] && echo "ERROR: uuhm.. missing RUNCMD! What should I do? smokin a pipe or what? try again! pfff.." && f_help && exit 3
[ ! -d "$SRCPATH" ] && echo "ERROR: missing source path or $SRCPATH does not exists!" && exit 3

cd $SRCPATH
source build/envsetup.sh

echo -e "ro.product.cpu.abilist=$TARGET_CPU_ABI,$TARGET_2ND_CPU_ABI"

[ "$3" == "killjack" ] && jack-admin kill-server

# filter out unwanted stuff
RUNCMD=$(echo "$RUNCMD" |grep -vo killjack | grep -vo "$SRCPATH")

$RUNCMD
RET=$?

echo -e "ro.product.cpu.abilist=$TARGET_CPU_ABI,$TARGET_2ND_CPU_ABI"

echo "build wrapper $0 finished with $RET"
exit $RET
