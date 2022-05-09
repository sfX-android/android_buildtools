vendor=$1
androidver=$2

[ -z "$vendor" ] && vendor=lineage
[ -z "$androidver" ] && androidver=0

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
if [ $androidver -lt 10 ];then
    grep -q "PRODUCT_EXTRA_RECOVERY_KEYS := user-keys/releasekey" vendor/$vendor/config/common.mk
    if [ $? -ne 0 ];then
	sed -i "1s;^;PRODUCT_EXTRA_RECOVERY_KEYS := user-keys/releasekey\n;" vendor/$vendor/config/common.mk && echo "PRODUCT_EXTRA_RECOVERY_KEYS set"
    fi
fi
