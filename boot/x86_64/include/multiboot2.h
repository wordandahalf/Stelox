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

UINT64 multiboot2_find_and_parse_header(UINT64 start_address)
{
    UINT32 *ptr = (UINT32*) start_address;

    while(*ptr != MULTIBOOT2_MAGIC)
        ptr += 4;

    MultibootHeader *header = (MultibootHeader*) ptr;

    // Actually parse here

    return ((UINT64) header) + header->header_length;
}

#endif