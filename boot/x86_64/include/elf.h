#ifndef __UEFI_ELF_H_
#define __UEFI_ELF_H_

#include <efi.h>

typedef struct
{
    UINT8         magic;
    const char    magic_text[3];
    UINT8         arch;
    UINT8         endianess;
    UINT8         header_version;
    UINT8         abi;
    UINT8         padding[8];
    UINT16        type;
    UINT16        instruction_set;
    UINT32        elf_version;
    UINT32        program_entry_position;
    UINT32        program_header_table_position;
    UINT32        section_header_table_position;
    UINT32        flags;
    UINT16        header_length;
    UINT16        program_header_entry_size;
    UINT16        program_header_entry_number;
    UINT16        section_header_entry_size;
    UINT16        section_header_entry_number;
    UINT16        section_names_offset;
} ElfHeader;

typedef struct
{
    UINT32        type;
    UINT32        data_offset;
    UINT32        load_address;
    UINT32        undefied;
    UINT32        data_size;
    UINT32        memory_size;
    UINT32        flags;
    UINT32        alignment;
} ElfProgramHeader;

#endif