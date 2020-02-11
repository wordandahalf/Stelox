#include <stdarg.h>

#include "types.h"
#include "io.h"
#include "terminal.h"
#include "ata.h"
#include "memory_map.h"

uint8_t *KERNEL_ADDRESS = (uint8_t*)0x1000;

void run_kernel()
{
    void (*kernel_main)(void) = (void*)KERNEL_ADDRESS;
    kernel_main();
}

void read_kernel(AtaDevice *device)
{
    atapi_read_sector(device, 0x10, 1, KERNEL_ADDRESS);

    uint32_t signature = ((uint32_t *)(KERNEL_ADDRESS + 1))[0];

    if(signature == 0x30304443) // 'CD00' in ASCII (the whole signature is CD001, but that is too big for a uint32_t)
    {
        uint8_t volume_type = KERNEL_ADDRESS[0];

        // volume_type == 1 => PVD
        if(volume_type == 0x1)
        {
            log("Found the Primary Volume Descriptor...", TERMINAL_INFO_LOG);

            // To be continued...
            for(;;);
        }
        else
        {
            log("Found Volume Descriptor of type %x instead of type 1!", TERMINAL_ERROR_LOG, volume_type);
            goto error;
        }
    }
    else
    {
        log("Could not find ISO9660 PVD.", TERMINAL_ERROR_LOG);
        goto error;
    }

    error:
        log("Please try recreating your startup medium.", TERMINAL_ERROR_LOG);
        for(;;);
}

int loader_main(void)
{
    terminal_init();

    log("Stelox v0.0.1 booted!", TERMINAL_INFO_LOG);

    memory_map_init();
    log("Received memory map with %d entries.", TERMINAL_INFO_LOG, memory_map.length);

    AtaDevice *device = ata_detect_devices(ATA_PATAPI_DRIVE);
    log("Found a %uKB CD-ROM.", TERMINAL_INFO_LOG, (device->capacity.lba_count * device->capacity.block_size) / 1024);

    if(device)
        read_kernel(device);
    else
        log("Couldn't find the booted device--try rebooting?", TERMINAL_ERROR_LOG);

    for(;;) {}

    return 0;
}