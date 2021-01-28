#include <stdarg.h>

#include "types.h"
#include "io.h"
#include "memory_map.h"

#include "terminal_impl.h"

#include "ata.h"
#include "iso9660_impl.h"
#include "elf.h"
#include "multiboot2_impl.h"

void read_kernel(AtaDevice *device)
{
    // The PVD is always located at sector 16 (0x10) in the image
    VolumeDescriptor *descriptor = read_volume_descriptor(device, 0x10);

    if(!descriptor)
    {
        log("Couldn't find volume descriptor!", ERROR);
        goto error;
    }

    // PVDs have a type of 1
    if(descriptor->type != 0x1)
    {
        log("Couldn't find primary volume descriptor!", ERROR);
        goto error;
    }

    PrimaryVolumeDescriptor *pvd = (PrimaryVolumeDescriptor*)descriptor;
    DirectoryRecord *directory_record = load_root_directory(pvd, device);

    uintptr_t file = load_file("KERNEL/KERNEL32.ELF", directory_record, device);

    // file will be a null pointer if it was unable to be found
    if(!file)
    {
        log("Couldn't find kernel!", ERROR);
        goto error;
    }

    Elf32Header *elf_header = (Elf32Header*)file;

    if(!strcmp(elf_header->magic_text, "ELF", 3))
    {
        log("Kernel is not a valid ELF image!", ERROR);
        goto error;
    }

    log("Loaded kernel ELF at 0x%x", INFO, file);

    Elf32ProgramHeader *header_table = (Elf32ProgramHeader*)((uintptr_t) elf_header + elf_header->program_header_table_position);

    Elf32ProgramHeader text_header = header_table[0];
    Elf32ProgramHeader data_header = header_table[1];

    if(text_header.type == 0x1 && text_header.flags == 0b101)
    {
        // Load the text header!
        uintptr_t src = ((uintptr_t) elf_header) + text_header.data_offset;
        memcpy((void *restrict)text_header.load_address, (const void *restrict)src, text_header.data_size);
    }
    else
    {
        
    }
    
    if(data_header.type == 0x1 && data_header.flags == 0b110)
    {
        // Load the data header!
        uintptr_t src = ((uintptr_t) elf_header) + data_header.data_offset;
        memcpy((void *restrict)data_header.load_address, (const void *restrict)src, data_header.data_size);
    }
    else
    {

    }

    // Execute the image
    multiboot2_execute_image(text_header.load_address);

    log("Returned from kernel!", ERROR);
    for(;;);

    error:
    log("Try rebooting or recreating your media...", ERROR);
}

void loader_main(void)
{
    terminal_init();

    log("Stelox v0.0.1 booted!", INFO);

    memory_map_init();
    uint64_t free_memory = 0;
    uint64_t reserved_memory = 0;
    log("Received memory map with %d entries", INFO, memory_map.length);
    for(uint8_t i = 0; i < memory_map.length; i++)
    {
        printf("base_address=0x%X, length=0x%X, type=0x%X\n", memory_map.entries[i].base_address, memory_map.entries[i].length, memory_map.entries[i].type);
        switch(memory_map.entries[i].type)
        {
            case 0x1:
                free_memory += memory_map.entries[i].length;
                break;
            case 0x2:
                reserved_memory += memory_map.entries[i].length;
                break;
        }
    }
    printf("free memory: 0x%X, %dMB\n", free_memory, free_memory / (1024 * 1024));
    printf("reserved memory: 0x%X, %dKB\n", reserved_memory, reserved_memory / 1024);

    AtaDevice *device = ata_detect_devices(ATA_PATAPI_DRIVE);
    log("Found a %uKB CD-ROM", INFO, (device->capacity.lba_count * device->capacity.block_size) / 1024);

    iso9660_allocate_buffers();

    if(device)
        read_kernel(device);
    else
        log("Couldn't find the booted device--try rebooting?", ERROR);

    for(;;) {}
}