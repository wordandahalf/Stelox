clean:
	@make -C boot/ -f Makefile -s clean
	@make -C kernel/ -f Makefile -s clean

x86_64:
	@make -C boot/ -f Makefile -s bootloader ARCH=x86_64
	@make -C kernel/ -f Makefile -s kernel ARCH=x86_64

i386:
	@make -C boot/ -f Makefile -s bootloader ARCH=i386
	@make -C kernel/ -f Makefile -s kernel ARCH=i386