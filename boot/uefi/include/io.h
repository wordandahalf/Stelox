#ifndef __UEFI_IO_H_
#define __UEFI_IO_H_
#include <efi.h>
#include <efilib.h>

void check_efi_error(EFI_STATUS status, const CHAR16 *error_msg)
{
    if(EFI_ERROR(status))
    {
        Print(L"[%EERROR%N] %H%s%N\r\n", error_msg);
    }
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

#endif