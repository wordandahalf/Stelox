#ifndef __IO_H_
#define __IO_H_

#include <stdint.h>

inline void outb(uint16_t port, uint8_t val)
{
    asm volatile ("outb %0, %1" : : "a"(val), "Nd"(port));
}

inline uint8_t inb(uint16_t port)
{
    uint8_t ret = 0;

    asm volatile ("inb %1, %0" : "=a"(ret) : "Nd"(port));

    return ret;
}

inline void inportsm(uint16_t port, uint8_t *data, uint64_t size) {
	asm volatile ("rep insw" : "+D" (data), "+c" (size) : "d" (port) : "memory");
}

inline void outportsm(uint16_t port, uint8_t *data, uint64_t size) {
	asm volatile ("rep outsw" : "+S" (data), "+c" (size) : "d" (port));
}

#endif