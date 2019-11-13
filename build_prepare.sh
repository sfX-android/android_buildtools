#!/bin/bash
#####################################################################

echo -e "\nThis sets the OTA package path to /tmp and depending on your selection\nmake an insecure build as well.\n\n"

F_CHECK(){
	echo -e "\nYour current settings:\n"
	echo -e "OTA path:\n$(grep 'INTERNAL_OTA_PACKAGE_TARGET :=' build/core/Makefile)"
	echo -e "\ninsecure state (vendor/lineage/config/common.mk):\n$(grep "secure=" vendor/lineage/config/common.mk)"
        echo -e "\nselinux state (device/lge/g4-common/BoardConfigCommon.mk):\n$(grep 'androidboot.selinux=' device/lge/g4-common/BoardConfigCommon.mk)"
	echo
}

F_INSEC(){
    echo -e "... prepare insecure building:"
    sed -i "s/ro.adb.secure=./ro.adb.secure=0/" vendor/lineage/config/common.mk
    echo -e "... set the build permissive..."
    sed -i 's/androidboot.selinux=enforcing/androidboot.selinux=permissive/g' device/lge/g4-common/BoardConfigCommon.mk
    F_CHECK
}

F_INSEC_OFF(){
    echo -e "... prepare secure building:"
    CPWD=$(pwd)
    cd vendor/lineage/ && git reset --hard
    cd $CPWD
    echo -e "vendor/lineage/config/common.mk:\t$(grep secure= vendor/lineage/config/common.mk |tr '\n' ,)\n"
    echo -e "... set the build to enforcing.."
    sed -i 's/androidboot.selinux=permissive/androidboot.selinux=enforcing/g' device/lge/g4-common/BoardConfigCommon.mk
    F_CHECK
}

F_TMP(){
    echo -e "... set path to ramdisk:"
    ROUTPATH=out/zip
    [ ! -L $ROUTPATH ] && ln -s /tmp/zip $ROUTPATH
    sed -i 's#INTERNAL_OTA_PACKAGE_TARGET := .*/$(name).zip#INTERNAL_OTA_PACKAGE_TARGET := ${OUT_DIR}/zip/$(name).zip#g' build/core/Makefile
    echo -e "build/core/Makefile:\t\t\t$(grep  'INTERNAL_OTA_PACKAGE_TARGET :=' build/core/Makefile)\n"
    F_CHECK
}

F_HELP(){
	echo -e "\nValid args: insecure, setpath, check, resetall"
	echo -e "\nmultiple options are allowed for: insecure and setpath but NOT for resetinsecure or resetall\n\n"
	exit 9

}

case $1 in 
    help|-help|--help)
    F_HELP
    ;;
    insecure|setpath|resetinsecure|resetall|check)
    ;;
    *)
    echo -e "\nmissing arg!!"
    F_HELP
    ;;
esac

while [ ! -z "$1" ];do
  case $1 in
    insecure)
	F_INSEC
	shift
    ;;
    setpath)
	F_TMP
	shift
    ;;
    resetinsecure)
        F_INSEC_OFF
        exit
    ;;
    resetall)
	echo -e "This will RESET ALL PROJECTS to default (repo forall -vc 'git reset --hard')!"
	read -p "Are you sure? <y|N>" ANS
	[ "$ANS" == "y" ] && repo forall -vc "git reset --hard"
	exit
    ;;
    check)
        F_CHECK
	exit
    ;;
    *)
    F_HELP
    ;;
  esac
done
