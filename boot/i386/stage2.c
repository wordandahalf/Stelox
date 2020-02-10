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

    log("Read ISO9660 PVD...", TERMINAL_INFO_LOG);
}

int loader_main(void)
{
    terminal_init();

    log("Stelox v0.0.1 booted!", TERMINAL_INFO_LOG);

    memory_map_init();
    log("Received memory map with %d entries.", TERMINAL_INFO_LOG, memory_map.length);

    AtaDevice *device = ata_detect_devices(ATA_PATAPI_DRIVE);

    if(device)
        read_kernel(device);
    else
        log("Couldn't find the booted device--try rebooting?", TERMINAL_ERROR_LOG);

    for(;;) {}

    return 0;
}