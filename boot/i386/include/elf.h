#ifndef __ELF_H_
#define __ELF_H_

typedef struct
{
    uint8_t         magic;
    const char      magic_text[3];
    uint8_t         arch;
    uint8_t         endianess;
    uint8_t         header_version;
    uint8_t         abi;
    uint8_t         padding[8];
    uint16_t        type;
    uint16_t        instruction_set;
    uint32_t        elf_version;
    uint32_t        program_entry_position;
    uint32_t        program_header_table_position;
    uint32_t        section_header_table_position;
    uint32_t        flags;
    uint16_t        program_header_entry_size;
    uint16_t        program_header_entry_number;
    uint16_t        section_header_entry_size;
    uint16_t        section_header_entry_number;
    uint16_t        section_names_offset;
} ElfHeader;

#endif