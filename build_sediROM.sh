#!/bin/bash
#################################################
#
# This is a build script helper for sediROM
#
#################################################

# defines the maximum cpu's you want to use. Valid for AOSP builds only because
# for CM we always use mka / all CPUs
MAXCPU=8

SRCDIR="build/envsetup.sh"
[ ! -f $SRCDIR ]&& echo "Are you in the root dir??? aborted." && exit 3

# help/usage
F_HELP(){
	echo USAGE:
	echo
	echo "$0 needs one of:" 
	echo "	systemimage|userdataimage|otapackage|bootimage|recovery|mr_twrp|multirom|trampoline|multirom_zip|free|showtargets"
	echo "	kernelonly"
	echo 
	echo "	e.g.: $0 otapackage"
	echo 
	echo "You can also add a 'make clean or make installclean' by given it as the second arg"
	echo "	valid options are: clean|installclean"
	echo
	echo "	e.g.: $0 otapackage clean"
	echo
	echo "Special commands:"
	echo "	<free>		You will be asked what target you want. No limits ;-)" 
	echo "	<showtargets>	Scans for all available targets and creates a file output."
	echo 
	echo "Special variables:"
	echo "	BUILDID		if you call 'BUILDID=samsung/i927 $0' you will skip that question"
	echo "	LOKIFY		if you set this to 1 we will lokify at the end"
        echo "  NEEDEDJAVA & JAVACBIN   overwrite internal java detection. BOTH needed!"
        echo "                          NEEDEDJAVA e.g.: java-7-oracle"
        echo "                          JAVACBIN e.g.: /usr/lib/jvm/java-7-openjdk-amd64/bin/javac"
	echo
	echo "Kernelonly variables:"
	echo "	KDIR		if set it overwrites the default kernel dir (kernel/$BUILDID)"
	echo "	KCONF		the kernel defconfig filename - will prompt if not set"
	echo
}
# check if we have at least 1 arg:
[ -z $1 ]&& echo -e "MISSING ARG. \n\n" && F_HELP && exit 3

case $1 in
	-h|--help)
		F_HELP
		exit 0
        ;;
        showtargets)
            echo "Generating all available targets..."
            make -qp | awk -F':' '/^[a-zA-Z0-9][^$#\/\t=]*:([^=]|$)/ {split($1,A,/ /);for(i in A)print A[i]}' > alltargets
            echo "All available build targets can be found in the file './alltargets' now."
            exit
	;;
esac

source $SRCDIR
if [ -z $BUILDID ];then
    echo 
    echo "******************************************************************************************************"
    echo "Tell me the build id. It must match the one in device tree and need to include the vendor as well."
    echo
    echo "Example:"
    echo "lge/fx3q --> will look into device/lge/fx3q/"
    echo "or"
    echo "samsung/i927 --> will look into device/samsung/i927"
    echo "or"
    echo "lge/h815 --> will look into device/lge/h815"
    echo "and so on...!"
    echo
    echo "you can skip this step by providing BUILDID - see help"
    echo "******************************************************************************************************"
    echo
    echo "Ok now give me your build id:"
    read BUILDID
else
    echo "BUILDID was predefined as $BUILDID"
fi
BUILDWHAT=$(egrep "^add_lunch_combo" device/$BUILDID/vendorsetup.sh |cut -d" " -f2)

# choose the right java JDK
# you need to have installed: openjdk-7-jdk for java1.7 and openjdk-6-jdk for v1.6
echo enabling correct java version depending on which Android version you want to build..
BUILDJAV=$(echo ${PWD##*/})
case "$BUILDJAV" in
        aosp_ics)
        #NEEDEDJAVA=java-6-oracle
        NEEDEDJAVA=java-1.6.0-openjdk-amd64
        JAVACBIN=/usr/lib/jvm/java-6-openjdk-amd64/bin/javac
	BUILDEXEC="make -j${MAXCPU}"
	;;
        aosp_jb)
        NEEDEDJAVA=java-1.6.0-openjdk-amd64
	JAVACBIN=/usr/lib/jvm/java-6-openjdk-amd64/bin/javac
	BUILDEXEC="make -j${MAXCPU}"
        ;;
        aosp_kk)
        #NEEDEDJAVA=java-7-oracle
        NEEDEDJAVA=java-1.7.0-openjdk-amd64
        JAVACBIN=/usr/lib/jvm/java-7-openjdk-amd64/bin/javac
	BUILDEXEC="make -j${MAXCPU}"
        ;;
        cm_ics|cm_jb)
	NEEDEDJAVA=java-6-oracle
        JAVACBIN=/usr/lib/jvm/$NEEDEDJAVA/bin/javac
	BUILDEXEC="mka"
        ;;
        cm_kk)
        NEEDEDJAVA=java-7-oracle
	JAVACBIN=/usr/lib/jvm/$NEEDEDJAVA/bin/javac
	#NEEDEDJAVA=java-1.7.0-openjdk-amd64
	#JAVACBIN=/usr/lib/jvm/java-7-openjdk-amd64/bin/javac
	BUILDEXEC="mka"
        ;;
	mm_*|ll_*|13.0|14.0|14.1)
        NEEDEDJAVA=java-7-oracle
        JAVACBIN=/usr/lib/jvm/$NEEDEDJAVA/bin/javac
        BUILDEXEC="mka"
        ;;
        *)
        if [ -z $NEEDEDJAVA ]||[ -z $JAVACBIN ];then
            echo "cannot determine best java version and you havent choosen JAVACBIN or NEEDEDJAVA var!"
            F_HELP
            exit 3
        fi
        ;;
esac
echo "... checking if we need to switch Java version" 
CURRENTJ=$(java -version 2>&1|grep version)
NEWJBIN=$(/usr/lib/jvm/$NEEDEDJAVA/bin/java -version 2>&1|grep version)
if [ "x$CURRENTJ" == "x$NEWJBIN" ];then
	echo "... skipping java switch because we already have the wanted version ($CURRENTJ == $NEWJBIN)"
else
	echo "($CURRENTJ vs. $NEWJBIN)"
	echo "... switching to $NEEDEDJAVA..."
	sudo update-java-alternatives -v -s $NEEDEDJAVA
fi

CURRENTC=$(javac -version 2>&1) 
NEWJCBIN=$($JAVACBIN -version 2>&1)
if [ "x$CURRENTC" == "x$NEWJCBIN" ];then
	echo "... skipping javaC switch because we already have the wanted version ($CURRENTC == $NEWJCBIN)"
else
	echo "($CURRENTC vs. $NEWJCBIN)"
	echo "... switching to $JAVACBIN..."
	sudo update-alternatives --set javac $JAVACBIN
fi
echo "DONE (Java)"

if [ x"$LOKIFY" == "x1" ];then

	# Loki specific
	LOKI="/home/xdajog/loki_tool"	# the loki patch binary
	ABOOT="/home/xdajog/aboot.img"	# the dd'ed image of aboot
	LOKINEED=boot.img		# the file which should be patched. will auto adjusted when you choosen 'recovery'
	LOKITYPE=boot			# the loki patch type. will auto adjusted when you choosen 'recovery' but not when 'mr_twrp'

	# Loki check
	if [ ! -f "$LOKI" ]||[ ! -f "$ABOOT" ];then
		echo missing loki binary. That means we can NOT lokifying for you!
		read DUMMY
		LOKIOK=3
	else
		echo "Great you have loki in place! So we are able to do loki for you at the end!"
		LOKIOK=0
	fi
else
	echo "Will not doing lokify because LOKIFY is not set."
    LOKIFY=0
    LOKIOK=0
fi

sec=$2

# check the targets
case $1 in
	otapackage|bootimage|systemimage|userdataimage)
		echo $1 choosen
		BUILDEXEC="$BUILDEXEC $1"
	;;
	multirom|trampoline|multirom_zip)
		echo $1 choosen
                BUILDEXEC="$BUILDEXEC $1"
		LOKIOK=1
		echo LOKI disabled because of your above choice
	;;
	recovery)
		echo $1 choosen
		BUILDEXEC="$BUILDEXEC ${1}image"
		LOKINEED=recovery.img
		LOKITYPE=recovery
	;;
	mr_twrp)
		echo $1 choosen
                BUILDEXEC="$BUILDEXEC recoveryimage"
                LOKINEED=recovery.img
		echo
		echo "***********************************************************"
		echo "PLEASE ENTER THE LOKI TYPE (can be 'boot' or 'recovery'):"
		read LOKITYPE
		echo "***********************************************************"
	;;
	mr_full)
		echo $1 choosen
		BUILDEXEC="$BUILDEXEC recoveryimage multirom trampoline"
		LOKINEED=recovery.img
		echo
		echo "***********************************************************"
                echo "PLEASE ENTER THE LOKI TYPE (can be 'boot' or 'recovery'):"
                read LOKITYPE
		echo "***********************************************************"
	;;
	free)
		echo "***********************************************************"
		echo "Enter your build choice (will NOT be verified!)"
		echo "Can be multiple choices - separated by space:"
		read BARG
		BUILDEXEC="$BUILDEXEC $BARG"
		echo "Do you want to LOKI? If so enter the Loki Type (recovery|boot) otherwise ENTER:"
		read "LOKITYPE"
		[ -z "$LOKITYPE" ]&& LOKIOK=1
		echo "***********************************************************"
	;;
        kernelonly)
		OUTDIR=./out
		CDIR=$(pwd)
		KARG="undef"

		echo "$1 with arg: $2 choosen"
		KARG="$2"

		while [ -z "$UARCH" ];do
		    read -p "No UARCH variable given so which architecture (x86 | x64)?" UARCH
		done

		[ _"$UARCH" == "_x64" ]&& RARCH=arm64
		[ _"$UARCH" == "_x86" ]&& RARCH=arm
		[ -z "$RARCH" ]&& echo -e "\n\nERROR: no valid arch defined!! x64 or x86 are the only valid\n\n" && exit 3
		
		[ -z "$KDIR" ] && KDIR="kernel/$BUILDID/"
                test -d $KDIR
		END=$?
		while [ $END -ne 0 ];do
		    test -d $KDIR
		    if [ $? -ne 0 ];then
			echo "expected kernel source $KDIR does not exists please enter the correct one:"
			read -p "kernel source dir> " KDIR
			test -d $KDIR
			END=$?
		    fi
		done
		cd $KDIR && echo "changed work directory to $KDIR"
		# check optional given args
		case "$KARG" in
			clean|mrproper)
			echo "CLEANING before make!"
			make mrproper
			make clean
			rm -Rf $OUTDIR
			mkdir -p $OUTDIR
			;;
			" "|""|undef)
			echo "No args given so no cleanup before doing the work.."
			;;
			*)
			echo 
			read -p "The given arg(s) $KARG will be IGNORED as those are not valid! Press ENTER to continue." DUMMY
			;;
		esac
		mkdir -p $OUTDIR
		
      	        while [ -z "$KCONF" ]||[ ! -r arch/$RARCH/configs/$KCONF ];do
			echo "config $KCONF invalid or not defined!"
			ls -la arch/$RARCH/configs/$KCONF
			echo "No KCONF given so please enter your kernel defconfig filename:"
			read "KCONF"
		done

		if [ "$RARCH" == "arm64" ];then
			# Toolchain UBER 4.9 !
			# TODO: make the TC selectable..
			#CCPATH="$HOME/android/$BUILDJAV/prebuilts/gcc/linux-x86/aarch64-linux-android-4.9-kernel/bin"
			#CCPREFIX="aarch64-linux-android-"
                        CCPATH=$(pwd)/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin
			#CCPATH="$HOME/android/$BUILDJAV/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin"
			CCPREFIX="aarch64-linux-android-"
        	        TC="UBER4.9"
		else
		    if [ "$RARCH" == "arm" ];then
                        # TODO: make the TC selectable..
                        CCPATH="$(pwd)/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8/bin"
			CCPREFIX="arm-eabi-"
		    else
			echo -e "\n\nERROR: no valid ARCH defined! Restart and choose either x86 or x64!!\n\n"
			exit 3
		    fi
		fi
                while [ ! -d ${CCPATH} ];do
                        echo "cross compile path invalid or not defined!"
			echo "CCPATH: $CCPATH"
                        echo "Please enter the toolchain path"
                        read -p "(FULL path required!) " CCPATH
                done
		# where the kernel resists
		ZIMAGE_DIR=$OUTDIR/arch/$RARCH/boot/

		export ARCH=$RARCH
		export TARGET_PRODUCT=${BUILDID#*/}_xdajog
		export TARGET_KERNEL_CONFIG=$KCONF
		export CROSS_COMPILE="${CCPATH}/${CCPREFIX}"
		export KCONF=$KCONF

		# build kernel device tree 
                MBTOOLS="$HOME/android/$BUILDJAV/prebuilts/devtools/mkbootimg_tools"
		KERNOUT=$OUTDIR/kernel
		DTDIR="$CDIR/device/$BUILDID"
		mkdir -p $KERNOUT
		
		# Need to have KDTB set with the main call!
		if [ "$RARCH" == "arm64" ];then	
			DTBIMAGE="dtb"

			make O="$OUTDIR" $KCONF -Werror && echo "makefile done. now starting the machines... " \
				&& make O="$OUTDIR" -j$MAXCPU -Werror \
				&& echo "make completed successfully! Now copying the kernel to your device tree folder" \
				&& cp -v $ZIMAGE_DIR/Image.gz-dtb $DTDIR/Image.gz-dtb.new \
				&& echo "Now starting DTB creation" \
				&& $MBTOOLS/dtbToolCM -2 -o $KERNOUT/$DTBIMAGE -s 2048 -p $OUTDIR/scripts/dtc/ $OUTDIR/arch/$RARCH/boot/dts/ \
                		&& cp -v $KERNOUT/$DTBIMAGE $DTDIR/dtb.img-new \
				&& md5sum $KERNOUT/$DTBIMAGE $DTDIR/dtb.img-new $ZIMAGE_DIR/Image.gz-dtb $DTDIR/Image.gz-dtb.new \
				&& echo -e "\nAll done successfull!!\n\n\t--> KERNEL:\t$DTDIR/Image.gz-dtb.new\n\t--> DTB:\t$DTDIR/dtb.img-new\n\n"
		else
	                make O="$OUTDIR" $KCONF && echo "makefile done. now starting the machines... " \
       		             	&& make O="$OUTDIR" -j$MAXCPU zImage \
       		             	&& echo "make completed successfully! Now copying the kernel to your device tree folder" \
			    	&& cp $ZIMAGE_DIR/zImage $DTDIR/zImage.new \
			    	&& md5sum $ZIMAGE_DIR/zImage $DTDIR/zImage.new \
                    		&& echo -e "\nAll done successfull!!\n\n\t--> KERNEL:\t$DTDIR/zImage.new\n"

		fi
		
		echo TARGET_PRODUCT was $TARGET_PRODUCT
		cd $CDIR
		echo "changed work directory back to root"
		LOKIOK=1
		echo LOKI disabled because of kernelonly

		exit
	;;
	clean|installclean)	
		echo will do $1 only..
		make $1
		[ -d kernel/$BUILDID/out ]&& rm -R kernel/$BUILDID/out
		[ -d $KDIR/out ]&& rm -R $KDIR/out 
		exit 2
	;;
	*)
		F_HELP
		exit 2
	;;
esac

if [ ! -z "$sec" ];then
	case $sec in
		clean)
			echo will $sec before
			make $sec
			[ -d kernel/$BUILDID/out ]&& rm -R kernel/$BUILDID/out
		;;
		installclean)
			echo will $sec before
			make $sec
			[ -d kernel/$BUILDID/out ]&& rm -R kernel/$BUILDID/out
		;;
		*)
			echo unknown clean arg aborted
			exit 3
		;;
	esac
fi

source $SRCDIR && lunch $BUILDWHAT && time $BUILDEXEC

BUILDEND=$?

echo "... BUILD ended with errorlevel = $BUILDEND"

if [ $LOKIFY -eq 1 ] && [ $LOKIOK -eq 0 ]&&[ $BUILDEND -eq 0 ];then
	echo "Lokifying ($LOKINEED as $LOKITYPE)..."
	$LOKI patch $LOKITYPE $ABOOT out/target/product/fx3q/$LOKINEED out/target/product/fx3q/${LOKINEED}.lokied
else
	echo "... skipping loki"
fi


