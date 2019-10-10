#include <stdint.h>
#include <stdbool.h>

#include "terminal.h"

int loader_main(void)
{
    terminal_init();

    put_string("Welcome to Stelox v0.0.1!\n");

    for(;;) {}

    return 0;
}