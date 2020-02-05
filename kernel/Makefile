# General folder variables

BASE_PROJECT_FOLDER		?= $(shell dirname $(shell pwd))
BASE_KERNEL_FOLDER		= $(shell pwd)

BASE_BUILD_FOLDER		= $(BASE_PROJECT_FOLDER)/build
BASE_IMAGE_FOLDER		= $(BASE_BUILD_FOLDER)/images

# General command variables

GCC_i386				= gcc
GCC_					= $(GCC_i386)
LD						= ld

# Platform-dependent variables

GCC_x86_64_FLAGS		= -Os -fno-pie -g -std=gnu99 -Wall -Wextra -pedantic -Wshadow -Wpointer-arith \
           					-Wcast-align -Wwrite-strings -Wmissing-prototypes -Wmissing-declarations \
            				-Wredundant-decls -Wnested-externs -Winline -Wno-long-long \
        					-Wconversion -Wstrict-prototypes
GCC_i386_FLAGS			= -m32 -Os -fno-pie -g -std=gnu99 -Wall -Wextra -pedantic -Wshadow -Wpointer-arith \
           					-Wcast-align -Wwrite-strings -Wmissing-prototypes -Wmissing-declarations \
            				-Wredundant-decls -Wnested-externs -Winline -Wno-long-long \
        					-Wconversion -Wstrict-prototypes
GCC__FLAGS				:= $(GCC_i386_FLAGS)

# Kernel variables

KERNEL_BUILD_FOLDER		= $(BASE_BUILD_FOLDER)/$(ARCH)/kernel

KERNEL_SOURCES			= $(BASE_KERNEL_FOLDER)/kernel.c

KERNEL_OBJECTS			= $(KERNEL_SOURCES:.c=.o)
KERNEL_OBJECTS			:= $(subst $(BASE_KERNEL_FOLDER),$(KERNEL_BUILD_FOLDER),$(KERNEL_OBJECTS))

KERNEL_ELF_IMAGE		= $(BASE_IMAGE_FOLDER)/kernel.elf

ifdef ARCH
kernel: clean kernel-$(ARCH)
else
kernel: clean kernel-i386
endif

clean:
	-@mkdir -p $(KERNEL_BUILD_FOLDER)
	@rm -rf $(KERNEL_OBJECTS) $(KERNEL_ELF_IMAGE)

kernel-x86_64: $(KERNEL_OBJECTS)
	$(LD) -e main -m elf_x86_64 $(KERNEL_OBJECTS) -o $(KERNEL_ELF_IMAGE)

kernel-i386: $(KERNEL_OBJECTS)
	$(LD) -e main -m elf_i386 $(KERNEL_OBJECTS) -o $(KERNEL_ELF_IMAGE)

$(KERNEL_BUILD_FOLDER)/%.o: $(BASE_KERNEL_FOLDER)/%.c
	$(GCC_$(ARCH)) -c $< -o $@ $(GCC_$(ARCH)_FLAGS) 