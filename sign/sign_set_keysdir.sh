vendor=$1
androidver=$2

[ -z "$vendor" ] && vendor=lineage
[ -z "$androidver" ] && androidver=0

# translate ROM specific versions
if [ $vendor == "lineage" ];then
    case $androidver in
	14*) androidver=7 ;;
	15*) androidver=8 ;;
	16*) androidver=9 ;;
	17*) androidver=10 ;;
	18*) androidver=11 ;;
    esac
fi

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
