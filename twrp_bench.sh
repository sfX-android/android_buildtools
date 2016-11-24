#!/bin/bash -
###############################################################################################################
#
# Get configuration not accessible by splunk btool
# Copyright: Thomas Fischer <mail@se-di.de>
# Licensed under the LGPL v3 or later:
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
###############################################################################################################
#
# Description:
#       simple TWRP benchmark tester for the LG G4
#       Use it with any other device if you like but then you have to adjust the topic:
#           # set readahead
#
#
VERSION=20161124
###############################################################################################################

BAKNAME=benchmarktest
LOG=${0/.sh/.log}

echo "Starting $0 - $VERSION"

[ -z "$1" ] &&echo "aborted! Missing args" && exit

while [ ! -z "$1" ] ;do
    case "$1" in 
        -rhsize)
        RHSIZE=$2
        shift 2
        ;;
        -gov)
        CGOV=$2
        shift 2
        ;;
        -isch)
        ISCH=$2
        shift 2
        ;;
        -key)
        KEY=$2
        shift 2
        ;;
        *)
        echo "ERROR unknown arg <$1>"
        exit
        ;;
    esac
done

# ensure we use the external storage
adb shell "twrp set tw_storage_path /external_sd" >> $LOG
[ $? -ne 0 ] && echo -e "\n\nERROR occured!!!\n ABORTED!!\nHere comes the LOG:\n $(cat $LOG)" && exit

# ensure we have no old backups in place
adb shell "rm -vRf /external_sd/TWRP/BACKUPS/*/$BAKNAME/; rm -vRf /sdcard/TWRP/BACKUPS/*/$BAKNAME/" >> $LOG
[ $? -ne 0 ] && echo -e "\n\nERROR occured!!!\n ABORTED!!\nHere comes the LOG:\n $(cat $LOG)" && exit

# set cpu governor
adb shell "for i in \$(find /sys/devices/ -type f -name scaling_governor);do echo $CGOV > \$i;cat \$i;done" >> $LOG
[ $? -ne 0 ] && echo -e "\n\nERROR occured!!!\n ABORTED!!\nHere comes the LOG:\n $(cat $LOG)" && exit

# set IO scheduler
adb shell "for a in \$(find /sys/devices/soc.0/ -type f -name scheduler|grep mmc);do echo $ISCH > \$a; cat \$a;done" >> $LOG
[ $? -ne 0 ] && echo -e "\n\nERROR occured!!!\n ABORTED!!\nHere comes the LOG:\n $(cat $LOG)" && exit

# set readahead
for b in /sys/devices/virtual/bdi/179\\:0/read_ahead_kb /sys/devices/virtual/bdi/254\\:0/read_ahead_kb /sys/devices/virtual/bdi/179\\:32/read_ahead_kb /sys/devices/virtual/bdi/179\\:64/read_ahead_kb;do
    adb shell "echo $RHSIZE >> $b; cat $b"
    [ $? -ne 0 ] && echo -e "\n\nERROR occured!!!\n ABORTED!!\nHere comes the LOG:\n $(cat $LOG)" && exit
    #echo "$RHSIZE >> $b cat $b"
done >> $LOG

# grep results and reboot
echo "Ok.. now lean back: we start the backup! This can take a fucking long time!"
echo "using: readahead=$RHSIZE, governor=$CGOV, scheduler=$ISCH"
adb shell 'twrp backup SDRBO benchmarktest' | egrep -i '(seconds|backup rate)' \
    && adb shell 'rm -Rf /external_sd/TWRP/BACKUPS/*/benchmarktest/' \
    && adb reboot recovery && sleep 10 && adb wait-for-recovery && sleep 40 &&  [ ! -z "$KEY" ] && adb shell twrp decrypt $KEY

[ $? -ne 0 ] && echo -e "\n\nERROR occured!!!\n ABORTED!!\nHere comes the LOG:\n $(cat $LOG)" && exit

echo finished

