#ifndef __ISO9660_H_
#define __ISO9660_H_

typedef struct
{
    uint8_t         record_length;
    uint8_t         extended_attributes_length;
    uint32_t        directory_extent_lba;
    uint32_t        directory_extent_lba_msb;
    uint32_t        directory_extent_length;
    uint32_t        directory_extent_length_msb;
    uint8_t         recording_date[7];
    uint8_t         file_flags;
    uint8_t         file_uint_size;
    uint8_t         interleave_gap_size;
    uint16_t        volume_sequence_number;
    uint16_t        volume_sequqnce_number_msb;
    uint8_t         file_name_length;
    const char      file_identifier[];

} __attribute__((packed)) DirectoryRecord;

typedef struct
{
    uint8_t         type;
    const char      id[5];
    uint8_t         version;
    uint8_t         unused_field0;
    const char      system_id[32];
    const char      volume_id[32];
    uint8_t         unused_field1[8];
    uint32_t        volume_space_size;
    uint32_t        msb_volume_space_size;
    uint8_t         unused_field2[32];
    uint16_t        volume_set_size;
    uint16_t        msb_volume_set_size;
    uint16_t        volume_sequence_number;
    uint16_t        msb_volume_sequence_number;
    uint16_t        logical_block_size;
    uint16_t        msb_logical_block_size;
    uint32_t        path_table_size;
    uint32_t        msb_path_table_size;
    uint32_t        path_table_lba;
    uint32_t        optional_path_table_lba;
    uint32_t        msb_path_table_lba;
    uint32_t        msb_optional_path_table_lba;
    uint8_t         root_directory[34];
    uint8_t         the_rest[1862];                 // We don't actually care about anything else...
} __attribute__((packed)) PrimaryVolumeDescriptor;

typedef struct
{
    uint8_t         type;
    const char      id[5];
    uint8_t         version;
    uint8_t         data[2041];
} __attribute__((packed)) VolumeDescriptor;

// The buffer in memory for disk reads. Hopefully it never overflows into code (though it would have to fill up into 0x7C00)
static uint8_t  *buffer = (uint8_t*)0x1000;

// The buffer in memory for load_file method--this probably can optimized away
static char     *name_buffer = (char*)0x900;

/*
*   Reads the LBA into memory and ensures it is a valid ISO 9660 volume descriptor
*   Returns a pointer to the found descriptor or NULL
*/
VolumeDescriptor *read_volume_descriptor(AtaDevice *device, uint32_t lba)
{
    atapi_read_sector(device, lba, 1, buffer);

    if(strcmp((const char *)(buffer + 1), "CD001", 5))
    {
        if(*(buffer + 6) == 0x1)
        {
            log("Found volume descriptor at LBA 0x%x", TERMINAL_INFO_LOG, lba);

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

    atapi_read_sector(device, root->directory_extent_lba, root->directory_extent_length / device->capacity.block_size, buffer);

    DirectoryRecord *record = (DirectoryRecord*)buffer;

    buffer += record->directory_extent_length;
    return record;
}

/*
*   Loads the provided filename from the AtaDevice, using the DirectoryRecord pointer as the root directory
*   Filenames are delimited by forward slashes ('/')
*   Returns a pointer to the loaded file
*/
uint8_t *load_file(const char *filename, DirectoryRecord *directory, AtaDevice *device)
{
    uint8_t name_length = 0;
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
            if(strcmp(directory->file_identifier, name_buffer, name_length))
            {
                // If the name ends with a null terminator and the file identifier ends with a ';'
                if(!filename[name_length] || directory->file_identifier[name_length] == ';')
                {
                    // Load the file!
                    atapi_read_sector(device, directory->directory_extent_lba, directory->directory_extent_length / device->capacity.block_size, buffer);
                    
                    uint8_t *file = buffer;
                    buffer += directory->directory_extent_length;

                    return file;
                }
                else
                if(filename[name_length] == '/')
                {
                    // Load the folder!                    
                    atapi_read_sector(device, directory->directory_extent_lba, directory->directory_extent_length / device->capacity.block_size, buffer);
                    
                    DirectoryRecord *subdirectory = (DirectoryRecord*)buffer;
                    buffer += directory->directory_extent_length;

                    return load_file(filename + name_length + 1, subdirectory, device);
                }
            }
            else
            {
                // Go to the next entry
                directory = (DirectoryRecord*) ((uint32_t) directory + directory->record_length);
            }
        }
    }

    log("Couldn't find '%s'...", TERMINAL_ERROR_LOG, name_buffer);

    return NULL;
}

#endif