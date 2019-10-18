#include <stdint.h>
#include <stdbool.h>

#include "terminal.h"
#include "ata.h"

uint16_t *KERNEL_ADDRESS = (uint16_t*)0x7E00;

int loader_main(void)
{
    terminal_init();

    printf("Welcome to %<Stelox%@ v0.0.1!\n", create_vga_color(0x3, 0x0));

    AtaDevice *device = ata_find_devices();
    ata_select_device(device, -1);

    if(device)
    {
        printf("Valid ATA device found...\nType: %X\n", (*device).type);
        ata_read_sector(0, 1, KERNEL_ADDRESS);
        printf("Done reading to %X\n", KERNEL_ADDRESS);
    }
    else
    {
        put_string("No valid ATA device found!\nPlease try restarting...\n");
    }

    for(;;) {}

    return 0;
}