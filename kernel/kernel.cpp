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
void kernel_main(void)
{
    prints("Hello, kernel!");

    for(;;);
}