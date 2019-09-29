unsigned char *terminal_buffer = (unsigned char*) 0xB8000;

void main(void)
{
    terminal_buffer[2] = 'r';
    terminal_buffer[3] = 0x1B;

    for(;;);
}