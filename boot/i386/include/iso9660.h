#ifndef __ISO9660_H_
#define __ISO9660_H_

// Where the Primary Volume Descriptor is loaded into memory
#define         PRIMARY_VOLUME_DESCRIPTOR_ADDRESS       0x1000

// Where the ELF kernel is loaded into memory
#define         KERNEL_ADDRESS                          0x2000

typedef struct
{
    uint8_t     type;
    char        id[5];
    uint8_t     version;
    uint8_t     *data[2041];
} PrimaryVolumeDescriptor;

PrimaryVolumeDescriptor *pvd = (PrimaryVolumeDescriptor*) PRIMARY_VOLUME_DESCRIPTOR_ADDRESS;

#endif