#include <stdarg.h>

#include "types.h"
#include "io.h"

#include "terminal.h"
#include "ata.h"

#include "memory_map.h"
#include "iso9660.h"
#include "elf.h"

void run_kernel()
{
    //void (*kernel_main)(void) = (void*)KERNEL_ADDRESS;
    //kernel_main();
}

void read_kernel(AtaDevice *device)
{
    VolumeDescriptor *descriptor = read_volume_descriptor(device, 0x10);

    if(descriptor)
    {
        if(descriptor->type == 0x1)
        {
            PrimaryVolumeDescriptor *pvd = (PrimaryVolumeDescriptor*)descriptor;
            DirectoryRecord *directory_record = load_root_directory(pvd, device);

            uint8_t *file = load_file("KERNEL/KERNEL32.ELF", directory_record, device);

            if(file)
            {
                ElfHeader *elf_header = (ElfHeader*)file;

                if(strcmp(elf_header->magic_text, "ELF", 3))
                {
                    log("Loaded kernel ELF at 0x%x", TERMINAL_INFO_LOG, file);
                }
            }
            else
            {
                log("Couldn't find kernel: try rebooting or recreating media!", TERMINAL_ERROR_LOG);
            }
        }
    }
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