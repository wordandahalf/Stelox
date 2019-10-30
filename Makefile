ARCH            = $(shell uname -m | sed s,i[3456789]86,ia32,)

UEFI_IMAGE		= boot/bootx64.so

OBJS            = boot/efi.o
TARGET          = fatbase/efi/boot/bootx64.efi

EFIINC          = utils/gnuefi/include
EFIINCS         = -I$(EFIINC) -I$(EFIINC)/$(ARCH) -I$(EFIINC)/protocol
LIB             = utils/gnuefi/lib
EFILIB          = utils/gnuefi/efi-lib
EFI_CRT_OBJS    = $(EFILIB)/crt0-efi-$(ARCH).o
EFI_LDS         = $(EFILIB)/elf_$(ARCH)_efi.lds

CFLAGS          = $(EFIINCS) -fno-stack-protector -fpic \
		  -fshort-wchar -mno-red-zone -Wall 
ifeq ($(ARCH),x86_64)
  CFLAGS += -DEFI_FUNCTION_WRAPPER
endif

LDFLAGS         = -nostdlib -znocombreloc -T $(EFI_LDS) -shared \
		  -Bsymbolic -L $(EFILIB) -L $(LIB) $(EFI_CRT_OBJS)

OVMF_URL	:= https://dl.bintray.com/no92/vineyard-binary/OVMF.fd
OVMF_BIN	:= OVMF.fd
OVMF		:= utils/OVMF/$(OVMF_BIN)

EMU		:= qemu-system-x86_64
EMUFLAGS	:= -drive if=pflash,format=raw,file=$(OVMF) -cdrom efi.iso -net none -serial stdio

all: cdrom

test: cdrom
	$(EMU) $(EMUFLAGS)

cdrom: $(TARGET) $(OVMF)
	dd if=/dev/zero of=efi.fat count=1 bs=1M
	mkfs.fat efi.fat
	mcopy -si efi.fat fatbase/* ::/
	cp efi.fat iso/

	xorriso -as mkisofs -R -f -e efi.fat -no-emul-boot -o efi.iso iso

%.o: %.c
	gcc -c -o $@ $(CFLAGS) $<

$(UEFI_IMAGE): $(OBJS)
	ld $(LDFLAGS) $(OBJS) -o $@ -lefi -lgnuefi

$(TARGET): $(UEFI_IMAGE)
	objcopy -j .text -j .sdata -j .data -j .dynamic \
		-j .dynsym  -j .rel -j .rela -j .reloc \
		--target=efi-app-$(ARCH) $^ $@

$(OVMF):
	mkdir -p bin
	wget $(OVMF_URL) -O $(OVMF) -qq
