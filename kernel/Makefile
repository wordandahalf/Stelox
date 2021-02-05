# General folder variables

BASE_PROJECT_FOLDER		?= $(shell dirname $(shell pwd))
BASE_KERNEL_FOLDER		= $(shell pwd)
KERNEL_COMMON_FOLDER	= $(BASE_KERNEL_FOLDER)/common
KERNEL_$(ARCH)_FOLDER	= $(BASE_KERNEL_FOLDER)/$(ARCH)

BASE_BUILD_FOLDER		= $(BASE_PROJECT_FOLDER)/build
BASE_IMAGE_FOLDER		= $(BASE_BUILD_FOLDER)/images

# General command variables

ifdef CROSS
GCC_i386				= $(CROSS)-g++
OBJCOPY_i386			= $(CROSS)-objcopy
else
GCC_i386				= g++
OBJCOPY_i386			= objcopy
endif

GCC_x86_64				= g++

NASM_x86_64_FLAGS		= -felf64
NASM_i386_FLAGS			= -felf32

# Platform-dependent variables

GCC_x86_64_FLAGS		= -ffreestanding -mcmodel=large -mno-red-zone -mno-mmx -mno-sse -mno-sse2 -O2 -Wall -Wextra -fno-exceptions -fno-rtti -fno-pic -fno-pie
GCC_i386_FLAGS			= -ffreestanding -O2 -Wall -Wextra -fno-exceptions -fno-rtti

LINK_x86_64_FLAGS		= -O2 -lgcc -nostdlib -z max-page-size=0x1000
LINK_i386_FLAGS			= -O2 -lgcc -nostdlib

# Kernel variables

KERNEL_$(ARCH)_BUILD_FOLDER	= $(BASE_BUILD_FOLDER)/$(ARCH)/kernel
KERNEL_COMMON_BUILD_FOLDER	= $(BASE_BUILD_FOLDER)/kernel

KERNEL_LINKER			= $(KERNEL_$(ARCH)_FOLDER)/linker.ld

KERNEL_$(ARCH)_SOURCES	= $(KERNEL_$(ARCH)_FOLDER)/entry.asm
KERNEL_COMMON_SOURCES	= $(KERNEL_COMMON_FOLDER)/main.cpp

# Replace file extensions
KERNEL_$(ARCH)_OBJECTS	:= $(KERNEL_$(ARCH)_SOURCES:.asm=.bin)
KERNEL_$(ARCH)_OBJECTS	:= $(KERNEL_$(ARCH)_OBJECTS:.cpp=.o)

# Replace folder
KERNEL_$(ARCH)_OBJECTS	:= $(subst $(KERNEL_$(ARCH)_FOLDER),$(KERNEL_$(ARCH)_BUILD_FOLDER),$(KERNEL_$(ARCH)_OBJECTS))

# Replace file extensions
KERNEL_COMMON_OBJECTS	:= $(KERNEL_COMMON_SOURCES:.cpp=.o)

# Replace folder
KERNEL_COMMON_OBJECTS	:= $(subst $(KERNEL_COMMON_FOLDER),$(KERNEL_COMMON_BUILD_FOLDER),$(KERNEL_COMMON_OBJECTS))

KERNEL_OBJECTS			= $(KERNEL_$(ARCH)_OBJECTS) $(KERNEL_COMMON_OBJECTS)

KERNEL_ELF_IMAGE		= $(BASE_IMAGE_FOLDER)/kernel-$(ARCH).elf

ifdef ARCH
ifneq ($(ARCH),$(shell arch))
ifdef CROSS
kernel: clean kernel-$(ARCH)
	@#There needs to be a tab here for whatever contrived reason, otherwise it executes some whacky command
else
kernel:
	$(error A cross compiler is required for target '$(ARCH)')
endif
else
kernel: clean kernel-$(ARCH)
	@#There needs to be a tab here for whatever contrived reason, otherwise it executes some whacky command
endif
else
kernel:
	$(error No target architecture was passed)
endif

clean:
	@echo Cleaning kernel files...
	-@mkdir -p $(KERNEL_BUILD_FOLDER) $(KERNEL_$(ARCH)_BUILD_FOLDER)
	@rm -rf $(KERNEL_OBJECTS) $(KERNEL_ELF_IMAGE)

kernel-$(ARCH): $(KERNEL_OBJECTS)
	@echo "Creating $(KERNEL_ELF_IMAGE)" 
	$(GCC_$(ARCH)) -ffreestanding -T $(KERNEL_LINKER) $(KERNEL_OBJECTS) -o $(KERNEL_ELF_IMAGE) $(LINK_$(ARCH)_FLAGS)

$(KERNEL_$(ARCH)_BUILD_FOLDER)/%.bin: $(KERNEL_$(ARCH)_FOLDER)/%.asm
	nasm $(NASM_$(ARCH)_FLAGS) $< -o $@

$(KERNEL_COMMON_BUILD_FOLDER)/%.o: $(KERNEL_COMMON_FOLDER)/%.cpp
	@echo "Compiling $< to $@"
	$(GCC_$(ARCH)) -c $< -o $@ $(GCC_$(ARCH)_FLAGS) 