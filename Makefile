CC		:= clang
LD		:= lld-link-6.0
EMU		:= qemu-system-x86_64
 
CFLAGS		:= -ffreestanding -flto -fno-stack-protector -fshort-wchar -Ikernel/include -MMD -mno-red-zone -std=c11 -target x86_64-pc-win32-coff -Wall -Wextra
LDFLAGS		:= -subsystem:efi_application -nodefaultlib -dll
EMUFLAGS	:= -drive if=pflash,format=raw,file=bin/OVMF.fd -cdrom efi.iso -net none -serial stdio
 
OBJ			:= kernel/kernel.o
KERNEL		:= fatbase/efi/boot/bootx64.efi
 
OVMF_URL	:= https://dl.bintray.com/no92/vineyard-binary/OVMF.fd
OVMF_BIN	:= OVMF.fd
OVMF		:= bin/$(OVMF_BIN)
 
$(KERNEL): $(OBJ)
	mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -entry:efi_main $< -out:$@
 
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@
 
-include $(OBJ:.o=.d)
 
test: $(KERNEL) $(OVMF)
	dd if=/dev/zero of=efi.fat count=1 bs=1M
	mkfs.fat efi.fat
	mcopy -si efi.fat fatbase/* ::/

	xorriso -as mkisofs -R -f -e efi.fat -no-emul-boot -o efi.iso iso

	$(EMU) $(EMUFLAGS)
 
$(OVMF):
	mkdir -p bin
	wget $(OVMF_URL) -O $(OVMF) -qq
 
clean:
	rm -f $(KERNEL)
	rm -f $(OBJ) $(OBJ:.o=.d)
	rm -f efi.fat
	rm -f efi.iso
 
.PHONY: test clean