#!/bin/sh

CURRENT_DIRECTORY="${PWD##*/}"

if [ "$CURRENT_DIRECTORY" != "utils" ]; then
    echo "get-gnu-efi.sh should be run from the utils folder!"
    exit
fi

wget 'https://iweb.dl.sourceforge.net/project/gnu-efi/gnu-efi-3.0.11.tar.bz2'
tar xjf gnu-efi-*.tar.bz2
cd gnu-efi-*/
make

mkdir ../gnu-efi
mkdir ../gnu-efi/efi-lib
mkdir ../gnu-efi/lib

cp x86_64/gnuefi/crt0-efi-x86_64.o ../gnu-efi/efi-lib/
cp gnuefi/elf_x86_64_efi.lds ../gnu-efi/efi-lib/

cp -r inc/ ../gnu-efi/

cp x86_64/lib/libefi.a ../gnu-efi/lib/
cp x86_64/gnuefi/libgnuefi.a ../gnu-efi/lib/

cd ..
rm -rf gnu-efi-*/
rm -rf gnu-efi-*.tar.bz2
