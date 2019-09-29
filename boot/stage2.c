unsigned char *terminal_buffer = (unsigned char*) 0xB8000;

int main(void)
{
    terminal_buffer[0] = 'H';
    terminal_buffer[1] = 0x1B;

    terminal_buffer[2] = 'i';
    terminal_buffer[3] = 0x1B;

    terminal_buffer[4] = '!';
    terminal_buffer[5] = 0x1B;

    for(;;);

    return 0;
}