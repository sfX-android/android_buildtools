#!/bin/bash
################################################################################################
#
# Prepare <vendor> dir to use a custom signing key
#
################################################################################################

# important for determining version number translation & vendor path
vendor=$1

# can be just "11" or "a11" or "android11" or "android-11" .. anything except digits will be removed
androidver=$2

case "$vendor" in
	lineage|eos|e-os) vendor=lineage ;;
	graphene) echo "skipping signing mod bc of vendor: $vendor" ; exit 0;;
esac

[ -z "$androidver" ] && androidver=0

# translate ROM specific versions
if [ "$vendor" == "lineage" ];then
    case $androidver in
	nougat|14*) androidver=7 ;;
	oreo|15*) androidver=8 ;;
	pie|16*|v*-p) androidver=9 ;;
	Q|17*|v*-q) androidver=10 ;;
	R|18*|v*-r) androidver=11 ;;
	S|19*|v*-s) androidver=12 ;;
	T|20*|v*-t) androidver=13 ;;
    esac
fi

normalizedver=$(echo "$androidver" | egrep -o "[0-9]+")

[ ! -f vendor/$vendor/config/common.mk ] && echo "vendor/$vendor/config/common.mk does not exists! ABORTED" && exit 9

grep -q "PRODUCT_DEFAULT_DEV_CERTIFICATE := user-keys/releasekey" vendor/$vendor/config/common.mk
if [ $? -ne 0 ];then 
    sed -i "1s;^;PRODUCT_DEFAULT_DEV_CERTIFICATE := user-keys/releasekey\n;" vendor/$vendor/config/common.mk && echo "PRODUCT_DEFAULT_DEV_CERTIFICATE set"
fi

grep -q "PRODUCT_OTA_PUBLIC_KEYS := user-keys/releasekey" vendor/$vendor/config/common.mk
if [ $? -ne 0 ];then
    sed -i "1s;^;PRODUCT_OTA_PUBLIC_KEYS := user-keys/releasekey\n;" vendor/$vendor/config/common.mk && echo "PRODUCT_OTA_PUBLIC_KEYS set"
fi

# android =< 10 will fail when using PRODUCT_EXTRA_RECOVERY_KEYS
if [ "$normalizedver" -lt 10 ];then
    grep -q "PRODUCT_EXTRA_RECOVERY_KEYS := user-keys/releasekey" vendor/$vendor/config/common.mk
    if [ $? -ne 0 ];then
	sed -i "1s;^;PRODUCT_EXTRA_RECOVERY_KEYS := user-keys/releasekey\n;" vendor/$vendor/config/common.mk && echo "PRODUCT_EXTRA_RECOVERY_KEYS set"
    fi
fi
