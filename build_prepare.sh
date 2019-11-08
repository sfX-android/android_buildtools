#!/bin/bash
#####################################################################

echo -e "\nThis sets the OTA package path to /tmp and depending on your selection\nmake an insecure build as well.\n\n"

F_INSEC(){
    echo -e "... prepare insecure building:"
    sed -i "s/secure=./secure=0/g" vendor/lineage/config/common.mk
    echo -e "vendor/lineage/config/common.mk:\t$(grep secure= vendor/lineage/config/common.mk |tr '\n' ,)\n"
}

F_TMP(){
    echo -e "... set path to ramdisk:"
    ROUTPATH=out/zip
    [ ! -L $ROUTPATH ] && ln -s /tmp/zip $ROUTPATH
    sed -i 's#INTERNAL_OTA_PACKAGE_TARGET := .*/$(name).zip#INTERNAL_OTA_PACKAGE_TARGET := ${OUT_DIR}/zip/$(name).zip#g' build/core/Makefile
    echo -e "build/core/Makefile:\t\t\t$(grep  'INTERNAL_OTA_PACKAGE_TARGET :=' build/core/Makefile)\n"
}

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
    disable)
	echo -e "This will RESET ALL PROJECTS to default (repo forall -vc 'git reset --hard')!"
	read -p "Are you sure? <y|N>" ANS
	[ "$ANS" == "y" ] && repo forall -vc "git reset --hard"
	shift
    ;;
    *)
	echo -e "\nneed either arg: insecure, setpath or disable\nmultiple options allowed for insecure, setpath but not for disable\n\n" && exit 9
    ;;
  esac
done
