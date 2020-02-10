# Stelox
A hobby x86(-64) protected-mode operating system.
It is mostly used as a learning tool and a long-term tinkering project of mine, maybe something will come of it
eventually.

### Building
The build system uses GNU `make` and several `Makefiles` for each component of Stelox.

It is not recommended to try to build each component individually--the `Makefile` in the root directory does the heavy lifting for you.

Nevertheless, to build Stelox, run `make [run] ARCH=<architecture> [CROSS=<path to bin/ + target>`. An El-Torito ISO will be generated at `build/images/stelox.iso`

Current supported architectures: `i386`, `x86_64`, and `x86-multi`.

`i386` supports 32-bit x86 CPUs with a BIOS.

*Requires `gcc`, `ld`, `objcopy`, `nasm`, and `xorriso`.*

**Note: ** Unless compiled on a 32-bit host, a cross-compiler must be passed
> If your cross-compiler GCC is located at `/opt/cross/bin/i686-elf-gcc`
> pass `CROSS=/opt/cross/bin/i686-elf` with the `make` command.

`x86_64` supports 64-bit x86 CPUs with a UEFI.

*Requires `gcc`, `ld`, `objcopy`, `xorriso`, `mkfs.fat`, and `mcopy`.*

`x86-multi` supports both `i386` and `x86_64` platforms.

*Requires dependencies for `i386` and `x86_64` platforms and a 32-bit cross-compiler`

### Branches
`#master`: The most stable up-to-date features

`#kernel-dev`: Uses GRUB2 as a stable base for more bleeding-edge kernel development

`#x64-uefi`: Historical development for x86-64 and UEFI support, new UEFI features will be directly added to `#master`
