# About

create your own keys for signing your build and prepare the ROM sources to use your own keys

### sign_generate_keys.sh

Needed once only for creating your own signing keys:

1. will create all signing keys required in `./user-keys/` directory.<br/>
   Examples: releasekey platform shared media networkstack verity
1. will create a releasekey in readable format for [manual verifier](https://github.com/sfX-android/update_verifier)
1. will create an AVB key needed for flashing on compatible devices (like Google's Pixel, OnePlus)

Usage: `./sign_generate_keys.sh`

### sign_set_keysdir.sh

Needed always after a full Android sources sync. Enables the use of the `user-keys/` key files within `vendor/<vendor>/config/common.mk`
  
Usage: `./sign_set_keysdir.sh <vendor> <Android-Version>`
  
Example: `./sign_set_keysdir.sh lineage 18.1`
  
