# About

create your own keys for signing your build and prepare the ROM sources to use your own keys

## sign_generate_keys.sh

Needed once only for creating your own signing keys:

1. will create all signing keys required in `$KEYS_DIR` (default `./user-keys/`) directory.<br/>
   Examples: `releasekey platform shared media networkstack verity ...`
1. will create a releasekey in readable format for [manual verifier](https://github.com/sfX-android/update_verifier)
1. will create an AVB key needed for flashing on compatible devices (like Google's Pixel, OnePlus)

Usage: `./sign_generate_keys.sh`

#### environment variables

mandatory:
- `USER_NAME` : sets given username for certificate CN  (will set `CN=<value>-$CERTCN`, will abort if unset)

optional:
- `CERT_CN` : sets a custom certificate CN (will set `CN=$USER_NAME-<value>`, default: "aosp")
- `KEYS_DIR` : target directory where the keys should be stored
- `KSIZE` : set keysize (allowed: 4096|8192), default is [here](https://github.com/sfX-android/android_buildtools/blob/main/sign/sign_generate_keys.sh#L11-L13) - **WARNING: Setting 8192 requires to patch the Updater + recovery to allow OTA's / ADB sideload install/upgrade**
- `HASHTYPE` : set keysize (allowed: sha256|sha512), default is [here](https://github.com/sfX-android/android_buildtools/blob/main/sign/sign_generate_keys.sh#L11-L13) - **WARNING: Setting sha512 requires to patch the Updater + recovery to allow OTA's / ADB sideload install/upgrade**

## sign_set_keysdir.sh

Needed always after a full Android sources sync. Enables the use of the key file directory within `vendor/<vendor>/config/common.mk`
  
### Usage

- `./sign_set_keysdir.sh <vendor> <Android-Version> [keys-directory]` 

```
<vendor>               vendor/<vendor>/config/common.mk will be changed to use the right keys directory (so must exist)
<Android-Version>      Android-Version must be specified as: "a9, a10, .." or "A9, A10, .."
[<keys-directory>]       Optional: specify a relative path where the key files are expected, if unspecified "user-keys/" will be used
```

### environment variables

instead of specifying the (optional) keys-directory as a parameter you can also set the variable

`export KEYS_DIR=<keys-directory>`

when both are specified (call parameter + environment variable) the parameter wins

### Examples

- `./sign_set_keysdir.sh lineage a11`
- `./sign_set_keysdir.sh graphene a14 keys/lynx`
  
