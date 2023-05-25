#!/bin/bash
#########################################################################################
# 
# Author & Copyright: 2020-2023 steadfasterX <steadfasterX | AT | gmail - DOT - com>
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

# default key/hash sizes
DEFKSIZE=4096
DEFHASHTYPE=sha256

KEYS_SUBJECT='/C=US/ST=Somewhere/L=Somewhere/CN='${_USR}-${CERT_CN}'/OU=Android/O=Google/emailAddress=android@android.local'

[ ! -d $KEYS_DIR ] && mkdir -p $KEYS_DIR

case $KSIZE in
    2048|4096|8192) echo setting rsa-${KSIZE} ;;
    *) echo -e "UNSUPPORTED or empty key size: >$KSIZE<\nUsing default KSIZE=$DEFKSIZE"; export KSIZE=$DEFKSIZE;;
esac

case $HASHTYPE in
    sha256|sha512) echo setting $HASHTYPE ;;
    *) echo -e "UNSUPPORTED or empty hash >$HASHTYPE<\Using default HASHTYPE=$DEFHASHTYPE" ; export HASHTYPE=$DEFHASHTYPE ;;
esac

for c in releasekey platform shared media networkstack verity sdk_sandbox bluetooth; do
    for k in pem key pk8 x509.pem der;do
	if [ -f "$KEYS_DIR/${c}.${k}" ];then
	    echo "WARNING: $c.${k} exists!! I WILL NOT OVERWRITE EXISTING KEYS!"
	    continue 2
	fi
    done
    echo ">> [$(date)]  Generating $c..."
    if [ $c == releasekey ] && [ "$HASHTYPE" != sha256 ];then
	echo "enforce max hash algo to SHA256 for releasekey!"
	echo "reason: build/make/tools/signapk/src/com/android/signapk/SignApk.java does not support anything else (atm)"
	HASHTYPE=sha256 ${VENDOR_DIR}/make_key "$KEYS_DIR/$c" "$KEYS_SUBJECT" <<< '' &> /dev/null
    else
	${VENDOR_DIR}/make_key "$KEYS_DIR/$c" "$KEYS_SUBJECT" <<< '' &> /dev/null
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
[ ! -f "$KEYS_DIR/releasekey.pub" ] && openssl rsa -in $KEYS_DIR/releasekey.pem -pubout > $KEYS_DIR/releasekey.pub && echo "... $KEYS_DIR/releasekey.pub created"

# make AVB required stuff
# AVB supports usually (atm) only sha256+4096bit max
for a in pk8;do
    if [ -f "$KEYS_DIR/avb.${a}" ];then
	echo "WARNING: avb.${a} exists!! I WILL NOT OVERWRITE EXISTING KEYS!"
	continue
    fi
    echo ">> [$(date)] Generating AVB ($a)..."
    export KSIZE=4096 HASHTYPE=sha512 ; ${VENDOR_DIR}/make_key "$KEYS_DIR/avb" "$KEYS_SUBJECT" <<< '' #&> /dev/null
done
if [ ! -f $KEYS_DIR/avb_pkmd.bin ];then
    [ ! -f "$KEYS_DIR/avb.x509.der" ] && openssl x509 -outform DER -in $KEYS_DIR/avb.x509.pem -out $KEYS_DIR/avb.x509.der && echo "... $KEYS_DIR/avb.x509.der created"
    [ ! -f "$KEYS_DIR/avb.pem" ] && openssl pkcs8 -in $KEYS_DIR/avb.pk8 -inform DER -out $KEYS_DIR/avb.pem -nocrypt && echo "... $KEYS_DIR/avb.pem created"
    external/avb/avbtool extract_public_key --key $KEYS_DIR/avb.pem --output $KEYS_DIR/avb_pkmd.bin && echo "... $KEYS_DIR/avb_pkmd.bin created"
fi
