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
    uint16_t        header_length;
    uint16_t        program_header_entry_size;
    uint16_t        program_header_entry_number;
    uint16_t        section_header_entry_size;
    uint16_t        section_header_entry_number;
    uint16_t        section_names_offset;
} Elf32Header;

typedef struct
{
    uint32_t        type;
    uint32_t        data_offset;
    uint32_t        load_address;
    uint32_t        undefied;
    uint32_t        data_size;
    uint32_t        memory_size;
    uint32_t        flags;
    uint32_t        alignment;
} Elf32ProgramHeader;

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
    uint64_t        program_entry_position;
    uint64_t        program_header_table_position;
    uint64_t        section_header_table_position;
    uint32_t        flags;
    uint16_t        header_length;
    uint16_t        program_header_entry_size;
    uint16_t        program_header_entry_number;
    uint16_t        section_header_entry_size;
    uint16_t        section_header_entry_number;
    uint16_t        section_names_offset;
} __attribute__((packed)) Elf64Header;

typedef struct
{
    uint32_t        type;
    uint32_t        flags;
    uint64_t        data_offset;
    uint64_t        load_address;
    uint64_t        undefied;
    uint64_t        data_size;
    uint64_t        memory_size;
    uint64_t        alignment;
} __attribute__((packed)) Elf64ProgramHeader;

#endif