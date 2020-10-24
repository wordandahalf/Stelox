#ifndef __TERMINAL_IMPL_
#define __TERMINAL_IMPL_

#include <efi.h>
#include <efilib.h>

#include "terminal.h"

#define ERR(s, m) if(EFI_ERROR(s)) log(m, ERROR);

void terminal_init(void)
{
    // Reset color
    uefi_call_wrapper(ST->ConOut->SetAttribute, 2, ST->ConOut, make_color(0x0F, 0x00));

    // Allocate memory for the itoa buffer
    EFI_STATUS Status = uefi_call_wrapper(ST->BootServices->AllocatePool, 3, EfiLoaderData, 0xFF, (void**)&itoa_buffer);
    ERR(Status, "There was an error allocating a pool for the itoa buffer!\r\n");
}

void put_char(char ch)
{
    // TODO: Debug and find the implementation
    Print(L"%c", ch);
}

void vprintf(const char *fmt, va_list arg)
{
    // Hopefully no one passes a string with 64 thousand characters...
    for(uint16_t i = 0; fmt[i]; i++)
    {
        if(fmt[i] == '%')
        {
            switch(fmt[i + 1])
            {
                case 'd':
                    put_int(va_arg(arg, int32_t), true, 10);
                    i++;
                    break;
                case 'D':
                    put_int(va_arg(arg, int64_t), true, 10);
                    i++;
                    break;
                case 'u':
                    put_int(va_arg(arg, uint32_t), false, 10);
                    i++;
                    break;
                case 'U':
                    put_int(va_arg(arg, uint64_t), false, 10);
                    i++;
                    break;
                case 'x':
                    put_int(va_arg(arg, uint32_t), false, 16);
                    i++;
                    break;
                case 'X':
                    put_int(va_arg(arg, uint64_t), false, 16);
                    i++;
                    break;
                case 'c':
                    put_char(va_arg(arg, uint32_t));
                    i++;
                    break;
                case 's':
                    put_string(va_arg(arg, char*));
                    i++;
                    break;
                case 'b':
                    put_string(va_arg(arg, bool) == true ? "true" : "false");
                    i++;
                    break;
                case '<':
                    // Set the color to the parameter
                    uefi_call_wrapper(ST->ConOut->SetAttribute, 2, ST->ConOut, va_arg(arg, uint32_t));
                    i++;
                    break;
                case '@':
                    // Reset color
                    uefi_call_wrapper(ST->ConOut->SetAttribute, 2, ST->ConOut, make_color(0x0F, 0x00));
                    i++;
                    break;
                default:
                    put_char('%');
                    break;
            }
        }
        else
        {
            put_char(fmt[i]);
        }
    }
}

#endif