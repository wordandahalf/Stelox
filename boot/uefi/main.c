#include <efi.h>
#include <efilib.h>

#include "io.h"

EFI_SYSTEM_TABLE *ST = NULL;

EFI_STATUS efi_main (EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {
    ST = SystemTable;
    InitializeLib(ImageHandle, ST);

    EFI_STATUS status;

    status = ST->ConOut->ClearScreen(ST->ConOut);
    check_efi_error(status, L"Failed to clear the screen");

    log_info(L"Stelox-UEFI v0.0.1 loaded!");

    UINT64 timeout_seconds = 10;

    EFI_INPUT_KEY key;

    Print(L"%HContinuing in %llu seconds...\n\rPress any key to stop the timer, press 'd' to enter debug mode, or press 'c' to immediately boot into the selected OS.%N\r\n", timeout_seconds);

    while(timeout_seconds)
    {
        status = WaitForSingleEvent(ST->ConIn->WaitForKey, 10000000);
        if(status != EFI_TIMEOUT)
        {
            status = ST->ConIn->ReadKeyStroke(ST->ConIn, &key);
            check_efi_error(status, L"Failed to read from the input buffer");

            if(key.UnicodeChar == L'd')
            {
                log_info(L"Loading debug mode...");
                break;
            }
            else
            if(key.UnicodeChar == L'c')
            {
                log_info(L"Loading OS...");
                break;
            }
            else
            {
                break;
            }
        }

        timeout_seconds -= 1;
    }

    if(!timeout_seconds)
    {
        log_info(L"Loading OS...");
    }

    return EFI_SUCCESS;
}