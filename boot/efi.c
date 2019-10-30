#include <efi.h>
#include <efilib.h>

void check_efi_error(EFI_STATUS status, const CHAR16 *error_msg)
{
    if(EFI_ERROR(status))
    {
        Print(L"[ERROR] ");
        Print(error_msg);
        Print(L"...\r\n");
    }
}

EFI_STATUS efi_main (EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {
    InitializeLib(ImageHandle, SystemTable);

    EFI_STATUS status;

    status = SystemTable->ConOut->ClearScreen(SystemTable->ConOut);
    check_efi_error(status, L"Failed to clear the screen");

    Print(L"[INFO] Stelox-UEFI v0.0.1 loaded!\r\n");

    UINT64 timeout_seconds = 10;
    EFI_INPUT_KEY key = { 0 };

    Print(L"Continuing in %llu...\n\rPress any key to stop the timer, press 'd' to enter debug mode, or press 'c' to immediately boot into the selected OS.\r\n", timeout_seconds);

    while(timeout_seconds)
    {
        status = WaitForSingleEvent(SystemTable->ConIn->WaitForKey, 10000000);
        if(status != EFI_TIMEOUT)
        {
            status = SystemTable->ConIn->ReadKeyStroke(SystemTable->ConIn, &key);
            check_efi_error(status, L"Failed to read from the input buffer");

            if(key.UnicodeChar == L'd')
            {
                Print(L"[INFO] Loading debug mode...\r\n");
                break;
            }
            else
            if(key.UnicodeChar == L'c')
            {
                Print(L"[INFO] Loading OS...\r\n");
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
        Print(L"[INFO] Loading OS...\r\n");
    }

    return EFI_SUCCESS;
}