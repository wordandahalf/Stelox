#!/bin/sh

cross="/mnt/d/Workspace/WSL/CC/i686-elf-4.9.1/bin/i686-elf-"

rm -rf kernel/boot.o kernel/kernel.o build/images/stelox.bin build/images/stelox.iso

as -march generic64 kernel/boot.s -o kernel/boot.o
g++ -c kernel/kernel.cpp -o kernel/kernel.o -ffreestanding -O2 -Wall -Wextra -fno-exceptions -fno-rtti
gcc -T kernel/link.ld -o build/images/stelox.bin -ffreestanding -O2 -nostdlib kernel/kernel.o kernel/boot.o -lgcc

mkdir -p build/iso/boot/grub
mkdir -p build/images/
cp build/images/stelox.bin build/iso/boot/stelox.bin
cp build/grub.cfg build/iso/boot/grub/grub.cfg
grub-mkrescue -o build/images/stelox.iso build/iso

#qemu-system-i386 -cdrom build/images/stelox.iso