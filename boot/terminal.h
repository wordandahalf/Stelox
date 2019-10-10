#ifndef __TERMINAL_H_
#define __TERMINAL_H_

#include <stdint.h>
#include <stdbool.h>
#include "io.h"

typedef struct {
    unsigned short *buffer;

    int selected_row;
    int selected_column;

    const int width;
    const int height;
} Terminal;

Terminal terminal = {
    .buffer = (unsigned short*)0xB8000,

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

void put_char(uint8_t ch)
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
    
    terminal.buffer[terminal.selected_column + (terminal.selected_row * terminal.width)] = create_vga_character(ch, create_vga_color(0xF, 0x0));

    update_cursor(terminal);
}

void put_string(char *str)
{
    for(int i = 0; str[i]; i++)
        put_char(str[i]);
}

void put_hex(uint32_t hex, bool prefix)
{
    const uint8_t HEX_CHARS[] = {'0','1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D','E','F'};

    if(prefix)
        put_string("0x");

    if(hex == 0)
    {
        put_char('0');
        return;
    }

    bool not_leading = false;

    for(int shft = 28; shft > -4; shft -= 4)
    {
        uint8_t ch = (hex >> shft) & 0xF;

        if(ch > 0)
        {
            if(!not_leading)
                not_leading = true;

            put_char(HEX_CHARS[ch]);
        }
        else
        {
            if(not_leading)
                put_char('0');
        }
    }
}

#endif