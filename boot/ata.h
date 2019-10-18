#ifndef __ATA_H_
#define __ATA_H_

#include <stdbool.h>
#include <stdint.h>
#include "io.h"
#include "terminal.h"

#define ATAPI_SECTOR_SIZE        2048

#define ATA_PRIMARY_BUS              0x01F0
#define ATA_SECONDARY_BUS            0x0170

#define ATA_PRIMARY_CONTROL_PORT     0x03F6
#define ATA_SECONDARY_CONTROL_PORT   0x0376

#define ATA_DATA_REGISTER            0 // R/W
#define ATA_ERROR_REGISTER           1 // R
#define ATA_FEATURE_REGISTER         1 // W
#define ATA_SECTOR_COUNT_REGISTER    2 // R/W
#define ATA_LBA_LOW_REGISTER         3 // R/W
#define ATA_LBA_MID_REGISTER         4 // R/W
#define ATA_LBA_HIGH_REGISTER        5 // R/W
#define ATA_DRIVE_SELECT_REGISTER    6 // R/W
#define ATA_STATUS_REGISTER          7 // R
#define ATA_COMMAND_REGISTER         7 // W

#define ATA_BUSY                     0x80
#define ATA_DRQ                      0x08
#define ATA_ERROR                    0x01

#define ATA_IDENTIFY_CMD             0xEC
#define ATA_PACKET_CMD               0xA0
#define ATA_IDENTIFY_PACKET_CMD      0xA1
#define ATA_READ_PIO_CMD             0x20
#define ATA_READ_CMD                 0xA8

enum AtaDeviceType
{
    ATA_NOT_SCANNED,
    ATA_UNKNOWN_DRIVE,
    ATA_PATA_DRIVE,
    ATA_SATA_DRIVE,
    ATA_PATAPI_DRIVE,
    ATA_SATAPI_DRIVE,
};

typedef struct
{
    char serial_number[40];
    char firmware_revision[16];
    char model_number[80];
    bool supports_48_lba;
    uint64_t block_count;
} AtaDeviceInfo;

typedef struct
{
    uint16_t io_base;
    uint16_t control;
    bool slave;

    enum AtaDeviceType type;
    AtaDeviceInfo info;
} AtaDevice;

AtaDevice scanned_devices[4];
uint16_t device_identify_buffer[256];

AtaDevice *selected_device;

/**
 * Writes the provided value to the provided register of the currently selected ATA device
 * Parameters:
 *      uint8_t reg: The ATA register to write to (see the defines above)
 *      uint8_t value: The value to write
 **/
void ata_write_register(uint8_t reg, uint8_t value)
{
    outb((*selected_device).io_base + reg, value);
}

/**
* Writes the provided value to the provided register of the provided device
* Parameters:
*       AtaDevice device: The device to write to
*       uint8_t reg: The register to write to
*       uint8_t val: The value to write
**/
void ata_write_device_register(AtaDevice device, uint8_t reg, uint8_t value)
{
    outb(device.io_base = reg, value);
}

/**
 * Writes the provided value to the control register of the currently selected ATA device
 * Parameters:
 *      uint8_t value: The value to write
 **/
void ata_write_control(uint8_t value)
{
    outb((*selected_device).control, value);
}

/**
 * Reads from the provided register of the currently selected ATA device
 * Parameters:
 *      uint8_t reg: The ATA register to read from (see the defines above)
 **/
uint8_t ata_read_register(uint8_t reg)
{
    return inb((*selected_device).io_base + reg);
}

/**
 * Stalls for approx. 400ns, as requested by the spec
 **/
void ata_400ns_wait()
{
    ata_read_register(ATA_STATUS_REGISTER);
    ata_read_register(ATA_STATUS_REGISTER);
    ata_read_register(ATA_STATUS_REGISTER);
    ata_read_register(ATA_STATUS_REGISTER);
}

/**
 * Sends a command to the selected drive
 * Parameters:
 *      uint8_t command: the command byte to send
 **/
uint8_t ata_send_command(uint8_t command)
{
    ata_write_register(ATA_COMMAND_REGISTER, command);

    uint32_t timeout = 2000000;
    uint8_t status = 0;

    do
    {
        status = ata_read_register(ATA_STATUS_REGISTER);
        timeout--;
    } while ((timeout > 0) && (status & ATA_BUSY) && !(status & ATA_ERROR));
    
    ata_400ns_wait();

    return ata_read_register(ATA_STATUS_REGISTER);
}

/**
 * Selects an ATA device as the drive to be operated upon
 * 
 * Parameters:
 *      AtaDevice *device: the device to selected
 *      int8_t lbaHighNibble: The highest four bits of the LBA to be selected, -1 if the next command is to be ATA_IDENTIFY
 **/
void ata_select_device(AtaDevice *device, int8_t lbaHighNibble)
{
    if(lbaHighNibble == -1)
    {
        ata_write_device_register((*device), ATA_COMMAND_REGISTER, (*device).slave ? 0xB0 : 0xA0);
    }
    else
    {
        // The 0x40 tells ATA to use LBA for addressing
        ata_write_device_register((*device), ATA_COMMAND_REGISTER, ((*device).slave ? 0xB0 : 0xA0) | 0x40 | (lbaHighNibble & 0xF));
    }

    ata_400ns_wait();

    selected_device = device;
}

/**
 * Disables IRQs for (all?) the currently selected device
 **/
void ata_disable_irqs()
{
    ata_write_register(ATA_COMMAND_REGISTER, 0x02);
}

/**
 * Sends the ATAPI reset command to the currently selected device if supported 
 **/
void atapi_reset_device()
{
    if((*selected_device).type < ATA_PATAPI_DRIVE)
        return;

    ata_write_control(0x04);
    ata_400ns_wait();
    ata_write_control(0x02);

    uint32_t timeout = 2000000;
    uint8_t status = 0;
    do
    {
        ata_400ns_wait();
        status = ata_read_register(ATA_STATUS_REGISTER);
        timeout--;
    } while ((timeout > 0) && (status & ATA_BUSY) && !(status & ATA_ERROR));
    
    ata_select_device(selected_device, -1);
}

void ata_parse_identify_data()
{
    // If we ever need the data returned, this will be properly implemented
}

void atapi_identify_device()
{
    AtaDevice device = *selected_device;

    if(device.type < ATA_PATAPI_DRIVE)
        return;

    atapi_reset_device();

    ata_send_command(ATA_IDENTIFY_PACKET_CMD);

    for(int i = 0; i < 256; i++)
    {
        device_identify_buffer[i] = inw(device.io_base + ATA_DATA_REGISTER);
    }

    ata_parse_identify_data();
}

AtaDevice ata_identify_device(uint16_t io_base, uint16_t control, bool slave)
{
    AtaDevice device = {.io_base = io_base, .control = control, .slave = slave, .type = ATA_NOT_SCANNED, .info = { }};

    ata_select_device(&device, -1);
    
    ata_write_register(ATA_SECTOR_COUNT_REGISTER, 0x0);
    ata_write_register(ATA_LBA_LOW_REGISTER, 0x0);
    ata_write_register(ATA_LBA_MID_REGISTER, 0x0);
    ata_write_register(ATA_LBA_HIGH_REGISTER, 0x0);

    uint8_t status = ata_send_command(ATA_IDENTIFY_CMD);

    // If the error bit is set, then the drive is not PATA--however, we'll need to check again for non-complaint non-PATA drives
    if(status & ATA_ERROR)
    {
        uint16_t signature = ata_read_register(ATA_LBA_HIGH_REGISTER) << 8 | ata_read_register(ATA_LBA_MID_REGISTER);

        switch(signature)
        {
            case 0xC33C:
                device.type = ATA_SATA_DRIVE;
                goto atapi_ret;
            case 0xEB14:
                device.type = ATA_PATAPI_DRIVE;
                goto atapi_ret;
            case 0x9669:
                device.type = ATA_SATAPI_DRIVE;
                goto atapi_ret;
            default:
                device.type = ATA_UNKNOWN_DRIVE;
                goto ret;
        }
    }
    else
    if(status == 0x0)
    {
        goto ret;
    }

    // Second try for the drives that sat at the back of the classroom
    uint16_t signature = ata_read_register(ATA_LBA_HIGH_REGISTER) << 8 | ata_read_register(ATA_LBA_MID_REGISTER);

    switch(signature)
    {
        case 0xC33C:
            device.type = ATA_SATA_DRIVE;
            goto atapi_ret;
        case 0xEB14:
            device.type = ATA_PATAPI_DRIVE;
            goto atapi_ret;
        case 0x9669:
            device.type = ATA_SATAPI_DRIVE;
            goto atapi_ret;
        default:
            device.type = ATA_UNKNOWN_DRIVE;
            goto ret;
    }

    uint32_t timeout = 2000000;
    status = 0;

    do
    {
        ata_400ns_wait();
        status = ata_read_register(ATA_STATUS_REGISTER);
        timeout--;
    }
    while((timeout > 0) && !(status & ATA_DRQ) && !(status & ATA_ERROR));

    if(status & ATA_ERROR)
    {
        if(!(status & ATA_DRQ))
        {
            device.type = ATA_PATA_DRIVE;

            for(int i = 0; i < 256; i++)
            {
                device_identify_buffer[i] = inw(device.io_base + ATA_DATA_REGISTER);
            }

            ata_parse_identify_data();

            goto ret;
        }
    }

    atapi_ret:
    atapi_identify_device();
    return device;

    ret:
    return device;
}

AtaDevice *ata_find_devices()
{
    scanned_devices[0] = ata_identify_device(ATA_PRIMARY_BUS, ATA_PRIMARY_CONTROL_PORT, false);
    scanned_devices[1] = ata_identify_device(ATA_PRIMARY_BUS, ATA_PRIMARY_CONTROL_PORT, true);
    scanned_devices[2] = ata_identify_device(ATA_SECONDARY_BUS, ATA_SECONDARY_CONTROL_PORT, false);
    scanned_devices[3] = ata_identify_device(ATA_SECONDARY_BUS, ATA_SECONDARY_CONTROL_PORT, true);

    for(int i = 0; i < 4; i++)
    {
        printf("Drive %d type = %x\n", i, scanned_devices[i].type);

        if(scanned_devices[i].type > ATA_UNKNOWN_DRIVE)
            return &scanned_devices[i];
    }

    return 0;
}

void ata_read_sector(uint32_t lba, uint8_t sectors, uint16_t *buffer)
{
    ata_select_device(selected_device, (lba >> 24) & 0x0F);

    ata_write_register(ATA_SECTOR_COUNT_REGISTER, sectors);
    ata_write_register(ATA_LBA_LOW_REGISTER, lba & 0xFF);
    ata_write_register(ATA_LBA_MID_REGISTER, (lba >> 8) & 0xFF);
    ata_write_register(ATA_LBA_HIGH_REGISTER, (lba >> 16) & 0xFF);

    ata_send_command(ATA_READ_PIO_CMD);

    for(; sectors > 1; sectors--)
    {
        for(int i = 0; i < 256; i++)
        {
            buffer[i] = inw((*selected_device).io_base + ATA_DATA_REGISTER);
        }

        ata_400ns_wait();
    }
}

#endif