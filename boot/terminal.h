#ifndef __TERMINAL_H_
#define __TERMINAL_H_

#include <stdint.h>
#include <stdbool.h>
#include <stdarg.h>

#include "io.h"

typedef struct {
    uint16_t *buffer;

    uint8_t current_color;
    uint8_t default_color;

    uint8_t selected_row;
    int8_t selected_column;

    const uint8_t width;
    const uint8_t height;
} Terminal;

Terminal terminal = {
    .buffer = (unsigned short*)0xB8000,

    .current_color = 0x0F,
    .default_color = 0x0F,

    .selected_row = 0,
    .selected_column = -1,

    .width = 80,
    .height = 25,
};

inline uint8_t create_vga_color(uint8_t foreground, uint8_t background)
{
    return foreground | background << 4;
}

inline uint16_t create_vga_character(uint8_t c, uint8_t color)
{
    return (short) c | (short) color << 8;
}

void terminal_init()
{
    terminal.buffer = (unsigned short*) 0xB8000;

    for(int i = 0; i < terminal.width * terminal.height; i++)
    {
        terminal.buffer[i] = create_vga_character(' ', create_vga_color(0xf,0x0));
    }

    terminal.buffer = (unsigned short*) 0xB8000;
}

void update_cursor(Terminal terminal)
{
    uint16_t position = (terminal.selected_row * terminal.width) + terminal.selected_column + 1;

    outb(0x03D4, 0x0F);
    outb(0x03D5, (uint8_t) (position & 0xFF));
    outb(0x03D4, 0x0E);
    outb(0x03D5, (uint8_t) ((position >> 8) & 0xFF));
}

void put_char(char ch)
{
    if(ch == '\n')
    {
        terminal.selected_column = -1;
        terminal.selected_row = (terminal.selected_row + 1) % terminal.height;
        return;
    }

    if(((terminal.selected_column + 1) == terminal.width))
        terminal.selected_row = (terminal.selected_row + 1) % terminal.height;

    terminal.selected_column = (terminal.selected_column + 1) % terminal.width;
    
    terminal.buffer[terminal.selected_column + (terminal.selected_row * terminal.width)] = create_vga_character(ch, terminal.current_color);

    update_cursor(terminal);
}

void put_string(char *str)
{
    for(int i = 0; str[i]; i++)
        put_char(str[i]);
}

char *itoa(int32_t value, char *result, uint8_t base)
{
    if(base < 2 || base > 36) { *result = '\0'; return result; }

    char *ptr = result, *ptr1 = result, tmp_char;
    int32_t tmp_value;

    do
    {
        tmp_value = value;
        value /= base;
        *ptr++ = "ZYXWVUTSRQPONMLKJIHGFEDCBA9876543210123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"[35 + (tmp_value - value * base)];
    } while(value);

    if(tmp_value < 0) *ptr++ = '-';
    *ptr-- = '\0';
    while(ptr1 < ptr)
    {
        tmp_char = *ptr;
        *ptr-- = *ptr1;
        *ptr1++ = tmp_char;
    }

    return result;
}

void put_int(int32_t value, uint8_t base)
{
    uint8_t number_of_digits = 0;
    uint32_t copy = value;

    while(copy > 0)
    {
        copy /= base;
        number_of_digits++;
    }

    char result[number_of_digits];
    put_string(itoa(value, result, base));
}

void printf(char *fmt, ...)
{
    va_list var; 
    va_start(var, fmt);

    for(int i = 0; fmt[i] != 0; i++)
    {
        // The format escape character
        if(fmt[i] == '%')
        {
            // Make sure there is a visible character following it (except delete, hopefully that doesn't bite me in the ass)
            if(fmt[i + 1] > 0x20)
            {
                switch(fmt[i + 1])
                {
                    case 'c':
                        put_char(va_arg(var, uint32_t) & 0xFF);
                        i++;
                        break;
                    case 'd':
                        put_int(va_arg(var, int32_t), 10);
                        i++;
                        break;
                    case 'x':
                        put_string("0x");
                        put_int(va_arg(var, int32_t), 16);
                        i++;
                        break;
                    case 's':
                        i++;
                        put_string(va_arg(var, char *));
                        break;
                    case 'b':
                        i++;
                        put_string(va_arg(var, int) > 0 ? "true" : "false");
                        break;
                    case '<':
                        i++;
                        terminal.current_color = va_arg(var, int);
                        break;
                    case '@':
                        i++;
                        terminal.current_color = terminal.default_color;
                        break;
                    default:
                        put_char('%');
                        break;
                }
            }
            else
            {
                put_char('%');
            }
        }
        else
        {
            put_char(fmt[i]);
        }
    }

    va_end(var);
    return;
}

#endif