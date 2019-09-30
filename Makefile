BOOTLOADER_FOLDER 		:= boot
KERNEL_FOLDER 			:= kernel
ISO_FOLDER				:= iso

BOOTLOADER_ASM_SOURCES 	:= $(BOOTLOADER_FOLDER)/stage0.asm $(BOOTLOADER_FOLDER)/stage1.asm #$(shell find $(BOOTLOADER_FOLDER) -type f -iname "*.asm")
BOOTLOADER_C_SOURCES	:= $(BOOTLOADER_FOLDER)/stage2.c
BOOTLOADER_OBJECTS 		:= $(subst .asm,.bin,$(BOOTLOADER_ASM_SOURCES))
BOOTLOADER_OBJECTS		+= $(subst .c,.o,$(BOOTLOADER_C_SOURCES))

BOOTLOADER_IMAGE		:= $(BOOTLOADER_FOLDER)/boot.img

KERNEL_SOURCES 			:= $(KERNEL_FOLDER)/kernel.c
KERNEL_OBJECTS 			:= $(subst .c,.o,$(KERNEL_SOURCES))

KERNEL_IMAGE			:= $(KERNEL_FOLDER)/kernel.elf

OS_IMAGE				:= stelox.img
OS_FLOPPY				:= stelox.flp
OS_ISO					:= stelox.iso

BOOTLOADER_LINKER		:= $(BOOTLOADER_FOLDER)/linker.ld

NASM					:= nasm
NASM_FLAGS				:= -f elf32

DD						:= dd
DD_FLAGS				:= status=none bs=512

CP						:= cp

GCC						:= gcc
GCC_FLAGS				:= -m32 -Os -g -std=gnu99 -Wall -Wextra -pedantic -Wshadow -Wpointer-arith \
           				   -Wcast-align -Wwrite-strings -Wmissing-prototypes -Wmissing-declarations \
            			   -Wredundant-decls -Wnested-externs -Winline -Wno-long-long \
        				   -Wconversion -Wstrict-prototypes

LD						:= ld
LD_FLAGS				:= -T boot/link.ld -o $@ boot/boot.o boot/cstuff.o

MKISOFS					:= mkisofs
MKISOFS_FLAGS			:= -quiet -input-charset utf-8 -o $(OS_ISO) -V Stelox -b $(OS_FLOPPY) $(ISO_FOLDER)

QEMU					:= qemu-system-i386
QEMU_FLAGS				:= -cdrom $(OS_ISO)

all: clean compile todo run

clean:
	-@rm -r $(BOOTLOADER_OBJECTS) $(KERNEL_OBJECTS) $(BOOTLOADER_IMAGE) $(OS_IMAGE) $(OS_FLOPPY) $(OS_ISO) $(ISO_FOLDER)/*
	-@mkdir -p $(ISO_FOLDER) > /dev/null 2>&1
	@echo Done cleaning!

compile: $(BOOTLOADER_OBJECTS) $(KERNEL_OBJECTS)

$(BOOTLOADER_FOLDER)/%.bin:$(BOOTLOADER_FOLDER)/%.asm
	@echo Compiling $<...
	@$(NASM) $(NASM_FLAGS) $< -o $@ -I$(BOOTLOADER_FOLDER)/include/

$(BOOTLOADER_FOLDER)/%.o:$(BOOTLOADER_FOLDER)/%.c
	@echo Compiling $<...
	@$(GCC) -c $< -o $@ -m32 -fno-pie -std=gnu99 -ffreestanding -O2 -Wall -Wextra

$(BOOTLOADER_IMAGE):$(BOOTLOADER_OBJECTS)
	@$(foreach file,$(BOOTLOADER_OBJECTS),dd status=none bs=512 if=$(file) >> $(BOOTLOADER_IMAGE);)

$(KERNEL_FOLDER)/%.o:$(KERNEL_FOLDER)/%.c
	@echo Compiling $<...
	@$(GCC) -m32 -fno-pie -c $< -o $@ $(GCC_FLAGS)

$(KERNEL_IMAGE):$(KERNEL_OBJECTS)
	@$(LD) -e main -m elf_i386 $(KERNEL_OBJECTS) -o $(KERNEL_IMAGE)

$(OS_IMAGE):$(BOOTLOADER_IMAGE) $(KERNEL_IMAGE)
	@$(DD) if=/dev/zero of=$(OS_FLOPPY) $(DD_FLAGS) count=2880

	@echo Linking into $(OS_IMAGE) using $(BOOTLOADER_LINKER)
	@$(LD) -T $(BOOTLOADER_LINKER) -o $@ $(BOOTLOADER_OBJECTS)
	@$(DD) conv=notrunc if=$(OS_IMAGE) of=$(OS_FLOPPY) $(DD_FLAGS)

	@$(CP) $(OS_FLOPPY) $(ISO_FOLDER)/$(OS_FLOPPY)
	@#For the unacquainted, the $($(KERNEL_IMAGE):%/=) simply reduces the KERNEL_IMAGE variable down to just the file name, without the path
	@$(CP) $(KERNEL_IMAGE) $(ISO_FOLDER)/$($(KERNEL_IMAGE):%/=)
	@$(MKISOFS) $(MKISOFS_FLAGS)

run:$(OS_IMAGE)
	@DISPLAY=:0 \
	$(QEMU) $(QEMU_FLAGS);

todo:
	-@for file in $(ALLFILES:Makefile=); do fgrep -H -e TODO -e FIXME $$file; done; true