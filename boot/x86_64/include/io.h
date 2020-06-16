#ifndef __UEFI_IO_H_
#define __UEFI_IO_H_

#include <efi.h>

inline void outb(UINT16 port, UINT8 val)
{
    asm volatile ("outb %0, %1" : : "a"(val), "Nd"(port));
}

inline void outw(UINT16 port, UINT16 val)
{
    asm volatile ("outw %0, %1" : : "a"(val), "Nd"(port));
}

inline UINT8 inb(UINT16 port)
{
    UINT8 ret = 0;

    asm volatile ("inb %1, %0" : "=a"(ret) : "Nd"(port));

    return ret;
}

inline UINT16 inw(UINT16 port)
{
    UINT16 ret = 0;

    asm volatile ("inw %1, %0" : "=a"(ret) : "Nd"(port));

    return ret;
}

extern void *memcpy(void *restrict dest, const void *restrict src, INT64 length);

BOOLEAN strcmp(CONST CHAR8 s0[], CONST CHAR8 s1[], UINT8 length)
{
    for(UINT8 i = 0; i < length; i++)
    {
        if(s0[i] != s1[i])
            return FALSE;
    }

    return TRUE;
}

void PrintString(CHAR8 *str)
{
    while(*str)
    {
        Print(L"%s", (CONST UINT16[]) {*str, 0x0});

        str++;
    }
}

#endif