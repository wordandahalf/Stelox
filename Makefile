UEFI_IMAGE		:= boot/uefi/bootx64.so

OBJS            := boot/uefi/main.o

IMAGE_FOLDER	:= image
ISO_FOLDER		:= $(IMAGE_FOLDER)/iso
FAT_FOLDER		:= $(IMAGE_FOLDER)/fat

EFI_BOOT_ISO	:= $(IMAGE_FOLDER)/efi.iso
EFI_BOOT_FAT	:= $(IMAGE_FOLDER)/efi.fat

EFI_BOOT_FOLDER	:= $(FAT_FOLDER)/efi/boot
EFI_BOOT_TARGET	:= $(EFI_BOOT_FOLDER)/bootx64.efi

UTILS_FOLDER	:= utils

GNU_EFI			:= $(UTILS_FOLDER)/gnu-efi
GNU_EFI_INCLUDE := $(GNU_EFI)/inc
GNU_EFI_LIBRARY	:= $(GNU_EFI)/lib

GNU_EFI_EFI_LIB	:= $(GNU_EFI)/efi-lib
GNU_EFI_CRT_OBJ	:= $(GNU_EFI_EFI_LIB)/crt0-efi-x86_64.o
GNU_EFI_ELF_LDS	:= $(GNU_EFI_EFI_LIB)/elf_x86_64_efi.lds

CFLAGS      	:= -I$(GNU_EFI_INCLUDE) -I$(GNU_EFI_INCLUDE)/x86_64 -I$(GNU_EFI_INCLUDE)/protocol -fno-stack-protector -fpic -fshort-wchar -mno-red-zone -Wall -DEFI_FUNCTION_WRAPPER 

LDFLAGS     	:= -nostdlib -znocombreloc -T $(GNU_EFI_ELF_LDS) -shared -Bsymbolic -L $(GNU_EFI_EFI_LIB) -L $(GNU_EFI_LIBRARY) $(GNU_EFI_CRT_OBJ)

OVMF_URL		:= https://dl.bintray.com/no92/vineyard-binary/OVMF.fd
OVMF_BIN		:= OVMF.fd
OVMF			:= utils/OVMF/$(OVMF_BIN)

EMU				:= qemu-system-x86_64
EMUFLAGS		:= -drive if=pflash,format=raw,file=$(OVMF) -cdrom $(EFI_BOOT_ISO) -net none -serial stdio

clean:
	mkdir -p $(ISO_FOLDER) $(FAT_FOLDER) $(EFI_BOOT_FOLDER) $(UTILS_FOLDER)
	rm -f $(UEFI_IMAGE) $(OBJS) $(EFI_BOOT_TARGET) $(EFI_BOOT_ISO) $(EFI_BOOT_FAT) $(ISO_FOLDER)/*

all: test cdrom clean

test: cdrom
	@DISPLAY=:0 \
	$(EMU) $(EMUFLAGS)

cdrom: $(EFI_BOOT_TARGET) $(OVMF)
	dd if=/dev/zero of=$(EFI_BOOT_FAT) count=1 bs=1M
	mkfs.fat $(EFI_BOOT_FAT)
	mcopy -si $(EFI_BOOT_FAT) $(FAT_FOLDER)/* ::/
	cp $(EFI_BOOT_FAT) $(ISO_FOLDER)

	xorriso -as mkisofs -R -f -e $(notdir $(EFI_BOOT_FAT)) -no-emul-boot -o $(EFI_BOOT_ISO) $(ISO_FOLDER)

%.o: %.c
	gcc -c -o $@ $(CFLAGS) $<

$(UEFI_IMAGE): $(OBJS)
	ld $(LDFLAGS) $(OBJS) -o $@ -lefi -lgnuefi

$(EFI_BOOT_TARGET): $(UEFI_IMAGE)
	objcopy -j .text -j .sdata -j .data -j .dynamic \
		-j .dynsym  -j .rel -j .rela -j .reloc \
		--target=efi-app-x86_64 $^ $@

$(OVMF):
	mkdir -p utils/OVMF
	wget $(OVMF_URL) -O $(OVMF) -qq