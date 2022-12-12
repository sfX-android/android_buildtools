#!/bin/bash

VENDOR_DIR=$(dirname $0)
[ -z "$KEYS_DIR" ] && KEYS_DIR=user-keys
_USR=$USER_NAME
[ -z $_USR ] && _USR=$BUILD_USERNAME
[ -z $_USR ] && echo "ERROR: missing USER_NAME var!" && exit 3

# default key/hash sizes
DEFKSIZE=4096
DEFHASHTYPE=sha256

KEYS_SUBJECT='/C=DE/ST=Somewhere/L=Somewhere/CN='${_USR}'/OU=aosp/O=android/emailAddress=android@android.local'

[ ! -d $KEYS_DIR ] && mkdir -p $KEYS_DIR

case $KSIZE in
    4096|8192) echo setting rsa-${KSIZE} ;;
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
    ${VENDOR_DIR}/make_key "$KEYS_DIR/$c" "$KEYS_SUBJECT" <<< '' &> /dev/null
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
	continue 2
    fi
    echo ">> [$(date)] Generating AVB ($a)..."
    export KSIZE=4096 HASHTYPE=sha256 ; ${VENDOR_DIR}/make_key "$KEYS_DIR/avb" "$KEYS_SUBJECT" <<< '' #&> /dev/null
done
[ ! -f "$KEYS_DIR/avb.x509.der" ] && openssl x509 -outform DER -in $KEYS_DIR/avb.x509.pem -out $KEYS_DIR/avb.x509.der && echo "... $KEYS_DIR/avb.x509.der created"
[ ! -f "$KEYS_DIR/avb.key" ] && openssl pkcs8 -in $KEYS_DIR/avb.pk8 -inform DER -out $KEYS_DIR/avb.key -nocrypt && echo "... $KEYS_DIR/avb.key created"
[ ! -f "$KEYS_DIR/avb.pem" ] && external/avb/avbtool extract_public_key --key $KEYS_DIR/avb.key --output $KEYS_DIR/avb.pem && echo "... $KEYS_DIR/avb.pem created"
