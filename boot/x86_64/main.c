#include <efi.h>
#include <efilib.h>

#include "types.h"

#include "terminal.h"
#include "terminal_impl.h"
#include "io.h"

#include "ata.h"
#include "iso9660.h"
#include "elf.h"
#include "multiboot2.h"

const char KERNEL_FILE_NAME[] = "KERNEL/KERNEL64.ELF";

EFI_SYSTEM_TABLE *ST = NULL;
EFI_STATUS Status;

void iso9660_allocate_buffers(EFI_SYSTEM_TABLE *ST)
{
    EFI_STATUS Status = uefi_call_wrapper(ST->BootServices->AllocatePool, 3, EfiLoaderData, 0x400000, &buffer);
    ERR(Status, "There was an error allocating a pool for loaded sectors!");

    Status = uefi_call_wrapper(ST->BootServices->AllocatePool, 3, EfiLoaderData, 0x100, &name_buffer);
    ERR(Status, "There was an error allocating a pool for names!");
}

EFI_STATUS efi_main (EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable)
{
    EFI_STATUS Status;
    ST = SystemTable;

    InitializeLib(ImageHandle, SystemTable);

    ST->BootServices->SetWatchdogTimer(0, 0, 0, NULL);

    Status = uefi_call_wrapper(ST->ConOut->Reset, 2, ST->ConOut, FALSE);
    ERR(Status, "There was an error resetting the console!");

    Status = uefi_call_wrapper(ST->ConOut->ClearScreen, 1, ST->ConOut);
    ERR(Status, "There was an error clearing the console!");

    terminal_init();

    AtaDevice *device = ata_detect_devices(ATA_PATAPI_DRIVE);
    if(device == NULL)
    {
        ERR(1, "Could not find a PATAPI-complaint drive! Please try restarting...");
        for(;;);
    }

    // Convert the size of the disk into kilobytes and print it
    uint16_t size = (device->capacity.lba_count * device->capacity.block_size) / 1024;
    log("Found a %dKB CD-ROM...", INFO, size);

    // Allocate buffers for parsing of the ISO9660 filesystem
    iso9660_allocate_buffers(ST);

    // The PVD is always located at sector 16 (0x10) in the image
    VolumeDescriptor *descriptor = read_volume_descriptor(device, 0x10);

    if(descriptor->type == 0x1)
    {
        PrimaryVolumeDescriptor *pvd = (PrimaryVolumeDescriptor*)descriptor;
        DirectoryRecord *directory_record = load_root_directory(pvd, device);

        uintptr_t file = load_file(KERNEL_FILE_NAME, directory_record, device);

        if(file)
        {
            Elf64Header *elf_header = (Elf64Header*) file;

            if(strcmp(elf_header->magic_text, (const char*) "ELF", 3))
            {
                log("Loaded kernel ELF to 0x%x...", INFO, file);

                Elf64ProgramHeader *header_table = (Elf64ProgramHeader*)((uintptr_t) elf_header + elf_header->program_header_table_position);

                Elf64ProgramHeader *text_header = header_table;
                Elf64ProgramHeader *data_header = (Elf64ProgramHeader*) ((uintptr_t) header_table + elf_header->program_header_entry_size);

                VOID *text_ptr = (VOID*) ((uintptr_t) elf_header + text_header->data_offset);
                VOID *data_ptr = (VOID*) ((uintptr_t) elf_header + data_header->data_offset);
                
                // Copy the .text and .data sections of the ELF into memory
                memcpy((VOID *restrict) text_header->load_address, text_ptr, text_header->data_size);
                memcpy((VOID *restrict) data_header->load_address, data_ptr, data_header->data_size);

                multiboot2_execute_image(text_header->load_address);

                log("Returned from kernel!", INFO);
                for(;;);
            }
            else
            {
                ERR(1, "Could not find a valid ELF image!");
            }                
        }
    }  

    for(;;);

    return EFI_SUCCESS;
}