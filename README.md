# Stelox
A hobby x86(-64) protected-mode operating system.
It is mostly used as a learning tool and a long-term tinkering project of mine, maybe something will come of it eventually.

### Building
The build system uses GNU `make` and several `Makefiles` for each component of Stelox.

It is not recommended to try to build each component individually--the `Makefile` in the root directory does the heavy lifting for you.

Nevertheless, to build Stelox, run `make [run] ARCH=<name> [CROSS=<path to bin/ + target>]`

An El-Torito ISO will be generated at `build/images/stelox-<arch>.iso`

#### Currently supported architectures:

| Name     | Platform              | Dependencies |
|-----------|----------------------|------|
| `i386`      | 32-bit x86 + BIOS        | `gcc`, `ld`, `objcopy`, `nasm`, `xorriso`    |
| `x86_64`    | 64-bit x86 + UEFI        | `gcc`, `ld`, `objcopy`, `xorriso`, `mkfs.fat`, `mcopy`    |
| `x86-multi` | Both `i386` and `x86_64` | All dependencies for `i386` and `x86_64` and `isolinux`   |

**Note:** Unless compiled on a 32-bit host, `i386` requires a cross-compiler to  be passed
> For example, if your cross-compiler GCC is located at `/opt/cross/bin/i686-elf-gcc`
> pass `CROSS=/opt/cross/bin/i686-elf` with the `make` command.

On `i386`, the bootloader supports (optionally) Multiboot2-complaint ELF32 images. For `x86_64`, it only supports ELF64 images, due to the lack of 64-bit inclusion in the MB2 standard. In the future I hope to refactor the build system so that the built-in bootloader could be easily switched out with GRUB2.

### Branches
`#master`: The most stable up-to-date features

`#kernel-dev`: Uses GRUB2 as a stable base for more bleeding-edge kernel development

`#x64-uefi`: Historical development for x86-64 and UEFI support, new UEFI features will be directly added to `#master`
