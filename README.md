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

### Bootloader
The bootloader aims to be able to load (optionally) Multiboot 2-compliant ELF images.
On `i386`, the bootloader looks for a ELF32 image at `KERNEL/KERNEL32.ELF`. Likewise, on `x86_64`, it looks for a ELF64 image at `KERNEL/KERNEL64.ELF`.
It loads the image into memory and then looks for a valid Multiboot2 header. If one is not found, it will simply transfer control to the freshly-loaded OS.

### Branches
`#master`: The most stable up-to-date features

`#kernel-dev`: Uses GRUB2 as a stable base for more bleeding-edge kernel development

`#x64-uefi`: Historical development for x86-64 and UEFI support, new UEFI features will be directly added to `#master`
