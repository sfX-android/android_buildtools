# android_buildtools
My build tools for developing android

### sign/

check the [README](https://github.com/sfX-android/android_buildtools/tree/main/sign) in that directory 

### blobs.sh

THE tool to find blob dependencies! Ever tried to bring-up a custom ROM for a device? you WILL get trouble to get everything working without proprietary (aka blobs) binaries from the STOCK ROM. as these have dependencies with libraries you can easily come into a situation where you need to grab 10 libs for 1 blob. finding these is always annoying as you either need to grab the logs again and again or using strace again and again.

-> not needed anymore as blobs.sh will do that all for you - right from your linux system - so even before including them in your next build :) 

### memcheck.sh

Simple RAM watcher for manually optimizing RAM usage. It was created to monitor the RAM usage during a ROM build in order to find the max used RAM amount during building Android.

### twrp_bench.sh

an incredible cool benchmark tool which runs a TWRP backup and measures its speed and performance.

Things you can adjust are:

* read_ahead_kb
* cpu governor
* I/O scheduler

It was written to get an idea which combination of the above would be best and it was used on several file systems as well (f2fs, ext4 etc)

# legacy

### start_android_env.sh

Starts a valid Android/TWRP build environment on Arch Linux based on python virtualenv. should be migrated to python3 btw.. but as I stopped using it on my desktop system that might not happen

### build_prepare.sh

made to get a clean state before building. superseeded by Jenkins later .. and now by [Ansible](https://github.com/sfX-android/automation_scripts)

### universalbuilder.sh

made some decades ago to build for several devices which all have their own shit. Parts of it can be found in [extendrom](https://github.com/sfX-android/android_vendor_extendrom) now.

### blobutil/

superseeded by blobs.sh (see above). it was a way to find dependencies of blobs.
