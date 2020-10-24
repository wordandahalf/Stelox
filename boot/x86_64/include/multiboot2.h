#ifndef __UEFI_MULTIBOOT2_H_
#define __UEFI_MULTIBOOT2_H_

#include <efibind.h>

#define MULTIBOOT2_MAGIC 0xE85250D6

typedef struct
{
    UINT16                  type;
    UINT16                  flags;
    UINT32                  size;
    UINT32                  data[];
} __attribute__((packed)) MultibootHeaderTag;

typedef struct
{
    UINT32                  magic;
    UINT32                  arch;
    UINT32                  header_length;
    UINT32                  checksum;
    MultibootHeaderTag      tags[];
} __attribute__((packed)) MultibootHeader;

MultibootHeader *multiboot2_parse_header(UINT64 start_address)
{
    UINT32 *header_ptr = (UINT32*) start_address;

    // As per 3.1 of the specification, the header must be 8-byte aligned and within the first 32768 bytes of the image.
    for(UINT16 off = 0; off < 0x8000; off += 8)
    {
        if(*(header_ptr + off) == MULTIBOOT2_MAGIC)
        {
            return (MultibootHeader*) (header_ptr + off);
        }
    }

    return NULL;
}

void multiboot2_execute_image(UINT64 start_address)
{
    MultibootHeader *header = (MultibootHeader*) multiboot2_parse_header(start_address);

    if(header)
    {
        Print(L"Found Multiboot 2 header!\r\n");
    }
}

#endif