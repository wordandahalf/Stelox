#ifndef __TERMINAL_H_
#define __TERMINAL_H_

#include <stdarg.h>

typedef enum {
    INFO,
    ERROR,
} TerminalLogType;

char *itoa_buffer;

void put_char(char ch);

// Initializes the terminal. Implementing method must allocate memory for the itoa buffer.
void terminal_init(void);

// Converts a foreground and background color into a single color.
inline uint8_t make_color(uint8_t foreground, uint8_t background)
{
    return foreground | background << 4;
}

// Outputs a string.
void put_string(char *str)
{
    for(int i = 0; str[i]; i++)
        put_char(str[i]);
}

// Converts an int with the provided properties to a string.
char *itoa(int64_t value, bool is_signed, uint8_t base, char *result)
{
    if(base < 2 || base > 36) { *result = '\0'; return result; }

    char *ptr = result, *ptr1 = result, tmp_char;

    if(is_signed)
    {
        int64_t tmp_value;

        do
        {
            tmp_value = value;
            value /= base;
            *ptr++ = "ZYXWVUTSRQPONMLKJIHGFEDCBA9876543210123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"[35 + (tmp_value - value * base)];
        } while(value && ((ptr - result) < 256)); // We don't want a buffer overflow--the buffer is 256 chars long

        if(tmp_value < 0) *ptr++ = '-';
    }
    else
    {
        uint64_t unsigned_value = value & 0xFFFFFFFF;
        uint64_t tmp_value;

        do
        {
            tmp_value = unsigned_value;
            unsigned_value /= base;
            *ptr++ = "ZYXWVUTSRQPONMLKJIHGFEDCBA9876543210123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"[35 + (tmp_value - unsigned_value * base)];
        } while(unsigned_value && ((ptr - result) < 256)); // We don't want a buffer overflow--the buffer is 256 chars long
    }
    
    *ptr-- = '\0';

    // This flips the chars; the previous few lines converts the int from most-significant digit to least
    while(ptr1 < ptr)
    {
        tmp_char = *ptr;
        *ptr-- = *ptr1;
        *ptr1++ = tmp_char;
    }

    return result;
}

// Outputs an int with the provided properties.
void put_int(int64_t value, bool is_signed, uint8_t base)
{
    put_string(itoa(value, is_signed, base, itoa_buffer));
}

// Implementation-specific vprintf function.
// Formatters include:
void vprintf(const char *fmt, va_list arg);

// Wrapper for vprintf.
void printf(char *fmt, ...)
{
    va_list var; 
    va_start(var, fmt);
    vprintf(fmt, var);
    va_end(var);
}

// Simple logging function with builtin styling and formatting.
void log(char *fmt, TerminalLogType type, ...)
{
    va_list var; 

    uint8_t type_foreground_color = 0x0;
    uint8_t text_foreground_color = 0xF;
    char    *text = "";
    
    switch(type)
    {
        case INFO:
            type_foreground_color = 0xD;
            text = "INFO";
            break;
        case ERROR:
            type_foreground_color = 0x4;
            text_foreground_color = 0xF;
            text = "ERR ";
    }
    
    printf("[%<%s%@] ", make_color(type_foreground_color, 0x0), text);

    printf("%<", make_color(text_foreground_color, 0x0));
    va_start(var, type);
    vprintf(fmt, var);
    va_end(var);
    printf("%@");

    put_char('\n');
}

#endif