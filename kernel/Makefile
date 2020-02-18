# General folder variables

BASE_PROJECT_FOLDER		?= $(shell dirname $(shell pwd))
BASE_KERNEL_FOLDER		= $(shell pwd)

BASE_BUILD_FOLDER		= $(BASE_PROJECT_FOLDER)/build
BASE_IMAGE_FOLDER		= $(BASE_BUILD_FOLDER)/images

# General command variables

ifdef CROSS
GCC_i386				= $(CROSS)-gcc
LD_i386					= $(CROSS)-ld
OBJCOPY_i386			= $(CROSS)-objcopy
else
GCC_i386				= gcc
LD_i386					= ld
OBJCOPY_i386			= objcopy
endif

GCC_x86_64				= gcc
LD_x86_64				= ld

# Platform-dependent variables

GCC_x86_64_FLAGS		= -Os -fno-pie -g -std=gnu99 -Wall -Wextra -pedantic -Wshadow -Wpointer-arith \
           					-Wcast-align -Wwrite-strings -Wmissing-prototypes -Wmissing-declarations \
            				-Wredundant-decls -Wnested-externs -Winline -Wno-long-long \
        					-Wconversion -Wstrict-prototypes
GCC_i386_FLAGS			= -m32 -Os -fno-pie -g -std=gnu99 -Wall -Wextra -pedantic -Wshadow -Wpointer-arith \
           					-Wcast-align -Wwrite-strings -Wmissing-prototypes -Wmissing-declarations \
            				-Wredundant-decls -Wnested-externs -Winline -Wno-long-long \
        					-Wconversion -Wstrict-prototypes

# Kernel variables

KERNEL_BUILD_FOLDER		= $(BASE_BUILD_FOLDER)/$(ARCH)/kernel

KERNEL_SOURCES			= $(BASE_KERNEL_FOLDER)/entry.asm $(BASE_KERNEL_FOLDER)/kernel.c

KERNEL_OBJECTS			= $(KERNEL_SOURCES:.c=.o)
KERNEL_OBJECTS			:= $(KERNEL_OBJECTS:.asm=.bin)
KERNEL_OBJECTS			:= $(subst $(BASE_KERNEL_FOLDER),$(KERNEL_BUILD_FOLDER),$(KERNEL_OBJECTS))

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
	-@mkdir -p $(KERNEL_BUILD_FOLDER)
	@rm -rf $(KERNEL_OBJECTS) $(KERNEL_ELF_IMAGE)

kernel-x86_64: $(KERNEL_OBJECTS)
	@echo "Creating $(KERNEL_ELF_IMAGE)" 
	@$(LD) -e main -m elf_x86_64 -o $(KERNEL_ELF_IMAGE) $(KERNEL_OBJECTS)

kernel-i386: $(KERNEL_OBJECTS)
	@echo "Creating $(KERNEL_ELF_IMAGE)" 
	@$(GCC_$(ARCH)) -T link.ld -o $(KERNEL_ELF_IMAGE) -ffreestanding -O2 -nostdlib $(KERNEL_OBJECTS) -lgcc
	@#$(LD) -T link.ld -m elf_i386 -o $(KERNEL_ELF_IMAGE) $(KERNEL_OBJECTS)

$(KERNEL_BUILD_FOLDER)/%.bin: $(BASE_KERNEL_FOLDER)/%.asm
	@nasm -felf32 $< -o $@

$(KERNEL_BUILD_FOLDER)/%.o: $(BASE_KERNEL_FOLDER)/%.c
	@echo "Compiling $< to $@"
	@$(GCC_$(ARCH)) -c $< -o $@ $(GCC_$(ARCH)_FLAGS) 