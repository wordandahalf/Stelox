# Stelox
A hobby x86 protected-mode operating system.
It is mostly used as a learning tool and a long-term tinkering project of mine, maybe something will come of it
eventually.

### Building
Have the usual build tools installed (`gcc`, `ld`, `make`, `binutils`, `nasm`) and `qemu-system-x86`.
When compiling for x64 is supported, you will need `qemu-system-x64` and `gnu-efi`.

Right now, only x86 is supported, so just run `make run`.

### Branches
`#master`: The most stable up-to-date features

`#kernel-dev`: Uses GRUB2 as a stable base for more bleeding-edge kernel development

`#x64-uefi`: Development for x86-64 and UEFI support
