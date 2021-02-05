unsigned short *terminal_buffer = (unsigned short*) 0xB8000;

// Top-of-the-line print function
void prints(const char *msg)
{
    for(unsigned int i = 0; *msg; i++)
    {
        terminal_buffer[i] =  0x0F << 8 | *msg; // Color + character (little endian)
        msg++;
    }
}

extern "C"
void kernel_main(unsigned long magic, unsigned long address)
{
    if(magic != 0x36d76289) {
        prints("Was provided with an invalid MB2 magic!");
        for(;;);
    }

    prints("Hello, kernel!");

    for(;;);
}