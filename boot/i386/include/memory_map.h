#ifndef __MEMORY_MAP_H_
#define __MEMORY_MAP_H_

#define             MEMORY_MAP_LOCATION 0x0500

typedef struct
{
    uint64_t        base_address;
    uint64_t        length;
    uint32_t        type;
    uint32_t        extended_attributes;
}__attribute__((packed)) MemoryMapEntry;

typedef struct
{
    uint8_t         length;
    MemoryMapEntry  *entries;
}__attribute__((packed)) MemoryMap;

MemoryMap memory_map;

static void memory_map_init()
{
    memory_map.length = ((uint32_t*) MEMORY_MAP_LOCATION)[0];
    memory_map.entries = (MemoryMapEntry*) (MEMORY_MAP_LOCATION + sizeof(memory_map.length));
}

#endif