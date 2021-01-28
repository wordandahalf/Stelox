#ifndef __MULTIBOOT2_IMPL_H_
#define __MULTIBOOT2_IMPL_H_

#include "types.h"
#include "multiboot2.h"

void multiboot2_execute_image(uintptr_t start_address)
{
    struct multiboot_header *header = (struct multiboot_header*) multiboot2_find_header(start_address);
    uintptr_t kernel_address = start_address;

    if(header)
    {
        log("Found Multiboot 2 header!", INFO);
        kernel_address += header->header_length;
    }
    else
    {
        log("Did not find Multiboot 2 header!", INFO);
    }

    log("Jumping to kernel at 0x%x!", INFO, kernel_address);

    asm volatile(
          "mov %1, %%rax\n\t"
          "mov %2, %%rbx\n\t"
          "jmp *%0\n\t"
        :
        : "g" (kernel_address),
          "g" (MULTIBOOT2_BOOTLOADER_MAGIC),
          "g" (header)
        : "rax", "rbx"
    );
}

#endif