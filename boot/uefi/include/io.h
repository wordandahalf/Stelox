#ifndef __UEFI_IO_H_
#define __UEFI_IO_H_

#include <efi.h>
#include <efilib.h>

BOOLEAN check_efi_error(EFI_STATUS status, const CHAR16 *error_msg)
{
    if(EFI_ERROR(status))
    {
        Print(L"[%EERROR%N] %H%s%N\r\n", error_msg);
        return TRUE;
    }

    return FALSE;
}

void log_msg(const CHAR16 *msg)
{
    uefi_call_wrapper(ST->ConOut->SetAttribute, 2, ST->ConOut, 0x0F);
    Print(L"%H%s%N\r\n", msg);
}

void log_info(const CHAR16 *msg)
{
    uefi_call_wrapper(ST->ConOut->SetAttribute, 2, ST->ConOut, 0x0F);
    Print(L"[");
    uefi_call_wrapper(ST->ConOut->SetAttribute, 2, ST->ConOut, 0x09);
    Print(L"INFO");
    uefi_call_wrapper(ST->ConOut->SetAttribute, 2, ST->ConOut, 0x0F);
    Print(L"] %s%N\r\n", msg);
}

EFI_STATUS load_kernel(EFI_SYSTEM_TABLE *ST, EFI_HANDLE image_handle, /* GPU_CONFIG * Graphics, */ EFI_CONFIGURATION_TABLE *config_tables, UINTN number_of_config_tables, UINT32 uefi_version)
{
    EFI_STATUS status;

    EFI_PHYSICAL_ADDRESS kernel_base_address = 0;
    UINTN kernel_pages = 0;

    EFI_LOADED_IMAGE_PROTOCOL *loaded_image;

    return EFI_SUCCESS;
}

#endif