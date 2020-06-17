#include <efi.h>
#include <efilib.h>

#define ERR(s, m) if(EFI_ERROR(s)) uefi_call_wrapper(ST->ConOut->OutputString, 2, ST->ConOut, m);

#include "io.h"
#include "ata.h"
#include "iso9660.h"
#include "elf.h"
#include "multiboot2.h"

const CHAR8 KERNEL_FILE_NAME[] = "KERNEL/KERNEL64.ELF";

EFI_SYSTEM_TABLE *ST = NULL;
EFI_STATUS Status;

EFI_STATUS efi_main (EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable)
{
    EFI_STATUS Status;
    ST = SystemTable;

    InitializeLib(ImageHandle, SystemTable);

    ST->BootServices->SetWatchdogTimer(0, 0, 0, NULL);

    Status = uefi_call_wrapper(ST->ConOut->Reset, 2, ST->ConOut, FALSE);
    ERR(Status, L"There was an error resetting the console!\r\n");

    Status = uefi_call_wrapper(ST->ConOut->ClearScreen, 1, ST->ConOut);
    ERR(Status, L"There was an error clearing the console!\r\n");

    AtaDevice *device = ata_detect_devices(ATA_PATAPI_DRIVE);

    if(device != NULL)
    {
        UINT16 size = (device->capacity.lba_count * device->capacity.block_size) / 1024;

        Print(L"Found a %dKB CD-ROM...\r\n", size);

        iso9660_allocate_buffers(ST);

        // The PVD is always located at sector 16 (0x10) in the image
        VolumeDescriptor *descriptor = read_volume_descriptor(device, 0x10);

        if(descriptor->type == 0x1)
        {
            PrimaryVolumeDescriptor *pvd = (PrimaryVolumeDescriptor*)descriptor;
            DirectoryRecord *directory_record = load_root_directory(pvd, device);

            UINT8 *file = load_file(KERNEL_FILE_NAME, directory_record, device);

            if(file)
            {
                ElfHeader *elf_header = (ElfHeader*) file;

                if(strcmp(elf_header->magic_text, (CONST CHAR8*) "ELF", 3))
                {
                    Print(L"Loaded kernel ELF to 0x%x...\r\n", file);

                    ElfProgramHeader *header_table = (ElfProgramHeader*)((UINT64) elf_header + elf_header->program_header_table_position);

                    ElfProgramHeader *text_header = header_table;
                    ElfProgramHeader *data_header = (ElfProgramHeader*) ((UINT64) header_table + elf_header->program_header_entry_size);

                    VOID *text_ptr = (VOID*) ((UINT64) elf_header + text_header->data_offset);
                    VOID *data_ptr = (VOID*) ((UINT64) elf_header + data_header->data_offset);
                    
                    // Copy the .text and .data sections of the ELF into memory
                    memcpy((VOID *restrict) text_header->load_address, text_ptr, text_header->data_size);
                    memcpy((VOID *restrict) data_header->load_address, data_ptr, data_header->data_size);

                    multiboot2_execute_image(text_header->load_address);

                    Print(L"Returned from kernel!\r\n");
                    for(;;);
                }
                else
                {
                    Print(L"Could not find a valid ELF image!\r\n");
                }                
            }
        }
    }
    else
    {
        Print(L"Couldn't find a PATAPI device!\r\n");
    }    

    for(;;);

    return EFI_SUCCESS;
}