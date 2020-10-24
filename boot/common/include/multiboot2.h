#ifndef __MULTIBOOT2_H_
#define __MULTIBOOT2_H_

#include "terminal.h"

#define MULTIBOOT2_MAGIC 0xE85250D6

typedef struct
{
    uint16_t                type;
    uint16_t                flags;
    uint32_t                size;
    uint32_t                data[];
} __attribute__((packed)) MultibootHeaderTag;

typedef struct
{
    uint32_t                magic;
    uint32_t                arch;
    uint32_t                header_length;
    uint32_t                checksum;
    MultibootHeaderTag      tags[];
} __attribute__((packed)) MultibootHeader;

MultibootHeader *multiboot2_parse_header(uintptr_t start_address)
{
    uint32_t *header_ptr = (uint32_t*) start_address;

    // As per section 3.1 of the specification, the header must be 8-byte aligned and within the first 32768 bytes of the image.
    for(uint16_t off = 0; off < 0x8000; off += 8)
    {
        if(*(header_ptr + off) == MULTIBOOT2_MAGIC)
        {
            return (MultibootHeader*) (header_ptr + off);
        }
    }

    return NULL;
}

void multiboot2_execute_image(uintptr_t start_address)
{
    MultibootHeader *header = (MultibootHeader*) multiboot2_parse_header(start_address);

    if(header)
    {
        log("Found Multiboot 2 header!", INFO);

        uintptr_t address = start_address + header->header_length;
        log("Jumping to kernel at 0x%x!", INFO, address);

        void (*kernel_main)(void) = (void*)address;
        kernel_main();
    }
    else
    {
        log("Did not find Multiboot 2 header, jumping to kernel at 0x%x!", INFO, start_address);
        void (*kernel_main)(void) = (void*)start_address;
        kernel_main();
    }
}

#endif