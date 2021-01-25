#ifndef __MULTIBOOT2_H_
#define __MULTIBOOT2_H_

#include "types.h"
#include "terminal.h"
#include "multiboot2_tags.h"

/*
*   Returns a pointer to a header if found. Otherwise, returns NULL.
*/
struct multiboot_header *multiboot2_find_header(uintptr_t start_address)
{
    uint32_t *header_ptr = (uint32_t*) start_address;

    // As per section 3.1 of the specification, the header must be 8-byte aligned and within the first 32768 bytes of the image.
    for(uint16_t off = 0; off < MULTIBOOT_SEARCH; off += MULTIBOOT_HEADER_ALIGN)
    {
        if(*(header_ptr + off) == MULTIBOOT2_HEADER_MAGIC)
        {
            return (struct multiboot_header*) (header_ptr + off);
        }
    }

    return NULL;
}

/*
*   Attempts to find a Multiboot2 header starting at the provided address and execute it.
*   If a header is not found, it will jump to start_address.
*/
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
          "mov %1, %%eax\n\t"
          "mov %2, %%ebx\n\t"
          "jmp *%0\n\t"
        :
        : "g" (kernel_address),
          "g" (MULTIBOOT2_BOOTLOADER_MAGIC),
          "g" (header)
        : "eax", "ebx"
    );
}

#endif