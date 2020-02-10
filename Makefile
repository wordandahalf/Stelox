BASE_BUILD_FOLDER		= build
BASE_UTILS_FOLDER		= utils
BASE_IMAGE_FOLDER		= $(BASE_BUILD_FOLDER)/images

SUPPORTED_ARCHITECTURES	= i386, x86_64, x86-multi

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

# ISO-generation variables

HYBRID_MBR_BIN			= /usr/lib/ISOLINUX/isohdpfx.bin

ifneq ($(filter $(ARCH),$(SUPPORTED_ARCHITECTURES:,=)),)
stub: $(ARCH)
run: $(ARCH)
	$(QEMU_$(ARCH)) $(QEMU_$(ARCH)_FLAGS)
else
ifndef ARCH
stub:
	@echo "Please provide a supported architecture."
	@echo "Supported architectures: $(SUPPORTED_ARCHITECTURES)"
else
stub:
	@echo "Unsupported architecture '$(ARCH)'..."
	@echo "Supported architectures: $(SUPPORTED_ARCHITECTURES)"
endif
endif

x86-multi: $(HYBRID_MBR_BIN)
	@make -C boot/ -f Makefile bootloader ARCH=i386
	@make -C boot/ -f Makefile bootloader ARCH=x86_64
	@#make -C kernel/ -f Makefile kernel ARCH=i386

	@xorriso -as mkisofs \
		-c boot/boot.cat \
		-b boot/boot.img \
		-no-emul-boot -boot-load-size 10 \
		-isohybrid-mbr $(HYBRID_MBR_BIN) \
		-eltorito-alt-boot \
		-e boot/efi/efi.fat \
		-no-emul-boot -isohybrid-gpt-basdat \
		-o $(STELOX_ISO) \
		-graft-points boot/boot.img=$(BIOS_BOOT_IMAGE) boot/efi/efi.fat=$(UEFI_BOOT_FAT)
		@# TODO: kernel/kernel.elf=$(KERNEL_IMAGE)

$(HYBRID_MBR_BIN):
	$(error "$(HYBRID_MBR_BIN) not found, please instal ISOLINUX")

x86_64: $(OVMF)
	@make -C boot/ -f Makefile bootloader ARCH=x86_64
	@#make -C kernel/ -f Makefile kernel ARCH=x86_64

	@xorriso -as mkisofs -R -f -e boot/efi/efi.fat -no-emul-boot -o $(STELOX_ISO) \
		-graft-points boot/efi/efi.fat=$(UEFI_BOOT_FAT)
		@# TOOD: kernel/kernel.elf=$(KERNEL_IMAGE)

$(OVMF):
	@echo "OVMF was not found, downloading..."
	@mkdir -p $(OVMF_FOLDER)
	@wget $(OVMF_URL) -O $(OVMF) -qq

i386:
	@make -C boot/ -f Makefile bootloader ARCH=i386
	@#make -C kernel/ -f Makefile kernel ARCH=i386

	@xorriso -as mkisofs -R -J -c boot/bootcat -b boot/boot.img -no-emul-boot \
		-boot-load-size 12 -o $(STELOX_ISO) -V SteloxCD -input-charset utf-8 \
		-graft-points boot/boot.img=$(BIOS_BOOT_IMAGE)
		@# TOOD: kernel/kernel.elf=$(KERNEL_IMAGE)