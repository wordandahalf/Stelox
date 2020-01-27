BASE_BUILD_FOLDER		= build
BASE_UTILS_FOLDER		= utils
BASE_IMAGE_FOLDER		= $(BASE_BUILD_FOLDER)/images

SUPPORTED_ARCHITECTURES	= i386 x86_64

# General build variables

STELOX_ISO				= $(BASE_IMAGE_FOLDER)/stelox.iso

# UEFI (x86-64) build variables

UEFI_BOOT_FAT			= $(BASE_IMAGE_FOLDER)/efi.fat

# BIOS (x86) build variables

BIOS_BOOT_IMAGE			= $(BASE_IMAGE_FOLDER)/boot.img

# QEMU variables

# OVMF is a freely-available UEFI for QEMU
OVMF_FOLDER				= $(BASE_UTILS_FOLDER)/OVMF
OVMF					= $(OVMF_FOLDER)/OVMF.fd
OVMF_URL				= https://dl.bintray.com/no92/vineyard-binary/OVMF.fd

QEMU_x86_64				= qemu-system-x86_64
QEMU_x86_64_FLAGS		= -drive if=pflash,format=raw,file=$(OVMF) -cdrom $(STELOX_ISO) -net none -serial stdio -d guest_errors

QEMU_i386				= qemu-system-i386
QEMU_i386_FLAGS			= -d guest_errors -cdrom $(STELOX_ISO)

clean:
	@make -C boot/ -f Makefile clean
	@#make -C kernel/ -f Makefile clean

	@rm -rf $(STELOX_ISO)

ifneq ($(filter $(ARCH),$(SUPPORTED_ARCHITECTURES)),)
run: $(ARCH)
	$(QEMU_$(ARCH)) $(QEMU_$(ARCH)_FLAGS)
else
run:
	@echo "Unsupported architecture $(ARCH)..."
	@echo "Supported architectures: i386, x86_64"
endif


x86_64: $(OVMF)
	@make -C boot/ -f Makefile bootloader ARCH=x86_64
	@#make -C kernel/ -f Makefile kernel ARCH=x86_64

	@xorriso -as mkisofs -R -f -e boot/efi/efi.fat -no-emul-boot -o $(STELOX_ISO) \
		-graft-points boot/efi/efi.fat=$(UEFI_BOOT_FAT)
		@# TOOD: kernel/kernel.elf=$(KERNEL_IMAGE)

i386:
	@make -C boot/ -f Makefile bootloader ARCH=i386
	@#make -C kernel/ -f Makefile kernel ARCH=i386

	@xorriso -as mkisofs -R -J -c boot/bootcat -b boot/boot.img -no-emul-boot \
		-boot-load-size 10 -o $(STELOX_ISO) -V SteloxCD -input-charset utf-8 \
		-graft-points boot/boot.img=$(BIOS_BOOT_IMAGE)
		@# TOOD: kernel/kernel.elf=$(KERNEL_IMAGE)

$(OVMF):
	@echo "OVMF was not found, downloading..."
	@mkdir -p $(OVMF_FOLDER)
	@wget $(OVMF_URL) -O $(OVMF) -qq