#!/bin/bash
#############################################################################################################
# Print the bootloader IDs for devices supporting it
#
# Usage:
#   print-bootloader-id.sh /path/to/avb_pkmd.bin
#############################################################################################################
# License: MIT
#############################################################################################################

key="$1"

if [ ! -f "$key" ];then
    echo "missing key or not existent: $key"
    exit 4
fi 

FPID=$(cat "$key" | openssl dgst -sha256 | cut -d "=" -f 2 | tr -d " " | tr "[[:lower:]]" "[[:upper:]]")
echo -e "\nBOOTLOADER minimal ID"
echo -e "\t${FPID:0:8}\n"
echo -e "BOOTLOADER full ID:"
echo -e "\t${FPID:0:16}"
echo -e "\t${FPID:16:16}"
echo -e "\t${FPID:32:16}"
echo -e "\t${FPID:48:16}\n"
