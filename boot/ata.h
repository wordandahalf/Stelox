#ifndef __ATA_H_
#define __ATA_H_

#include <stdbool.h>
#include <stdint.h>
#include "io.h"
#include "terminal.h"

#define ATAPI_SECTOR_SIZE        2048

#define PRIMARY_ATA_BUS          0x01F0
#define SECONDARY_ATA_BUS        0x0170

#define PRIMARY_CONTROL_PORT     0x03F6
#define SECONDARY_CONTROL_PORT   0x0376

#define DATA_REGISTER            0 // R/W
#define ERROR_REGISTER           1 // R
#define FEATURE_REGISTER         1 // W
#define SECTOR_COUNT_REGISTER    2 // R/W
#define LBA_LOW_REGISTER         3 // R/W
#define LBA_MID_REGISTER         4 // R/W
#define LBA_HIGH_REGISTER        5 // R/W
#define DRIVE_SELECT_REGISTER    6 // R/W
#define STATUS_REGISTER          7 // R
#define COMMAND_REGISTER         7 // W

enum AtaDeviceType
{
    NOT_SCANNED = 0,
    UNKNOWN = 1,
    ATA_NON_PACKET = 2,
    ATA_PACKET = 4,
};

typedef struct
{
    uint16_t io_base;
    uint16_t control;
    bool slave;

    enum AtaDeviceType type;
} AtaDevice;

AtaDevice scanned_devices[4];

void write_port(AtaDevice device, uint8_t port, uint8_t val)
{
    outb(device.io_base + port, val);
}

uint8_t read_port(AtaDevice device, uint8_t port)
{
    return inb(device.io_base + port);
}

void ata_pio_select_drive(AtaDevice device)
{
    write_port(device, DRIVE_SELECT_REGISTER, device.slave ? 0xB0 : 0xA0);
}

AtaDevice ata_pio_identify(uint16_t io_base, uint16_t control, bool slave, bool debug)
{
    AtaDevice device = {.io_base = io_base, .control = control, .slave = slave, .type = NOT_SCANNED};

    ata_pio_select_drive(device);

    write_port(device, SECTOR_COUNT_REGISTER, 0x0);
    write_port(device, LBA_LOW_REGISTER, 0x0);
    write_port(device, LBA_MID_REGISTER, 0x0);
    write_port(device, LBA_HIGH_REGISTER, 0x0);

    write_port(device, COMMAND_REGISTER, 0xEC);

    uint8_t status = read_port(device, STATUS_REGISTER);

    if(status != 0)
    {
        while(read_port(device, STATUS_REGISTER) & 0x80) {}

        uint8_t mid = read_port(device, LBA_MID_REGISTER);
        uint8_t high = read_port(device, LBA_HIGH_REGISTER);

        printf("LBA high, LBA mid=%x\n", high << 8 | mid);

        if(mid == 0x00 && high == 0x00)
        {
            device.type = ATA_NON_PACKET;
        }
        else if(mid == 0x14 && high == 0xEB)
        {    
            device.type = ATA_PACKET;
        }
        else
        {
            device.type = UNKNOWN;
        }
    }

    if(debug)
        printf("ATA Device: (IO Base: %x, Control: %x, Slave: %b, Type: %x)\n", device.io_base, device.control, device.slave, device.type);
    
    return device;
}

AtaDevice *ata_pio_find_devices()
{
    scanned_devices[0] = ata_pio_identify(PRIMARY_ATA_BUS, PRIMARY_CONTROL_PORT, false, false);
    scanned_devices[1] = ata_pio_identify(PRIMARY_ATA_BUS, PRIMARY_CONTROL_PORT, true, false);
    scanned_devices[2] = ata_pio_identify(SECONDARY_ATA_BUS, SECONDARY_CONTROL_PORT, false, false);
    scanned_devices[3] = ata_pio_identify(SECONDARY_ATA_BUS, SECONDARY_CONTROL_PORT, true, false);

    for(int i = 0; i < 4; i++)
    {
        if(scanned_devices[i].type > 1)
        {
            return &scanned_devices[i];
        }
    }

    return 0;
}

void ata_read_sectors(AtaDevice device, uint32_t lba, uint8_t sectors, uint8_t *buffer)
{
    if(device.type < 2)
    {
        put_string("Tried reading from a unknown or unscaned ATA PIO device!\n");
        return;
    }

    if(device.type == ATA_NON_PACKET)
    {
        // Read using ATAPIO
    }
    else
    if(device.type == ATA_PACKET)
    {
        //TODO: Debug
        put_string("Reading via ATA_PACKET\n");

        // Read using ATAPI (packet interface)
        uint8_t read_command[12] = { 0xA8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
        uint8_t status;

        ata_pio_select_drive(device);

        // 400ns delay
        inb(device.control);
        inb(device.control);
        inb(device.control);
        inb(device.control);

        write_port(device, FEATURE_REGISTER, 0x0);

        write_port(device, LBA_MID_REGISTER, ATAPI_SECTOR_SIZE & 0xFF);
        write_port(device, LBA_HIGH_REGISTER, ATAPI_SECTOR_SIZE >> 8);

        write_port(device, COMMAND_REGISTER, 0xA0);

        //TODO: Debug
        put_string("Wait #1...\n");

        while ((status = read_port(device, COMMAND_REGISTER)) & 0x80) {}

	    asm volatile ("pause");

        //TODO: Debug
        put_string("Wait #2...\n");
	    while (!((status = read_port(device, COMMAND_REGISTER)) & 0x8) && !(status & 0x1)) {}

	    asm volatile ("pause");

        if(status & 0x1)
            return;

        read_command[9] = 1;
        read_command[2] = (lba >> 0x18) & 0xFF;
        read_command[3] = (lba >> 0x10) & 0xFF;
        read_command[4] = (lba >> 0x08) & 0xFF;
        read_command[5] = (lba >> 0x00) & 0xFF;

        //TODO: Debug
        put_string("Sending READ command...\n");

        outportsm(device.io_base + DATA_REGISTER, read_command, 6);
        // outsw (ATA_DATA (bus), (uint16_t *) read_cmd, 6);

        uint16_t size = (read_port(device, LBA_HIGH_REGISTER) << 8) | read_port(device, LBA_MID_REGISTER);
        
        if(size != ATAPI_SECTOR_SIZE)
        {
            return;
        }

        //TOOD: Debug
        put_string("Reading sector...\n");

        inportsm(device.io_base + DATA_REGISTER, buffer, size / 2);
        // insw (ATA_DATA (bus), buffer, size / 2);

        while ((status = read_port(device, COMMAND_REGISTER)) & 0x88) {}

	    asm volatile ("pause");

        put_string("Done!\n");
        return;
    }
}

#endif