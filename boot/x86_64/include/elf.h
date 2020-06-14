#ifndef __UEFI_ELF_H_
#define __UEFI_ELF_H_

#include <efi.h>

typedef struct
{
    UINT8         magic;
    const CHAR8   magic_text[3];
    UINT8         arch;
    UINT8         endianess;
    UINT8         header_version;
    UINT8         abi;
    UINT8         padding[8];
    UINT16        type;
    UINT16        instruction_set;
    UINT32        elf_version;
    UINT64        program_entry_position;
    UINT64        program_header_table_position;
    UINT64        section_header_table_position;
    UINT32        flags;
    UINT16        header_length;
    UINT16        program_header_entry_size;
    UINT16        program_header_entry_number;
    UINT16        section_header_entry_size;
    UINT16        section_header_entry_number;
    UINT16        section_names_offset;
} __attribute__((packed)) ElfHeader;

typedef struct
{
    UINT32        type;
    UINT32        flags;
    UINT64        data_offset;
    UINT64        load_address;
    UINT64        undefied;
    UINT64        data_size;
    UINT64        memory_size;
    UINT64        alignment;
} __attribute__((packed)) ElfProgramHeader;

#endif