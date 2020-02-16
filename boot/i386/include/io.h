#ifndef __IO_H_
#define __IO_H_

inline void outb(uint16_t port, uint8_t val)
{
    asm volatile ("outb %0, %1" : : "a"(val), "Nd"(port));
}

inline void outw(uint16_t port, uint16_t val)
{
    asm volatile ("outw %0, %1" : : "a"(val), "Nd"(port));
}

inline void outl(uint16_t port, uint32_t val)
{
    asm volatile ("outl %0, %1" : : "a"(val), "Nd"(port));
}

inline uint8_t inb(uint16_t port)
{
    uint8_t ret = 0;

    asm volatile ("inb %1, %0" : "=a"(ret) : "Nd"(port));

    return ret;
}

inline uint16_t inw(uint16_t port)
{
    uint16_t ret = 0;

    asm volatile ("inw %1, %0" : "=a"(ret) : "Nd"(port));

    return ret;
}

inline uint32_t inl(uint16_t port)
{
    uint32_t ret = 0;

    asm volatile ("inl %i, %0" : "=a"(ret) : "Nd"(port));

    return ret;
}

inline void *memcpy(void *restrict dest, const void *restrict src, long length)
{
    asm volatile (
        "cld; rep movsb"
        : "=c"((int){0})
        : "D"(dest), "S"(src), "c"(length)
        : "flags", "memory"
    );

    return dest;
}

#endif