ifdef ARCH
bootloader: clean bootloader-$(ARCH)
clean: clean-$(ARCH)
else
kernel:
	@echo "Target $(ARCH) is unsupported!"
clean: clean-x86_64 clean-i386
endif