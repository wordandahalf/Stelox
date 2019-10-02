BITS 16

jmp 0x0:main

address  equ 0x0500

reset_disk:
    mov     ah, 0x0
    mov     dl, 0x0

    int     0x13

    jc      reset_disk
    jmp     .done
.done:
    ret

read_disk:
    mov     ah, 0x02

    int     0x13

    cmp     ah, 0x0
    jmp     .done

    cmp     ah, 0x80
    jmp     .try_again
.try_again:
    pusha
    call    reset_disk
    popa

    jmp     read_disk
.done:
    ret

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

    call    reset_disk                  ; Reset the floppy to the first sector

    mov     al, 0x2                     ; Read two sectors
    mov     ch, 0x0                     ; from from the first cylinder
    mov     cl, 0x2                     ; starting at the second sector
    mov     dh, 0x0                     ; on the first head
    mov     dl, 0x0                     ; on the first drive

    mov     bx, address                 ; Load it at 0x0000:0x0500

    call    read_disk

    jmp     0x0000:address

    cli
    hlt

TIMES 510-($-$$) db 0
db 0x55
db 0xAA