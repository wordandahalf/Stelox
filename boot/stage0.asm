BITS 16

jmp 0x0:main

%include "bios.inc"

address  equ 0x0500

main:
    cli                                 ; Disable interrupts -- what we're about to do will trip one otherwise
    xor     ax, ax                      ; Clear all the segment registers
    mov     ds, ax
    mov     es, ax
    mov     fs, ax
    mov     gs, ax

    mov     ax, 0x0000                  ; Set up the stack
    mov     ss, ax
    mov     sp, 0xFFFF
    sti                                 ; Re-enable interrupts

    extern stage1
    jmp stage1

    cli
    hlt

TIMES 510-($-$$) db 0
db 0x55
db 0xAA