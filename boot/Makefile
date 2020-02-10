# General folder variables

BASE_PROJECT_FOLDER 	?= $(shell dirname $(shell pwd))
BASE_BOOT_FOLDER		= $(shell pwd)

BASE_BUILD_FOLDER		= $(BASE_PROJECT_FOLDER)/build
BASE_UTILS_FOLDER		= $(BASE_PROJECT_FOLDER)/utils

BASE_IMAGE_FOLDER		= $(BASE_BUILD_FOLDER)/images

# General command variables

ifdef CROSS
GCC_i386				= $(CROSS)-gcc
LD_i386					= $(CROSS)-ld
OBJCOPY_i386			= $(CROSS)-objcopy
LIBGCC_i386				= $(shell $(GCC_i386) -print-libgcc-file-name)
else
GCC_i386				= gcc
LD_i386					= ld
OBJCOPY_i386			= objcopy
endif

GCC_x86_64				= gcc
LD_x86_64				= ld
OBJCOPY_x86_64			= objcopy

NASM					= nasm

# UEFI (x86-64) build variables

UEFI_BOOTLOADER_FOLDER	= $(BASE_BOOT_FOLDER)/x86_64
UEFI_BUILD_FOLDER		= $(BASE_BUILD_FOLDER)/x86_64/boot
UEFI_INCLUDE_FOLDER 	= $(UEFI_BOOTLOADER_FOLDER)/include

UEFI_FAT_FOLDER			= $(BASE_IMAGE_FOLDER)/fat
UEFI_BOOT_FOLDER		= $(UEFI_FAT_FOLDER)/efi/boot

UEFI_C_SOURCES			= $(UEFI_BOOTLOADER_FOLDER)/main.c

UEFI_BOOT_OBJECTS		= $(UEFI_C_SOURCES:.c=.o)

# Objects are put in the build/ folder

UEFI_BOOT_OBJECTS		:= $(subst $(UEFI_BOOTLOADER_FOLDER),$(UEFI_BUILD_FOLDER),$(UEFI_BOOT_OBJECTS))

UEFI_ELF_OBJECT			= $(UEFI_BUILD_FOLDER)/bootx64.so

UEFI_BOOT_TARGET		= $(UEFI_BOOT_FOLDER)/bootx64.efi
UEFI_BOOT_FAT			= $(BASE_IMAGE_FOLDER)/efi.fat

# GNU-EFI library variables

GNU_EFI_FOLDER			= $(BASE_UTILS_FOLDER)/gnu-efi
GNU_EFI_INCLUDE_FOLDER 	= $(GNU_EFI_FOLDER)/inc
GNU_EFI_LIBRARY_FOLDER 	= $(GNU_EFI_FOLDER)/lib

GNU_EFI_EFI_LIBRARY 	= $(GNU_EFI_FOLDER)/efi-lib
GNU_EFI_CRT_OBJ 		= $(GNU_EFI_EFI_LIBRARY)/crt0-efi-x86_64.o
GNU_EFI_ELF_LDS 		= $(GNU_EFI_EFI_LIBRARY)/elf_x86_64_efi.lds

GNU_EFI_SCRIPT			= $(BASE_UTILS_FOLDER)/get-gnu-efi.sh

# UEFI build command arguments

UEFI_CFLAGS      		:= -I$(UEFI_INCLUDE_FOLDER) -I$(GNU_EFI_INCLUDE_FOLDER) -I$(GNU_EFI_INCLUDE_FOLDER)/x86_64 -I$(GNU_EFI_INCLUDE_FOLDER)/protocol -fno-stack-protector -fpic -fshort-wchar -mno-red-zone -Wall -DEFI_FUNCTION_WRAPPER 

UEFI_LDFLAGS     		:= -nostdlib -znocombreloc -T $(GNU_EFI_ELF_LDS) -shared -Bsymbolic -L $(GNU_EFI_EFI_LIBRARY) -L $(GNU_EFI_LIBRARY_FOLDER) $(GNU_EFI_CRT_OBJ)

UEFI_OBJCOPY_FLAGS		:= -j .text -j .sdata -j .data -j .dynamic -j .dynsym  -j .rel -j .rela -j .reloc --target=efi-app-x86_64

# BIOS (x86) build variables

BIOS_BOOTLOADER_FOLDER 	= $(BASE_BOOT_FOLDER)/i386
BIOS_BUILD_FOLDER		= $(BASE_BUILD_FOLDER)/i386/boot
BIOS_INCLUDE_FOLDER 	= $(BIOS_BOOTLOADER_FOLDER)/include

BIOS_ASM_SOURCES 		= $(BIOS_BOOTLOADER_FOLDER)/stage0.asm $(BIOS_BOOTLOADER_FOLDER)/stage1.asm
BIOS_C_SOURCES 			= $(BIOS_BOOTLOADER_FOLDER)/stage2.c
BIOS_BOOT_OBJECTS 		= $(BIOS_ASM_SOURCES:.asm=.bin)
BIOS_BOOT_OBJECTS 		+= $(BIOS_C_SOURCES:.c=.o)

# Objects are put in the build/ folder

BIOS_BOOT_OBJECTS		:= $(subst $(BIOS_BOOTLOADER_FOLDER),$(BIOS_BUILD_FOLDER),$(BIOS_BOOT_OBJECTS))

BIOS_LINKER				= $(BIOS_BOOTLOADER_FOLDER)/linker.ld

BIOS_BOOT_IMAGE			= $(BASE_IMAGE_FOLDER)/boot.img

# BIOS (x86) build command variables

BIOS_NASM_FLAGS			= -f elf32
BIOS_CFLAGS				= -fno-pie -std=gnu99 -ffreestanding -O2 -Wall -Wextra -I$(BIOS_INCLUDE_FOLDER)

ifdef ARCH
ifneq ($(ARCH),$(shell arch))
ifdef CROSS
bootloader: clean-$(ARCH) bootloader-$(ARCH)
else
bootloader:
	$(error A cross compiler is required for target '$(ARCH)')
clean: clean-$(ARCH)
endif
else
bootloader: clean bootloader-$(ARCH)
clean: clean-$(ARCH)
endif
else
bootloader:
	$(error No target architecture was passed)
clean:
	$(error No target architecture was passed)
endif

# UEFI build commands

clean-x86_64: $(GNU_EFI_FOLDER)
	-@echo "Cleaning UEFI bootloader files..."
	-@mkdir -p $(UEFI_BOOT_IMAGE_FOLDER) $(UEFI_BOOT_FOLDER) $(UEFI_FAT_FOLDER) $(UEFI_BUILD_FOLDER)
	-@rm -rf $(UEFI_BOOT_OBJECTS) $(UEFI_ELF_OBJECT) $(UEFI_BOOT_TARGET) $(UEFI_BOOT_FAT)

$(GNU_EFI_FOLDER): $(GNU_EFI_SCRIPT)
	@echo "GNU-EFI was not found, downloading..."
	@cd $(BASE_UTILS_FOLDER) && \
	$(GNU_EFI_SCRIPT) && \
	cd $(BASE_BOOT_FOLDER)

bootloader-x86_64: $(UEFI_BOOT_TARGET)
	-@echo "Creating $(UEFI_BOOT_FAT)..."
	@dd if=/dev/zero of=$(UEFI_BOOT_FAT) count=1 status=none bs=1M
	@mkfs.fat $(UEFI_BOOT_FAT)
	@mcopy -si $(UEFI_BOOT_FAT) $(UEFI_FAT_FOLDER)/* ::/

$(UEFI_BOOT_TARGET): $(UEFI_ELF_OBJECT)
	@$(OBJCOPY_$(ARCH)) $(UEFI_OBJCOPY_FLAGS) $^ $@

$(UEFI_ELF_OBJECT): $(UEFI_BOOT_OBJECTS)
	@$(LD_$(ARCH)) $(UEFI_LDFLAGS) $^ -o $@ -lefi -lgnuefi

$(UEFI_BUILD_FOLDER)/%.o: $(UEFI_BOOTLOADER_FOLDER)/%.c
	@echo "Compiling $< to $@"
	@$(GCC_$(ARCH)) -c -o $@ $(UEFI_CFLAGS) $<

# BIOS build commands

clean-i386:
	-@echo "Cleaning BIOS bootloader files..."
	-@mkdir -p $(BOOT_IMAGE_FOLDER) $(BIOS_BOOT_IMAGE_FOLDER) $(BIOS_BOOTLOADER_FOLDER) $(BIOS_BUILD_FOLDER)
	-@rm -rf $(BIOS_BOOT_OBJECTS) $(BIOS_BOOT_IMAGE)

bootloader-i386: $(BIOS_BOOT_IMAGE)

$(BIOS_BOOT_IMAGE): $(BIOS_BOOT_OBJECTS)
	-@echo "Creating $(BIOS_BOOT_IMAGE)..."
	@$(LD_$(ARCH)) -T $(BIOS_LINKER) -o $(BIOS_BOOT_IMAGE) $(BIOS_BOOT_OBJECTS) $(LIBGCC_$(ARCH))

$(BIOS_BUILD_FOLDER)/%.o: $(BIOS_BOOTLOADER_FOLDER)/%.c
	@echo "Compiling $< to $@"
	@$(GCC_$(ARCH)) -c $< -o $@ $(BIOS_CFLAGS)

$(BIOS_BUILD_FOLDER)/%.bin: $(BIOS_BOOTLOADER_FOLDER)/%.asm
	@echo "Compiling $< to $@"
	@# NASM requires that the include folder end with a '/' for whatever reason
	@$(NASM) $(BIOS_NASM_FLAGS) $< -o $@ -I$(BIOS_INCLUDE_FOLDER)/