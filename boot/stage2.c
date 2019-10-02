#include <stdint.h>
#include <stdbool.h>

struct Terminal {
    unsigned short *buffer;

    int selected_row;
    int selected_column;

    const int width;
    const int height;
};

struct Terminal terminal = {
    .buffer = (unsigned short*)0xB8000,

    .selected_row = 0,
    .selected_column = -1,

    .width = 80,
    .height = 25,
};

static inline uint8_t create_vga_color(uint8_t foreground, uint8_t background)
{
    return foreground | background << 4;
}

static inline uint16_t create_vga_character(uint8_t c, uint8_t color)
{
    return (short) c | (short) color << 8;
}

static void terminal_init()
{
    terminal.buffer = (unsigned short*) 0xB8000;

    for(int i = 0; i < terminal.width * terminal.height; i++)
    {
        terminal.buffer[i] = create_vga_character(' ', create_vga_color(0xf,0x0));
    }

    terminal.buffer = (unsigned short*) 0xB8000;
}

static void put_char(uint8_t ch)
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
}

static void put_string(char *str)
{
    for(int i = 0; str[i]; i++)
        put_char(str[i]);
}

static void put_hex(uint32_t hex, bool prefix)
{
    static const uint8_t HEX_CHARS[] = {'0','1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D','E','F'};

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

static inline void outb(uint16_t port, uint8_t val)
{
    asm volatile ("outb %0, %1" : : "a"(val), "Nd"(port));
}

static inline uint8_t inb(uint16_t port)
{
    unsigned char ret;

    asm volatile ("inb %1, %0" : "=a"(ret) : "Nd"(port));

    return ret;
}

static void read_sector(uint32_t lba, uint8_t sectors, uint8_t *buffer)
{
    uint8_t address = (uint8_t) ((lba >> 24) | 0b11100000);

    put_string("Reading ");
    put_hex(sectors, true);
    put_string(" sector(s) into ");
    put_hex((uint32_t) buffer, true);
    put_string(" from LBA ");
    put_hex(lba, true);
    put_string("...\n");

    outb(0x01F6, address); // Send bits 24-27 of the LBA for first sector
    outb(0x01F2, sectors); // Send number of sectors
    outb(0x01F3, (uint8_t) (lba & 0xF)); // Send bits 0-7 of the LBA
    outb(0x01F4, (uint8_t) ((lba >> 8) & 0xF)); // Send bits 8-15 of the LBA
    outb(0x01F5, (uint8_t) ((lba >> 16) & 0xF)); // Send bits 16-23 of the LBA

    outb(0x01F7, 0x20); // Command for read w/ retry

    put_string("Sent ATAPIO commands!\n");

    while((0x8 & inb(0x01F7)) == 0) {}

    put_string("ATA device ready!\n");

    for(int i = 0; i < 255 * sectors; i++)
    {
        //read word from port DX into address

        buffer[i] = inb(0x01F0);
    }

    put_string("Done reading.\n");

    /*
               mov rax, 256         ; to read 256 words = 1 sector
               xor bx, bx           ; bx = 0
               mov bl, cl           ; read CL sectors
               mul bx               ; dx:ax = ax * bx
               mov rcx, rax         ; RCX is counter for INSW
               mov rdx, 0x1F0       ; Data port, in and out
               rep insw             ; Input (E)CX words from port DX into ES:[(E)DI]
    */
}

int kmain(void)
{
    terminal_init();

    put_string("Welcome to Stelox v0.0.1!\n");

    read_sector(0, 1, (uint8_t*)0x7E00);

    for(;;);

    return 0;
}