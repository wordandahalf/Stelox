#!/bin/bash

helpFunction() {
   echo ""
   echo "Usage: $0 -i [UEFI application] -o [image location]"
   echo -e "\t-i Path to the UEFI application to insert into the image"
   echo -e "\t-o Destination path of the created image"
   exit 1 # Exit script after printing help
}

while getopts "i:o:" opt
do
   case "$opt" in
      i ) input="$OPTARG" ;;
      o ) output="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

if [ -z "$input" ] || [ -z "$output" ]
then
   helpFunction
fi

# Begin script in case all parameters are correct
echo "Assembling FAT16-formated image '$output' with boot executable '$input'"

dd if=/dev/zero of="$output" count=1440 bs=1k status=none
mformat -i "$output" -f 1440 ::
mmd -i "$output" ::/EFI
mmd -i "$output" ::/EFI/BOOT
mcopy -si "$output" "$input" ::/EFI/BOOT