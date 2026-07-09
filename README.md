# Stelox
Stelox is a hobbyist operating system and bootloader targeting 64-bit x86 systems, though it is structured to be platform agnostic.

### Structure
| Path | Description |
| ---- | ----------- |
| `lib/` | general purpose data structures and algorithms which do not depend on the bootloader or kernel |
| `lib/platform/` | platform-specific data structures, "" |
| `src/boot/` | source of the UEFI, Multiboot 2-compliant bootloader |
| `src/kernel/` | source code for the Stelox kernel |
| `src/hal/` | platform-specific kernel initialization code |
|
