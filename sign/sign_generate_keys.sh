#!/bin/bash

#VENDOR_DIR=$PWD
VENDOR_DIR=$(dirname $0)
KEYS_DIR=user-keys
_USR=$USER_NAME
[ -z $_USR ] && echo "ERROR: missing USER_NAME var!" && exit 3

KEYS_SUBJECT='/C=DE/ST=Somewhere/L=Somewhere/O='${_USR}'/OU=e/CN=eOS/emailAddress=android@android.local'

[ ! -d $KEYS_DIR ] && mkdir -p $KEYS_DIR

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
openssl rsa -inform DER -outform PEM -in $KEYS_DIR/releasekey.pk8 -out $KEYS_DIR/releasekey.pem
openssl rsa -in $KEYS_DIR/releasekey.pem -pubout > $KEYS_DIR/releasekey.pub

# make AVB required stuff
openssl x509 -outform DER -in $KEYS_DIR/releasekey.x509.pem -out $KEYS_DIR/releasekey.x509.der
openssl pkcs8 -in $KEYS_DIR/releasekey.pk8 -inform DER -out $KEYS_DIR/releasekey.key -nocrypt
external/avb/avbtool extract_public_key --key $KEYS_DIR/releasekey.key --output $KEYS_DIR/pkmd.key
