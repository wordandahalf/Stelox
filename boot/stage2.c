#include <stdint.h>
#include <stdbool.h>

#include "terminal.h"
#include "ata.h"

int loader_main(void)
{
    terminal_init();

    printf("Welcome to %<Stelox%@ v0.0.1!\n", create_vga_color(0x3, 0x0));

    AtaDevice *device = ata_find_devices();
    ata_select_device(device, -1);

    if(device)
    {
        printf("Valid ATA device found...\nType: %x\n", (*device).type);
    }
    else
    {
        put_string("No valid ATA device found!\nPlease try restarting...\n");
    }

    for(;;) {}

    return 0;
}