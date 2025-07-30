#!/bin/bash
################################################################################################
#
# Author & Copyright: 2020-2025 steadfasterX <steadfasterX | AT | gmail - DOT - com>
#
# Prepare <vendor> dir to use a custom signing key
#
################################################################################################

# important for determining version number translation & vendor path
vendor=$1

# can be just "11" or "a11" or "android11" or "android-11" .. anything except digits will be removed
androidver=$2

# optionally specifying the keys dir (relative from the sources path)
[ ! -z "$3" ] && tdir="$3"
[ -z "$tdir" -a ! -z "$KEYS_DIR_LINKNAME" ] && tdir="$KEYS_DIR_LINKNAME"

# set directory name within the source dir
if [ -z "$tdir" ];then
    case "$vendor" in
        graphene) tdir="keys" ;;
               *) tdir="user-keys";;
    esac
fi

[ -z "$androidver" ] && androidver=0

# translate ROM specific versions
case $androidver in
    [aA]7) androidver=7;;
    [aA]8) androidver=8 ;;
    [aA]9) androidver=9 ;;
    [aA]10) androidver=10 ;;
    [aA]11) androidver=11 ;;
    [aA]12) androidver=12 ;;
    [aA]13) androidver=13 ;;
    [aA]14) androidver=14 ;;
    [aA]15) androidver=15 ;;
    [aA]16) androidver=16 ;;
    *)
    echo "ERROR: Unknown android version specified! please use a7, a8, a9, ... (A7, A8, A9, ... will work, too) for a clear definition!"
    echo "Update your scripts and workflows which using this script as names (nougat, etc) and numbers (16.0, 17.1 etc) support has been dropped!"
    exit 4
    ;;
esac
normalizedver=$(echo "$androidver" | egrep -o "[0-9]+")

# (re)create keys dir(s) if specified
if [ ! -z "$KEYS_DIR" ];then
    if [ ! -d "$KEYS_DIR" ]; then
	echo "$KEYS_DIR does not exist - creating it..."
	mkdir -p "$KEYS_DIR"
    fi
    if [ ! -L $tdir ]&&[ -d "$tdir" ];then
	echo "WARNING: KEYS_DIR main path '$tdir' is a directory - we expected a LINK instead!"
      else
	# WARNING: we have to ensure that a link has been removed before.
	# otherwise (even when using ln -sf) a folder "keys" will be added within the link dir
	rm $tdir
	# Soong (Android 9+) complains if the signing keys are outside the build path
	ln -s "$KEYS_DIR" $tdir
      fi
fi

if [ "$vendor" != "graphene" ];then

	if [ "$vendor" == "eos" ] && [ "$normalizedver" -ge 10 ];then
 		echo "skipped PRODUCT_DEFAULT_DEV_CERTIFICATE + PRODUCT_OTA_PUBLIC_KEYS as eOS is A${normalizedver} and so part of vendor/eos already"
   	else
		[ ! -f vendor/$vendor/config/common.mk ] && echo "vendor/$vendor/config/common.mk does not exists! ABORTED" && exit 9
		grep -q "PRODUCT_DEFAULT_DEV_CERTIFICATE := $tdir/releasekey" vendor/$vendor/config/common.mk
		if [ $? -ne 0 ];then 
		    sed -i "1s;^;PRODUCT_DEFAULT_DEV_CERTIFICATE := $tdir/releasekey\n;" vendor/$vendor/config/common.mk && echo "PRODUCT_DEFAULT_DEV_CERTIFICATE set"
		fi
		if [ "$normalizedver" -lt 15 ];then # causes duplicate which then leads to no fastboot zip
		    grep -q "PRODUCT_OTA_PUBLIC_KEYS := $tdir/releasekey" vendor/$vendor/config/common.mk
		    if [ $? -ne 0 ];then
			sed -i "1s;^;PRODUCT_OTA_PUBLIC_KEYS := $tdir/releasekey\n;" vendor/$vendor/config/common.mk && echo "PRODUCT_OTA_PUBLIC_KEYS set"
		    fi
		fi
  	fi

fi
if [ "$vendor" != "graphene" ];then
    # android =< 10 will fail when using PRODUCT_EXTRA_RECOVERY_KEYS
    if [ "$normalizedver" -lt 10 ];then
	grep -q "PRODUCT_EXTRA_RECOVERY_KEYS := $tdir/releasekey" vendor/$vendor/config/common.mk
	if [ $? -ne 0 ];then
	    sed -i "1s;^;PRODUCT_EXTRA_RECOVERY_KEYS := $tdir/releasekey\n;" vendor/$vendor/config/common.mk && echo "PRODUCT_EXTRA_RECOVERY_KEYS set"
	fi
    fi
fi
