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

static inline int create_vga_color(unsigned int foreground, unsigned int background)
{
    return foreground | background << 4;
}

static inline short create_vga_character(unsigned char c, unsigned int color)
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

static void putch(unsigned char ch)
{
    if(++terminal.selected_column == terminal.width)
    {
        terminal.selected_column = 0;

        if(++terminal.selected_row == terminal.height)
        {
            terminal.selected_row = 0;
        }
    }
    
    terminal.buffer[terminal.selected_column + (terminal.selected_row * terminal.width)] = create_vga_character(ch, create_vga_color(0xF, 0x0));
}

static void puts(char *str)
{
    for(int i = 0; str[i]; i++)
        putch(str[i]);
}

int kmain(void)
{
    terminal_init();

    puts("Welcome to Stelox v0.0.1!");

    for(;;);

    return 0;
}