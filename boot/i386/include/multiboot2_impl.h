#ifndef __MULTIBOOT2_IMPL_H_
#define __MULTIBOOT2_IMPL_H_

#include "types.h"
#include "multiboot2.h"

boot_state = (struct multiboot_boot_state*) (0x6900 - sizeof(struct multiboot_boot_state))

void multiboot2_call_kernel(uintptr_t kernel_address, uintptr_t mbi_struct)
{
    asm volatile(
          "mov %1, %%eax\n\t"
          "mov %2, %%ebx\n\t"
          "jmp *%0\n\t"
        :
        : "g" (kernel_address),
          "g" (MULTIBOOT2_BOOTLOADER_MAGIC),
          "g" (mbi_struct)
        : "eax", "ebx"
    );
}

#endif