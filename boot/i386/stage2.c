#include <stdarg.h>

#include "types.h"
#include "io.h"
#include "memory_map.h"

#include "terminal.h"
#include "terminal_impl.h"

#include "ata.h"
#include "iso9660.h"
#include "elf.h"

void run_kernel(uint32_t address)
{
    log("Jumping to kernel at 0x%x", TERMINAL_INFO_LOG, address);

    void (*kernel_main)(void) = (void*)address;
    kernel_main();
}

void read_kernel(AtaDevice *device)
{
    // The PVD is always located at sector 16 (0x10) in the image
    VolumeDescriptor *descriptor = read_volume_descriptor(device, 0x10);

    if(descriptor)
    {
        // PVDs have a type of 1
        if(descriptor->type == 0x1)
        {
            PrimaryVolumeDescriptor *pvd = (PrimaryVolumeDescriptor*)descriptor;
            DirectoryRecord *directory_record = load_root_directory(pvd, device);

            uint8_t *file = load_file("KERNEL/KERNEL32.ELF", directory_record, device);

            if(file)
            {
                Elf32Header *elf_header = (Elf32Header*)file;

                if(strcmp(elf_header->magic_text, "ELF", 3))
                {
                    log("Loaded kernel ELF at 0x%x", TERMINAL_INFO_LOG, file);

                    Elf32ProgramHeader *header_table = (Elf32ProgramHeader*)((uint32_t) elf_header + elf_header->program_header_table_position);

                    Elf32ProgramHeader text_header = header_table[0];
                    Elf32ProgramHeader data_header = header_table[1];

                    if(text_header.type == 0x1 && text_header.flags == 0b101)
                    {
                        // Load the text header!
                        uint32_t src = ((uint32_t) elf_header) + text_header.data_offset;

                        memcpy((void *restrict)text_header.load_address, (const void *restrict)src, text_header.data_size);
                    }
                    else
                    {
                        
                    }
                    
                    if(data_header.type == 0x1 && data_header.flags == 0b110)
                    {
                        // Load the data header!
                        uint32_t src = ((uint32_t) elf_header) + data_header.data_offset;
                        memcpy((void *restrict)data_header.load_address, (const void *restrict)src, data_header.data_size);
                    }
                    else
                    {

                    }

                    // Parse the multiboot header
                
                    uint32_t *ptr = (uint32_t*)text_header.load_address;

                    while(*ptr != 0xE85250D6) // magic number
                        ptr++;

                    uint32_t header_size = *(ptr + 2);
                    uint32_t code_address = ((uint32_t) ptr) + header_size;

                    run_kernel(code_address);

                    log("Returned from kernel!", TERMINAL_ERROR_LOG);
                    for(;;);
                }
                else
                {
                    log("Kernel is not a valid ELF image!", TERMINAL_ERROR_LOG);
                }
            }
            else
            {
                log("Couldn't find kernel!", TERMINAL_ERROR_LOG);
            }
        }
        else
        {
            log("Couldn't find primary volume descriptor!", TERMINAL_ERROR_LOG);
        }
    }
    else
    {
        log("Couldn't find volume descriptor!", TERMINAL_ERROR_LOG);
    }

    log("Try rebooting or recreating your media...", TERMINAL_ERROR_LOG);
}

int loader_main(void)
{
    terminal_init();

    log("Stelox v0.0.1 booted!", TERMINAL_INFO_LOG);

    memory_map_init();
    log("Received memory map with %d entries", TERMINAL_INFO_LOG, memory_map.length);

    AtaDevice *device = ata_detect_devices(ATA_PATAPI_DRIVE);
    log("Found a %uKB CD-ROM", TERMINAL_INFO_LOG, (device->capacity.lba_count * device->capacity.block_size) / 1024);

    if(device)
        read_kernel(device);
    else
        log("Couldn't find the booted device--try rebooting?", TERMINAL_ERROR_LOG);

    for(;;) {}

    return 0;
}