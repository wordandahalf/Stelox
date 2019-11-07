# General variables

GCC					:= gcc
LD					:= ld
OBJCOPY				:= objcopy

# Kernel variables

KERNEL_FOLDER		:= kernel
KERNEL_LINKER_FILE	:= $(KERNEL_FOLDER)/linker.ld
KERNEL_IMAGE		:= $(KERNEL_FOLDER)/kernel.elf

KERNEL_SOURCES		:= $(KERNEL_FOLDER)/kernel.c

KERNEL_OBJECTS		:= $(KERNEL_SOURCES:.c=.o)

KERNEL_CFLAGS		:= -fno-pie -Os -g -std=gnu99 -Wall -Wextra -pedantic -Wshadow -Wpointer-arith \
           				-Wcast-align -Wwrite-strings -Wmissing-prototypes -Wmissing-declarations \
            			-Wredundant-decls -Wnested-externs -Winline -Wno-long-long \
        				-Wconversion -Wstrict-prototypes

KERNEL_LD_FLAGS		:= -e main -o $(KERNEL_IMAGE)

# EFI variables

EFI_BOOT_SOURCES	:= boot/uefi/main.c
EFI_BOOT_OBJECTS	:= $(EFI_BOOT_SOURCES:.c=.o)

EFI_ELF_OBJECT		:= boot/uefi/bootx64.so

EFI_INCLUDE			:= boot/uefi/include

IMAGE_FOLDER		:= image
FAT_FOLDER			:= $(IMAGE_FOLDER)/fat

EFI_BOOT_ISO		:= $(IMAGE_FOLDER)/efi.iso
EFI_BOOT_FAT		:= $(IMAGE_FOLDER)/efi.fat

EFI_BOOT_FOLDER		:= $(FAT_FOLDER)/efi/boot
EFI_BOOT_TARGET		:= $(EFI_BOOT_FOLDER)/bootx64.efi

UTILS_FOLDER		:= utils

GNU_EFI				:= $(UTILS_FOLDER)/gnu-efi
GNU_EFI_INCLUDE 	:= $(GNU_EFI)/inc
GNU_EFI_LIBRARY		:= $(GNU_EFI)/lib

GNU_EFI_EFI_LIB		:= $(GNU_EFI)/efi-lib
GNU_EFI_CRT_OBJ		:= $(GNU_EFI_EFI_LIB)/crt0-efi-x86_64.o
GNU_EFI_ELF_LDS		:= $(GNU_EFI_EFI_LIB)/elf_x86_64_efi.lds

EFI_CFLAGS      	:= -I$(EFI_INCLUDE) -I$(GNU_EFI_INCLUDE) -I$(GNU_EFI_INCLUDE)/x86_64 -I$(GNU_EFI_INCLUDE)/protocol -fno-stack-protector -fpic -fshort-wchar -mno-red-zone -Wall -DEFI_FUNCTION_WRAPPER 

EFI_LDFLAGS     	:= -nostdlib -znocombreloc -T $(GNU_EFI_ELF_LDS) -shared -Bsymbolic -L $(GNU_EFI_EFI_LIB) -L $(GNU_EFI_LIBRARY) $(GNU_EFI_CRT_OBJ)

EFI_OBJCOPY_FLAGS	:= -j .text -j .sdata -j .data -j .dynamic -j .dynsym  -j .rel -j .rela -j .reloc --target=efi-app-x86_64

OVMF_URL			:= https://dl.bintray.com/no92/vineyard-binary/OVMF.fd
OVMF_BIN			:= OVMF.fd
OVMF				:= utils/OVMF/$(OVMF_BIN)

QEMU_EFI			:= qemu-system-x86_64
QEMU_EFI_FLAGS		:= -drive if=pflash,format=raw,file=$(OVMF) -cdrom $(EFI_BOOT_ISO) -net none -serial stdio -d guest_errors

all: test  

test: cdrom
	@DISPLAY=:0 \
	$(QEMU_EFI) $(QEMU_EFI_FLAGS)

cdrom: clean $(EFI_BOOT_TARGET) $(KERNEL_IMAGE)
	-@echo "Creating ISO image..."
	@dd if=/dev/zero of=$(EFI_BOOT_FAT) count=1 status=none bs=1M
	@mkfs.fat $(EFI_BOOT_FAT)
	@mcopy -si $(EFI_BOOT_FAT) $(FAT_FOLDER)/* ::/

	@xorriso -as mkisofs -R -f -e boot/efi/efi.fat -no-emul-boot -o $(EFI_BOOT_ISO) \
	-graft-points boot/efi/efi.fat=$(EFI_BOOT_FAT) kernel/kernel.elf=$(KERNEL_IMAGE)

clean: $(OVMF)
	-@echo "Cleaning..."
	-mkdir -p $(FAT_FOLDER) $(EFI_BOOT_FOLDER) $(UTILS_FOLDER)
	-rm -f $(UEFI_IMAGE) $(EFI_BOOT_OBJECTS) $(EFI_BOOT_TARGET) $(EFI_BOOT_ISO) $(EFI_BOOT_FAT) $(KERNEL_OBJECTS) $(KERNEL_IMAGE)

kernel/%.o: kernel/%.c
	@echo Compiling $@ to $<
	@ARCH="$(ARCH)"; \
	if [ "$$ARCH" = "i386" ]; then \
		$(GCC) -c -o $@ -m32 $(KERNEL_CFLAGS) $<; \
	elif [ "$$ARCH" = "x86_64" ]; then \
		$(GCC) -c -o $@ $(KERNEL_CFLAGS) $<; \
	fi

$(KERNEL_IMAGE): $(KERNEL_OBJECTS)
	@echo Linking kernel for $(ARCH) target
	@ARCH="$(ARCH)"; \
	if [ "$$ARCH" = "i386" ]; then \
		$(LD) -e main -m elf_i386 $^ -o $@; \
	elif [ "$$ARCH" = "x86_64" ]; then \
		$(LD) -e main -m elf_x86_64 $^ -o $@; \
	fi

boot/uefi/%.o: boot/uefi/%.c
	@$(GCC) -c -o $@ $(EFI_CFLAGS) $<

$(EFI_ELF_OBJECT): $(EFI_BOOT_OBJECTS)
	@$(LD) $(EFI_LDFLAGS) $^ -o $@ -lefi -lgnuefi

$(EFI_BOOT_TARGET): $(EFI_ELF_OBJECT)
	$(eval ARCH:=x86_64)
	$(OBJCOPY) $(EFI_OBJCOPY_FLAGS) $^ $@

$(OVMF):
	@echo "Downloading OVMF for UEFI boot..."
	@mkdir -p utils/OVMF
	wget $(OVMF_URL) -O $(OVMF) -qq