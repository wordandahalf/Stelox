#ifndef __MEMORY_MAP_H_
#define __MEMORY_MAP_H_

#define             MEMORY_MAP_LOCATION 0x0500

typedef struct
{
    uint64_t        base_address;
    uint64_t        length;
    uint32_t        type;
    uint32_t        attributes;
} MemoryMapEntry;

typedef struct
{
    uint32_t        length;
    MemoryMapEntry  *entries;
} MemoryMap;

MemoryMap       memory_map;

static void memory_map_init()
{
    memory_map.length = ((uint32_t*) MEMORY_MAP_LOCATION)[0];
    memory_map.entries = (MemoryMapEntry*) (MEMORY_MAP_LOCATION + sizeof(memory_map.length));
}

#endif