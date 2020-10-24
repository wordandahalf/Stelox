#ifndef __TYPES_H_
#define __TYPES_H_

#include <efibind.h>
#include <efidef.h>

typedef INT64 int64_t;
typedef UINT64 uint64_t;
typedef INT32 int32_t;
typedef UINT32 uint32_t;
typedef INT16 int16_t;
typedef UINT16 uint16_t;
typedef INT8 int8_t;
typedef UINT8 uint8_t;

typedef UINT64 uintptr_t;

typedef enum { false, true } bool;

bool strcmp(const char s0[], const char s1[], uint8_t length)
{
    for(int i = 0; i < length; i++)
    {
        if(s0[i] != s1[i])
            return false;
    }

    return true;
}

#endif