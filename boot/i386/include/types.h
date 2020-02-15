#ifndef __TYPES_H_
#define __TYPES_H_

typedef signed long long int64_t;
typedef unsigned long long uint64_t;
typedef signed int int32_t;
typedef unsigned int uint32_t;
typedef unsigned short uint16_t;
typedef signed short int16_t;
typedef unsigned char uint8_t;
typedef signed char int8_t;
typedef unsigned long uintptr_t;

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

#define NULL (0)

#endif