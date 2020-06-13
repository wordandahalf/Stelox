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


typedef enum { true, false } bool;

bool strcmp(const char s0[], const char s1[], UINT8 length)
{
    for(int i = 0; i < length; i++)
    {
        if(s0[i] != s1[i])
            return false;
    }

    return true;
}

#endif