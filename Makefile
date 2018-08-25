BOOTLOADER_FOLDER 		:= boot
KERNEL_FOLDER 			:= kernel

BOOTLOADER_SOURCES 		:= $(shell find $(BOOTLOADER_FOLDER) -type f -iname "*.asm")
BOOTLOADER_OBJECTS 		:= $(subst .asm,.bin,$(BOOTLOADER_SOURCES))

BOOTLOADER_IMAGE		:= $(BOOTLOADER_FOLDER)/boot.img

KERNEL_SOURCES 			:= $(shell find . -type f -iname "*.c")
KERNEL_OBJECTS 			:= $(foreach x,$(basename $(C_SOURCES)),$(x).o)

OS_IMAGE				:= stelox.img

ALLFILES				:= $(BOOTLOADER_SOURCES) $(KERNEL_SOURCES)

NASM					:= nasm
NASM_FLAGS				:= -f bin

DD						:= dd
DD_FLAGS				:= bs=512

GCC						:= GCC
GCC_FLAGS				:= -g -std=gnu99 -Wall -Wextra -pedantic -Wshadow -Wpointer-arith \
           				   -Wcast-align -Wwrite-strings -Wmissing-prototypes -Wmissing-declarations \
            			   -Wredundant-decls -Wnested-externs -Winline -Wno-long-long \
        				   -Wconversion -Wstrict-prototypes

QEMU					:= qemu-system-i386
QEMU_FLAGS				:= -drive format=raw,file=$(OS_IMAGE),index=0,if=floppy

all: clean compile todo run

clean:
	-rm -r $(BOOTLOADER_OBJECTS) $(KERNEL_OBJECTS) $(BOOTLOADER_IMAGE) $(OS_IMAGE)

compile: $(BOOTLOADER_OBJECTS) $(KERNEL_OBJECTS)

%.bin:%.asm
	@$(NASM) $(NASM_FLAGS) $< -o $@ -I$(BOOTLOADER_FOLDER)/include/

%.o:%.c
	@$(GCC) $(GCC_FLAGS) -o $@ $<

$(BOOTLOADER_IMAGE):$(BOOTLOADER_OBJECTS)
	@$(foreach file,$(BOOTLOADER_OBJECTS),dd bs=512 if=$(file) >> $(BOOTLOADER_IMAGE);)

$(KERNEL_IMAGE):$(KERNEL_OBJECTS)

$(OS_IMAGE):$(BOOTLOADER_IMAGE) $(KERNEL_IMAGE)
	@$(DD) $(DD_FLAGS) if=$(BOOTLOADER_IMAGE) >> $(OS_IMAGE)

run:$(OS_IMAGE)
	@DISPLAY=:0 \
	$(QEMU) $(QEMU_FLAGS);

todo:
	-@for file in $(ALLFILES:Makefile=); do fgrep -H -e TODO -e FIXME $$file; done; true