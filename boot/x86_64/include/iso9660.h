#ifndef __UEFI_ISO9660_H_
#define __UEFI_ISO9660_H_

#include <efi.h>

#include "ata.h"

typedef struct
{
    UINT8         record_length;
    UINT8         extended_attributes_length;
    UINT32        directory_extent_lba;
    UINT32        directory_extent_lba_msb;
    UINT32        directory_extent_length;
    UINT32        directory_extent_length_msb;
    UINT8         recording_date[7];
    UINT8         file_flags;
    UINT8         file_uint_size;
    UINT8         interleave_gap_size;
    UINT16        volume_sequence_number;
    UINT16        volume_sequqnce_number_msb;
    UINT8         file_name_length;
    CONST CHAR8   file_identifier[];
} __attribute__((packed)) DirectoryRecord;

typedef struct
{
    UINT8         type;
    CONST CHAR8   id[5];
    UINT8         version;
    UINT8         unused_field0;
    CONST CHAR8   system_id[32];
    CONST CHAR8   volume_id[32];
    UINT8         unused_field1[8];
    UINT32        volume_space_size;
    UINT32        msb_volume_space_size;
    UINT8         unused_field2[32];
    UINT16        volume_set_size;
    UINT16        msb_volume_set_size;
    UINT16        volume_sequence_number;
    UINT16        msb_volume_sequence_number;
    UINT16        logical_block_size;
    UINT16        msb_logical_block_size;
    UINT32        path_table_size;
    UINT32        msb_path_table_size;
    UINT32        path_table_lba;
    UINT32        optional_path_table_lba;
    UINT32        msb_path_table_lba;
    UINT32        msb_optional_path_table_lba;
    UINT8         root_directory[34];
    UINT8         the_rest[1862];                 // We don't actually care about anything else...
} __attribute__((packed)) PrimaryVolumeDescriptor;

typedef struct
{
    UINT8         type;
    CONST CHAR8    id[5];
    UINT8         version;
    UINT8         data[2041];
} __attribute__((packed)) VolumeDescriptor;

// The buffer in memory for disk reads
static UINT8  *buffer;

// The buffer in memory for load_file method
static CHAR8   *name_buffer;

void iso9660_allocate_buffers(EFI_SYSTEM_TABLE *ST)
{
    EFI_STATUS Status = uefi_call_wrapper(ST->BootServices->AllocatePool, 3, EfiLoaderData, 0x400000, &buffer);
    ERR(Status, L"There was an error allocating a pool for loaded sectors!\r\n");

    Status = uefi_call_wrapper(ST->BootServices->AllocatePool, 3, EfiLoaderData, 0x100, &name_buffer);
    ERR(Status, L"There was an error allocating a pool for names!\r\n");
}

/*
*   Reads the LBA into memory and ensures it is a valid ISO 9660 volume descriptor
*   Returns a pointer to the found descriptor or NULL
*/
VolumeDescriptor *read_volume_descriptor(AtaDevice *device, UINT32 lba)
{
    atapi_read_sectors(device, lba, 1, buffer);

    if(strcmp(((CHAR8*) buffer) + 1, (CHAR8*) "CD001", 5))
    {
        if(*(buffer + 6) == 0x1)
        {
            Print(L"Found volume descriptor at LBA 0x%x\r\n", lba);

            VolumeDescriptor *descriptor = (VolumeDescriptor*)buffer;

            buffer += sizeof(VolumeDescriptor);
            return descriptor;
        }
    }

    return NULL;
}

/*
*   Loads the root directory from a primary volume descriptor
*   Returns a pointer to the table of directory records
*/
DirectoryRecord *load_root_directory(PrimaryVolumeDescriptor *pvd, AtaDevice *device)
{
    DirectoryRecord *root = (DirectoryRecord*)pvd->root_directory;

    Print(L"Loading sector 0x%x for root directory\r\n", root->directory_extent_lba);
    atapi_read_sectors(device, root->directory_extent_lba, root->directory_extent_length / device->capacity.block_size, buffer);

    DirectoryRecord *record = (DirectoryRecord*)buffer;

    buffer += record->directory_extent_length;
    return record;
}

/*
*   Loads the provided filename from the AtaDevice, using the DirectoryRecord pointer as the root directory
*   Filenames are delimited by forward slashes ('/')
*   Returns a pointer to the loaded file
*/
UINT8 *load_file(const CHAR8 *filename, DirectoryRecord *directory, AtaDevice *device)
{
    UINT8 name_length = 0;
    /* 
    *   The point of this loop is to get the leftmost folder or file name.
    *   the '/' is used as a path delimiter--the ';' is the ISO9660 delimiter after a file (not folder) name
    */
    while(filename[name_length] && (filename[name_length] != '/') && (directory->file_identifier[name_length] != ';') && (name_length < 0xFF))
    {
        name_buffer[name_length] = filename[name_length];
        name_length++;
    }

    // Input validation--the leftmost file/folder name must end with a NULL terminator (signifing a file) or a '/' (signifing a folder)
    if(!filename[name_length] || filename[name_length] == '/')
    {
        // This while loop iterates over all the (valid) directories/files in the current table
        while(directory->record_length)
        {
            // If the name is what we are looking for, then load it!
            if(strcmp((CHAR8*) directory->file_identifier, name_buffer, name_length))
            {
                UINT32 sectors = directory->directory_extent_length / device->capacity.block_size;

                // Since ints chop off decimals, we need to accommodate for a partial sector of data
                if(directory->directory_extent_length % device->capacity.block_size)
                    sectors++;

                atapi_read_sectors(device, directory->directory_extent_lba, sectors, buffer);

                UINT8 *cpy = buffer;
                buffer += directory->directory_extent_length;

                // If the name ends with a null terminator and the file identifier ends with a ';'
                if(!filename[name_length] || directory->file_identifier[name_length] == ';')
                {
                    // Loaded the file!

                    return cpy;
                }
                else
                if(filename[name_length] == '/')
                {
                    // Loaded another directory table

                    return load_file(filename + name_length + 1, (DirectoryRecord*)cpy, device);
                }
            }
            else
            {
                // Go to the next entry
                directory = (DirectoryRecord*) ((UINT64) directory + directory->record_length);
            }
        }
    }

    Print(L"Couldn't find '");
    PrintString((CHAR8*) filename);
    Print(L"'...\r\n");

    return NULL;
}

#endif