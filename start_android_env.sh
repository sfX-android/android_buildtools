#!/bin/bash
##########################################################################
#
# Start a valid Android/TWRP build environment on Arch Linux
#
# Copyright:    steadfasterX <steadfasterX -at- gmail -DoT- com>, 2018
# License:      LGPL v2
##########################################################################
#
# Requirements:
#       $> pacman -Sy python2-virtualenv
#
#       $> cd ~
#       $> virtualenv2 venvpy2 (will create an virtual env named venvpy2)
#       $> ln -s /usr/lib/python2.7/* ~/venvpy2/lib/python2.7/
#
##########################################################################
SRCONLY=0
# ensure we fail completely when any tiny bit fails
set -e

# change this to the name of your virtualenv environment name you created
VENVNAME=venvpy2

source ~/$VENVNAME/bin/activate && echo venv sourced...

# when building with jack how much RAM should it suck?
JACKRAM=10G

# ccache settings
CACHESIZE=10G                   # the ccache size on disk
export USE_CCACHE=1             # enable / disable ccache
export CCACHE_DIR=~/.ccache     # best is having this on a diff disk then your $BDIR

# force java home set (needed for some special cases)
export ANDROID_SET_JAVA_HOME=true

# your path to the java jdk (will be set to JAVA_HOME)
# you can set different MY_JAVA_HOME's in the "check how we started" case condition!!
MY_JAVA_HOME=/usr/lib/jvm/java-8-openjdk

# special var for TWRP
export TW_DEVICE_VERSION="$(date +%F)"

# the hostname which should be displayed in your builds (settings->about etc)
export HOSTNAME="sfxbook-droid"

# the user which should be displayed in your builds (settings->about etc)
export USER=steadfasterx

# sets a part of the bash prompt to identify where you are in
BASHPROMPT=android      # can be overwritten by the "check how we started" case condition
PDIRSIZE='\\W'          # \\W means only the current dirname. \\w means the FULL path

# where is your MAIN android source dir (1 level BEFORE your sources dir)
# when starting this script with an argument you can automate the lunch cmd
# (just extend the "check how we started" case condition 
BDIR=/opt/data/development/android_build

# check how we started
case $1 in
    twrp)
    ADIR=omni
    SELECTDEVICE="lunch omni_g4-eng"
    BASHPROMPT=TWRP
    ;;
    los15)
    ADIR="los/15.1"
    ;;
    manual) # will just display a copy/paste template
    ADIR=$2
    SRCONLY=1
    ;;
    *)
    ADIR="$1"
    ;;
esac

#######################################################################################
# no changes beyond here needed (usually)
#

[ -z $ADIR ] && echo "require a starting dir.. ABORTED" && exit 1

# some special vars
export HISTFILE="$HOME/.android_big_history"                # sets the path to a custom history file for android building
export HISTFILESIZE="200000"                            # max lines of $HISTFILE at startup time of a session (e.g. 100k have an avg of ~4MB file size)
export HISTSIZE="10000"                                 # max lines that are stored in MEMORY(!) in a history list while your bash session is ONGOING

[ ! -f $HISTFILE ] && touch $HISTFILE

# required! otherwise build will fail :p
export LANG=$LANG
export LC_ALL=C

ccache --set-config=max_size=$CACHESIZE

# prepare the basics
cd ${BDIR}/${ADIR}
ENVSRC=custombuildenv

cat >$ENVSRC<<EOHOST
# needed to overwrite the build hostname
alias hostname='echo $HOSTNAME'
EOHOST
source build/envsetup.sh
$SELECTDEVICE

# jack args
export ANDROID_JACK_VM_ARGS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx${JACKRAM}"

# MUST BE DONE AFTER LUNCH!
# this here is needed as LUNCH will overwrite anything which was set!
export JAVA_HOME="$MY_JAVA_HOME"

# ensure that all parent functions will be exported to the subshells
lsfns () {
   case "$1" in
      -v | v*)
         # verbose:
         set | grep '()' --color=always
         ;;
      *)
         declare -F | cut -d" " -f3 
         ;;
   esac
}
# not needed atm.. leaving it here for future ref
#lsvars () {
#   case "$1" in
#      -v | v*)
#         # verbose:
#         set | egrep '^\w+=' --color=always | egrep -v "PATH="
#         ;;
#      *)
#        #export -p | cut -d " " -f3 | egrep -v "PATH"
#         ;;
#   esac
#}
#export $(lsvars)

PYVER=$(python --version 2>&1)

# set bash prompt
echo "PS1='\[\033[01;32m\]['${BASHPROMPT}' ('${VIRTUAL_ENV##*/}')]\[\033[01;37m\] [\['$PDIRSIZE']\$\[\033[00m\] '" >> $ENVSRC

if [ $SRCONLY -eq 0 ] ;then
    export -f $(lsfns)

    # fasten your seat bells.. the magic happens NOW!
    /bin/bash --rcfile <(echo "echo -e \"\nAndroid build environment has been setup:\n\tpython: $PYVER\n\tuse ccache: $USE_CCACHE\n\tJAVA_HOME: $JAVA_HOME\n\tTW_DEVICE_VERSION: $TW_DEVICE_VERSION\n\tbuild user: $USER\n\thost set: $HOSTNAME\n\";source $ENVSRC")

    #/bin/bash  -c "echo -e \"\nAndroid build environment has been setup:\n\tpython: $(python --version 2>&1)\n\tuse ccache: $USE_CCACHE\n\tJAVA_HOME: $JAVA_HOME\n\tTW_DEVICE_VERSION: $TW_DEVICE_VERSION\n\tbuild user: $USER\n\thost set: $HOSTNAME\n\"; \
     #          $SHELL --rcfile $ENVSRC"
else
    echo "copy & paste only mode.."
    cat <<EOFCP

copy everything between these 2 lines and paste it to your shell
*****************************************************************

source ~/$VENVNAME/bin/activate && echo venv sourced...
export USE_CCACHE=$USE_CCACHE
export CCACHE_DIR="$CCACHE_DIR"
export ANDROID_SET_JAVA_HOME=true
export TW_DEVICE_VERSION="$(date +%F)"
export HOSTNAME=$HOSTNAME
export USER=$USER
export BASHPROMPT="$BASHPROMPT"
export PDIRSIZE="$PDIRSIZE"
export BDIR="$BDIR"
export HISTFILE="$HOME/.android_big_history"
export HISTFILESIZE="200000"
export HISTSIZE="10000"
[ ! -f $HISTFILE ] && touch $HISTFILE
export LANG="$LANG"
export LC_ALL=C
ccache --set-config=max_size=$CACHESIZE
cd ${BDIR}/${ADIR}
alias hostname='echo $HOSTNAME'
source build/envsetup.sh
export ANDROID_JACK_VM_ARGS="$ANDROID_JACK_VM_ARGS"
export JAVA_HOME="$MY_JAVA_HOME"


*****************************************************************
EOFCP
    #bash --rcfile <(echo "PS1=\"$EDITHOST/system/local \$>\";cd $SYSDIR/ && ls -la")
    #source $ENVSRC
    #PS1='\[\033[01;32m\]['${BASHPROMPT}' ('${VIRTUAL_ENV##*/}')]\[\033[01;37m\] [\['$PDIRSIZE']\$\[\033[00m\] '
    #echo -e "\nAndroid build environment has been setup:\n\tpython: $(python --version 2>&1)\n\tuse ccache: $USE_CCACHE\n\tJAVA_HOME: $JAVA_HOME\n\tTW_DEVICE_VERSION: $TW_DEVICE_VERSION\n\tbuild user: $USER\n\thost set: $HOSTNAME\n"
fi

