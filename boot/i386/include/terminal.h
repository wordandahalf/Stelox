#ifndef __TERMINAL_H_
#define __TERMINAL_H_

typedef enum {
    TERMINAL_INFO_LOG,
    TERMINAL_ERROR_LOG,
} TerminalLogType;

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

    .current_color = 0x07,
    .default_color = 0x07,

    .selected_row = 0,
    .selected_column = -1,

    .width = 80,
    .height = 25,
};

char itoa_buffer[256];

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

void put_int(int64_t value, bool is_signed, uint8_t base)
{
    put_string(itoa(value, is_signed, base, itoa_buffer));
}

void vprintf(const char *fmt, va_list arg)
{
    // Hopefully no one passes a string with 64 thousand characters...
    for(uint16_t i = 0; fmt[i]; i++)
    {
        if(fmt[i] == '%')
        {
            switch(fmt[i + 1])
            {
                case 'd':
                    put_int(va_arg(arg, int32_t), true, 10);
                    i++;
                    break;
                case 'D':
                    put_int(va_arg(arg, int64_t), true, 10);
                    i++;
                    break;
                case 'u':
                    put_int(va_arg(arg, uint32_t), false, 10);
                    i++;
                    break;
                case 'U':
                    put_int(va_arg(arg, uint64_t), false, 10);
                    i++;
                    break;
                case 'x':
                    put_int(va_arg(arg, uint32_t), false, 16);
                    i++;
                    break;
                case 'X':
                    put_int(va_arg(arg, uint64_t), false, 16);
                    i++;
                    break;
                case 'c':
                    put_char(va_arg(arg, uint32_t));
                    i++;
                    break;
                case 's':
                    put_string(va_arg(arg, char*));
                    i++;
                    break;
                case 'b':
                    put_string(va_arg(arg, bool) == true ? "true" : "false");
                    i++;
                    break;
                case '<':
                    terminal.current_color = va_arg(arg, uint32_t);
                    i++;
                    break;
                case '@':
                    terminal.current_color = terminal.default_color;
                    i++;
                    break;
                default:
                    put_char('%');
                    break;
            }
        }
        else
        {
            put_char(fmt[i]);
        }
    }
}

void printf(char *fmt, ...)
{
    va_list var; 
    va_start(var, fmt);
    vprintf(fmt, var);
    va_end(var);
}

void log(char *fmt, TerminalLogType type, ...)
{
    va_list var; 

    uint8_t type_foreground_color = 0x0;
    uint8_t text_foreground_color = 0x7;
    char    *text = "";
    
    switch(type)
    {
        case TERMINAL_INFO_LOG:
            type_foreground_color = 0xD;
            text = "INFO";
            break;
        case TERMINAL_ERROR_LOG:
            type_foreground_color = 0x4;
            text_foreground_color = 0xF;
            text = "ERR ";
    }
    
    printf("[%<%s%@] ", create_vga_color(type_foreground_color, 0x0), text);

    printf("%<", create_vga_color(text_foreground_color, 0x0));
    va_start(var, type);
    vprintf(fmt, var);
    va_end(var);
    printf("%@");

    put_char('\n');
}

#endif