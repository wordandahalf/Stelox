%ifndef _BIOS_INC_
%define _BIOS_INC_

[BITS 16]

print_string:
    lodsb
    or      al, al
    jz      .done
    mov     ah, 0x0E
    int     0x10
    jmp     print_string
.done:
    ret

%endif