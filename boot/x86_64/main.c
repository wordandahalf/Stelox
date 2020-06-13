#include <efi.h>
#include <efilib.h>

#include "io.h"
#include "ata.h"
#include "iso9660.h"
#include "elf.h"

#define ERR(s, m) if(EFI_ERROR(s)) uefi_call_wrapper(ST->ConOut->OutputString, 2, ST->ConOut, m);

const CHAR16 *KERNEL_FILE_NAME = "kernel/kernel64.elf";

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
        
        // The PVD is always located at sector 16 (0x10) in the image
        VolumeDescriptor *descriptor = read_volume_descriptor(device, 0x10);
        Print(L"Type: %d\r\n", descriptor->type);

        for(;;);
    }

    for(;;);

    return EFI_SUCCESS;
}