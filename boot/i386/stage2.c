#include <stdarg.h>

#include "types.h"
#include "io.h"
#include "terminal.h"
#include "ata.h"

uint8_t *KERNEL_ADDRESS = (uint8_t*)0x0500;

void read_sectors(AtaDevice *device)
{
    atapi_read_sector(device, 0x11, 1, KERNEL_ADDRESS);
}

int loader_main(void)
{
    terminal_init();

    log("Stelox v0.0.1 booted!", TERMINAL_INFO_LOG);

    ata_detect_devices();

    for(int i = 0; i < 1024; i++)
        KERNEL_ADDRESS[i] = 0xFF;

    if(ata_primary_master.type == ATA_PATAPI_DRIVE)
    {
        read_sectors(&ata_primary_master);
    }
    if(ata_primary_slave.type == ATA_PATAPI_DRIVE)
    {
        read_sectors(&ata_primary_slave);
    }
    if(ata_secondary_master.type == ATA_PATAPI_DRIVE)
    {
        read_sectors(&ata_secondary_master);
    }
    if(ata_secondary_slave.type == ATA_PATAPI_DRIVE)
    {
        read_sectors(&ata_secondary_slave);
    }

    for(int y = 0; y < 16; y++)
    {
        for(int x = 0; x < 16; x++)
        {
            put_int(KERNEL_ADDRESS[(y * 16) + x], false, 16);
            printf(" ");
        }
        printf("\n");
    }

    for(;;) {}

    return 0;
}