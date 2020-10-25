#ifndef __ISO9660_IMPL_H_
#define __ISO9660_IMPL_H_

#include "iso9660.h"
#include "types.h"

void iso9660_allocate_buffers(void)
{
    buffer = (uint8_t*)0x1000;
    name_buffer = (char*)0x900;
}

#endif