# Stelox
A hobby x86(-64) protected-mode operating system.
It is mostly used as a learning tool and a long-term tinkering project of mine, maybe something will come of it
eventually.

### Building
#### i386
Have the usual suspects installed (an i386 toolchain, `nasm`, `objcopy`, `xorriso`).
Compile with `make i386`, or compile & run with `make run ARCH=i386`.

#### x86_64
Requires the usual: `gcc`, `ld`, `nasm`, `objcopy`, `xorriso`
Compile with `make x86_64`, or compile & run with `make run ARCH=x86_64`

#### Multiplatform
Make sure to have all depedencies for `i386` and `x86_64` targets.
Compile with `make all`, and a multiplatform ISO will be built to `build/images/stelox.iso`. This ISO can be run on 32-bit BIOSor 64-bit UEFI machines. 

### Branches
`#master`: The most stable up-to-date features

`#kernel-dev`: Uses GRUB2 as a stable base for more bleeding-edge kernel development

`#x64-uefi`: Historical development for x86-64 and UEFI support, new UEFI features will be directly added to `#master`
