BITS 16

jmp 0x0:main

print_string:
    lodsb
    or      al, al
    jz      .done
    mov     ah, 0x0E
    int     0x10
    jmp     print_string
.done:
    ret

address  equ 0x500

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
    cli
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    mov     fs, ax
    mov     gs, ax

    mov     ax, 0x0000
    mov     ss, ax
    mov     sp, 0xFFFF
    sti

    call    reset_disk

    mov     al, 0x2
    mov     ch, 0x0
    mov     cl, 0x2
    mov     dh, 0x0
    mov     dl, 0x0

    mov     bx, address

    call    read_disk

    jmp     0x000:address

    cli
    hlt

TIMES 510-($-$$) db 0
db 0x55
db 0xAA