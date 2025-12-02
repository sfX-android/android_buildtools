#!/bin/bash
#########################################################################################
# 
# Author & Copyright: 2020-2025 steadfasterX <steadfasterX | AT | gmail - DOT - com>
#
# Generate all required keys for signing Android builds
#
#########################################################################################

VENDOR_DIR=$(dirname $0)
: "${KEYS_DIR:=user-keys}"

_USR=$USER_NAME
[ -z $_USR ] && _USR=$BUILD_USERNAME
[ -z $_USR ] && echo "ERROR: missing USER_NAME var!" && exit 3

# set certificate defaults
: "${CERT_DAYS:=10950}"
: "${CERT_DAYS_VERITY:=10950}"	# note: AVB v1 devices MIGHT get in trouble if the default of 30 years is used, i.e. do not boot at all (e.g. dumpling)
: "${CERT_CN:=aosp}"
: "${CERT_C:=US}"
: "${CERT_ST:=Somewhere}"
: "${CERT_L:=Somewhere}"
: "${CERT_OU:=Android}"
: "${CERT_O:=Google}"
: "${CERT_E:=android@android.local}"

KEYS_SUBJECT="/C=${CERT_C}/ST=${CERT_ST}/L=${CERT_L}/CN=${CERT_CN}/OU=${CERT_OU}/O=${CERT_O}/emailAddress=${CERT_E}"

export CERT_DAYS

# ensure avbtool binary path is set properly 
# (e.g on pie external/avb/avbtool exists only but on A14 there's only external/avb/avbtool.py
[ ! -x external/avb/avbtool ] && ln -s avbtool.py external/avb/avbtool

# fail if mka generate_verity_key is missing
which generate_verity_key || (echo "ERROR: missing generate_verity_key (run 'mka generate_verity_key')"; exit 4)

# defaults
DEFKSIZE=4096
DEFHASHTYPE=sha256
: "${AVB_VERSION:=2}"

[ ! -d $KEYS_DIR ] && mkdir -p $KEYS_DIR

case $KSIZE in
    2048|4096|8192) echo setting rsa-${KSIZE} ;;
    *) echo -e "UNSUPPORTED or empty key size: >$KSIZE< --> Using default KSIZE=$DEFKSIZE"; export KSIZE=$DEFKSIZE;;
esac

case $HASHTYPE in
    sha256|sha512) echo setting $HASHTYPE ;;
    *) echo -e "UNSUPPORTED or empty hash >$HASHTYPE< --> Using default HASHTYPE=$DEFHASHTYPE" ; export HASHTYPE=$DEFHASHTYPE ;;
esac

unset nlist
for c in releasekey platform shared media networkstack verity sdk_sandbox bluetooth extra apps nfc; do
    for k in pem key pk8 x509.pem der;do
	if [ -f "$KEYS_DIR/${c}.${k}" ];then
	    echo "WARNING: $KEYS_DIR/$c.${k} exists!! I WILL NOT OVERWRITE EXISTING KEYS!"
	    echo "$nlist" |grep -q "$c" && nlist=$(echo $nlist | sed "s/$c//g")
	    continue 2
	else
	    echo "$nlist" |grep -q "$c" || nlist="$nlist $c"
	fi
    done
done
for nc in $nlist;do
    echo ">> [$(date)]  Generating $nc..."
    if [ $nc == releasekey ] && [ "$HASHTYPE" != sha256 ];then
	echo "enforce max hash algo to SHA256 for releasekey!"
	echo "reason: build/make/tools/signapk/src/com/android/signapk/SignApk.java does not support anything else (atm)"
	HASHTYPE=sha256 ${VENDOR_DIR}/make_key "$KEYS_DIR/$nc" "$KEYS_SUBJECT" <<< '' &> /dev/null
	continue
    elif [ $nc == verity ] && [ "$AVB_VERSION" == 1 ];then
	echo "enforce special key handling. enforce sha256/2048bits for AVB v1 verity key!"
	echo "reason: AVB v1 boot signing process does not support any other key size!"
	# some bootloaders MIGHT don't like expire days long in the future, so if the signature is VALID
	# but it still does not boot, test with other expire days!
	CERT_DAYS=$CERT_DAYS_VERITY HASHTYPE=sha256 KSIZE=2048 ${VENDOR_DIR}/make_key "$KEYS_DIR/$nc" "$KEYS_SUBJECT" <<< '' #&> /dev/null
	continue
    fi
    ${VENDOR_DIR}/make_key "$KEYS_DIR/$nc" "$KEYS_SUBJECT" <<< '' &> /dev/null
done

for c in cyngn{-priv,}-app testkey; do
    for e in pk8 x509.pem; do
      ln -s releasekey.$e "$KEYS_DIR/$c.$e" 2> /dev/null
      test -L "$KEYS_DIR/$c.$e"
    done
done

# make readable format for manual verifier
[ ! -f "$KEYS_DIR/releasekey.pem" ] && openssl rsa -inform DER -outform PEM -in $KEYS_DIR/releasekey.pk8 -out $KEYS_DIR/releasekey.pem && echo "... $KEYS_DIR/releasekey.pem created"
[ ! -f "$KEYS_DIR/releasekey_OTA.pub" ] && openssl rsa -in $KEYS_DIR/releasekey.pem -pubout > $KEYS_DIR/releasekey_OTA.pub && echo "... $KEYS_DIR/releasekey_OTA.pub created"

# Verity / Verified boot requires special handling
# the specs allow only sha256/2048bit max!
if [ "$AVB_VERSION" == 1 ];then
    echo "verity: special AVB v1 handling ..."
    [ ! -f "$KEYS_DIR/verity.pem" ] \
	&& openssl genrsa -f4 -out $KEYS_DIR/verity.pem 2048 \
	&& echo "... $KEYS_DIR/verity.pem created"
    [ ! -f "$KEYS_DIR/verity.x509.der" ] \
	&& openssl x509 -in $KEYS_DIR/verity.x509.pem -outform DER -out $KEYS_DIR/verity.x509.der \
	&& echo "... $KEYS_DIR/verity.x509.der created"
    [ ! -L "$KEYS_DIR/verifiedboot_relkeys.der.x509" ] \
	&& ln -s verity.x509.der $KEYS_DIR/verifiedboot_relkeys.der.x509 \
	&& echo "... linked $KEYS_DIR/verifiedboot_relkeys.der.x509 to verity.x509.der"
    [ ! -f "$KEYS_DIR/verity_key" ] \
	&& generate_verity_key -convert $KEYS_DIR/verity.x509.pem $KEYS_DIR/verity_key \
	&& mv $KEYS_DIR/verity_key.pub $KEYS_DIR/verity_key \
	&& echo "... $KEYS_DIR/verity_key created"
fi

# make AVB required stuff
# AVB supports usually (atm) only sha512+4096bit MAX (this depends on the device's bootloader so might VARY!)
for a in pk8;do
    if [ -f "$KEYS_DIR/avb.${a}" ];then
	echo "WARNING: avb.${a} exists!! I WILL NOT OVERWRITE EXISTING KEYS!"
	continue
    fi
    if [ "$HASHTYPE" != "sha256" -a "$HASHTYPE" != "sha512" ];then
        echo "Unsupported hash type for AVB: $HASHTYPE"
        echo "enforcing max known to work value instead (sha512)"
        export HASHTYPE=sha512
    fi
    if [ "$KSIZE" -gt 4096 ];then
        echo "Unsupported key size for AVB: $KSIZE"
        echo "enforcing max known to work value instead (4096)"
        export KSIZE=4096
    fi
    echo ">> [$(date)] Generating AVB ($a | $KSIZE/$HASHTYPE)..."
    ${VENDOR_DIR}/make_key "$KEYS_DIR/avb" "$KEYS_SUBJECT" <<< '' #&> /dev/null
done
if [ ! -f $KEYS_DIR/avb_pkmd.bin ];then
    [ ! -f "$KEYS_DIR/avb.x509.der" ] && openssl x509 -outform DER -in $KEYS_DIR/avb.x509.pem -out $KEYS_DIR/avb.x509.der && echo "... $KEYS_DIR/avb.x509.der created"
    [ ! -f "$KEYS_DIR/avb.pem" ] && openssl pkcs8 -in $KEYS_DIR/avb.pk8 -inform DER -out $KEYS_DIR/avb.pem -nocrypt && echo "... $KEYS_DIR/avb.pem created"
    python external/avb/avbtool extract_public_key --key $KEYS_DIR/avb.pem --output $KEYS_DIR/avb_pkmd.bin && echo "... $KEYS_DIR/avb_pkmd.bin created"
fi

# Android >= 14 requires to set a BUILD file for bazel to avoid errors:
cat > $KEYS_DIR/BUILD << _EOB
# adding an empty BUILD file fixes the A14 build error:
# "ERROR: no such package 'keys': BUILD file not found in any of the following directories. Add a BUILD file to a directory to mark it as a package."
# adding the filegroup "android_certificate_directory" fixes the A14 build error:
# "no such target '//keys:android_certificate_directory': target 'android_certificate_directory' not declared in package 'keys'"
filegroup(
    name = "android_certificate_directory",
    srcs = glob([
        "*.pk8",
        "*.pem",
    ]),
    visibility = ["//visibility:public"],
)
_EOB
