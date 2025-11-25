#!/bin/bash
#########################################################################################
# 
# Author & Copyright: 2020-2025 steadfasterX <steadfasterX | AT | gmail - DOT - com>
#
# Generate all required keys for signing Android builds
#
#########################################################################################

VENDOR_DIR=$(dirname $0)
[ -z "$KEYS_DIR" ] && KEYS_DIR=user-keys
_USR=$USER_NAME
[ -z $_USR ] && _USR=$BUILD_USERNAME
[ -z $_USR ] && echo "ERROR: missing USER_NAME var!" && exit 3
[ -z "$CERT_CN" ] && CERT_CN=aosp
KEYS_SUBJECT='/C=US/ST=Somewhere/L=Somewhere/CN='${_USR}-${CERT_CN}'/OU=Android/O=Google/emailAddress=android@android.local'

# ensure avbtool binary path is set properly 
# (e.g on pie external/avb/avbtool exists only but on A14 there's only external/avb/avbtool.py
[ ! -x external/avb/avbtool ] && ln -s avbtool.py external/avb/avbtool

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
    elif [ $nc == verity ] && [ "$KSIZE" != 2048 ] && [ "$AVB_VERSION" == 1 ];then
	echo "enforce max keysize to 2048 bits for AVB v1 verity key!"
	echo "reason: AVB v1 boot signing process does not support any higher key size!"
	KSIZE=2048 ${VENDOR_DIR}/make_key "$KEYS_DIR/$nc" "$KEYS_SUBJECT" <<< '' &> /dev/null
    else
	${VENDOR_DIR}/make_key "$KEYS_DIR/$nc" "$KEYS_SUBJECT" <<< '' &> /dev/null
    fi
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
[ ! -f "$KEYS_DIR/verity.pem" ] && openssl rsa -inform DER -outform PEM -in $KEYS_DIR/verity.pk8 -out $KEYS_DIR/verity.pem && echo "... $KEYS_DIR/verity.pem created"
[ ! -f "$KEYS_DIR/verity_key.pub" ] && openssl rsa -in $KEYS_DIR/verity.pem -pubout > $KEYS_DIR/verity_key.pub && echo "... $KEYS_DIR/verity_key.pub created"

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
