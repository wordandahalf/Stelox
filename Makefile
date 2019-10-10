BOOTLOADER_FOLDER 		:= boot
KERNEL_FOLDER 			:= kernel

BOOTLOADER_ASM_SOURCES 	:= $(BOOTLOADER_FOLDER)/stage0.asm $(BOOTLOADER_FOLDER)/stage1.asm #$(shell find $(BOOTLOADER_FOLDER) -type f -iname "*.asm")
BOOTLOADER_C_SOURCES	:= $(BOOTLOADER_FOLDER)/stage2.c
BOOTLOADER_OBJECTS 		:= $(subst .asm,.bin,$(BOOTLOADER_ASM_SOURCES))
BOOTLOADER_OBJECTS		+= $(subst .c,.o,$(BOOTLOADER_C_SOURCES))

BOOTLOADER_IMAGE		:= $(BOOTLOADER_FOLDER)/boot.img

KERNEL_SOURCES 			:= $(KERNEL_FOLDER)/kernel.c
KERNEL_OBJECTS 			:= $(subst .c,.o,$(KERNEL_SOURCES))

KERNEL_IMAGE			:= $(KERNEL_FOLDER)/kernel.elf

OS_FLOPPY				:= stelox.img
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
MKISOFS_FLAGS			:= -quiet -R -J -c boot/bootcat -b boot/boot.img -no-emul-boot -boot-load-size 4 -o $(OS_ISO) -V SteloxCD -input-charset utf-8 -graft-points boot/boot.img=$(OS_FLOPPY) kernel/kernle.elf=$(KERNEL_IMAGE)

QEMU					:= qemu-system-i386
QEMU_FLAGS				:= -cdrom $(OS_ISO)

all: clean compile todo run

clean:
	-@rm -r $(BOOTLOADER_OBJECTS) $(KERNEL_OBJECTS) $(BOOTLOADER_IMAGE) $(OS_FLOPPY) $(OS_ISO)
	@echo Done cleaning!

compile: $(BOOTLOADER_OBJECTS) $(KERNEL_OBJECTS)

$(BOOTLOADER_FOLDER)/%.bin:$(BOOTLOADER_FOLDER)/%.asm
	@echo Compiling $<...
	@$(NASM) $(NASM_FLAGS) $< -o $@ -I$(BOOTLOADER_FOLDER)/include/

$(BOOTLOADER_FOLDER)/%.o:$(BOOTLOADER_FOLDER)/%.c
	@echo Compiling $<...
	@$(GCC) -c $< -o $@ -m32 -fno-pie -std=gnu99 -ffreestanding -O2 -Wall -Wextra

$(BOOTLOADER_IMAGE):$(BOOTLOADER_OBJECTS)
	@echo Linking bootloader into $@ using $(BOOTLOADER_LINKER)
	@$(LD) -T $(BOOTLOADER_LINKER) -o $(BOOTLOADER_IMAGE) $(BOOTLOADER_OBJECTS)

$(KERNEL_FOLDER)/%.o:$(KERNEL_FOLDER)/%.c
	@echo Compiling $<...
	@$(GCC) -m32 -fno-pie -c $< -o $@ $(GCC_FLAGS)

$(KERNEL_IMAGE):$(KERNEL_OBJECTS)
	@$(LD) -e main -m elf_i386 $(KERNEL_OBJECTS) -o $(KERNEL_IMAGE)

$(OS_ISO):$(BOOTLOADER_IMAGE) $(KERNEL_IMAGE)
	@$(DD) if=/dev/zero of=$(OS_FLOPPY) $(DD_FLAGS) count=2880

	@$(DD) conv=notrunc if=$(BOOTLOADER_IMAGE) of=$(OS_FLOPPY) $(DD_FLAGS)

	@#For the unacquainted, the $($(KERNEL_IMAGE):%/=) simply reduces the KERNEL_IMAGE variable down to just the file name, without the path

	@$(MKISOFS) $(MKISOFS_FLAGS)

run:$(OS_ISO)
	@DISPLAY=:0 \
	$(QEMU) $(QEMU_FLAGS);

todo:
	-@for file in $(ALLFILES:Makefile=); do fgrep -H -e TODO -e FIXME $$file; done; true