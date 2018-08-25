%ifndef _A20_INC_
%define _A20_INC_

[BITS 16]

enable_a20:
    ;push    ax

    call    check_a20
    cmp     ax, 0x1
    je      .enable_a20_done

    call    enable_a20_bios
    call    check_a20
    cmp     ax, 0x1
    je      .enable_a20_done

    call    enable_a20_keyboard
    call    check_a20
    cmp     ax, 0x1
    je      .enable_a20_done

    call    enable_a20_fast
    call    check_a20
    cmp     ax, 0x1
    je      .enable_a20_done

    jmp     .enable_a20_failed
.enable_a20_done:
    mov     ax, 1
    ret
.enable_a20_failed:
    mov     ax, 0
    ret

enable_a20_bios:
    push    ax
    mov     ax, 0x2403
    int     0x15
    jb      .enable_a20_bios_done
    cmp     ah, 0x0
    jnz     .enable_a20_bios_done
    
    mov     ax, 0x2402
    int     0x15
    jb      .enable_a20_bios_done
    cmp     ah, 0x0
    jnz     .enable_a20_bios_done
    
    cmp     al, 0x1
    jz      .enable_a20_bios_done
    
    mov     ax, 0x2401
    int     0x15
    jb      .enable_a20_bios_done
    cmp     ah, 0x0
    jnz     .enable_a20_bios_done
.enable_a20_bios_done:
    pop     ax
    ret

enable_a20_keyboard:
    cli
 
    call    .enable_a20_keyboard_wait_2
    mov     al, 0xAD
    out     0x64, al
 
    call    .enable_a20_keyboard_wait_2
    mov     al, 0xD0
    out     0x64, al
 
    call    .enable_a20_keyboard_wait_1
    in      al,0x60
    push    eax
 
    call    .enable_a20_keyboard_wait_2
    mov     al, 0xD1
    out     0x64, al
 
    call    .enable_a20_keyboard_wait_2
    pop     eax
    or      al, 0x2
    out     0x60, al
 
    call    .enable_a20_keyboard_wait_2
    mov     al, 0xAE
    out     0x64, al
 
    call    .enable_a20_keyboard_wait_2
    sti
    ret
.enable_a20_keyboard_wait_2:
    in      al, 0x64
    test    al, 2
    jnz     .enable_a20_keyboard_wait_2
    ret
.enable_a20_keyboard_wait_1:
    in      al, 0x64
    test    al, 1
    jz      .enable_a20_keyboard_wait_1
    ret

enable_a20_fast:
    push    ax
    in      al, 0x92
    test    al, 0x2
    jnz     .enable_a20_fast_done
    or      al, 0x2
    and     al, 0xFE
    out     0x92, al
.enable_a20_fast_done:
    pop     ax
    ret

; Returns: 0 in ax if the a20 line is disabled (memory wraps around)
;          1 in ax if the a20 line is enabled (memory does not wrap around)
 
check_a20:
    pushf
    push ds
    push es
    push di
    push si
 
    cli
 
    xor ax, ax ; ax = 0
    mov es, ax
 
    not ax ; ax = 0xFFFF
    mov ds, ax
 
    mov di, 0x0500
    mov si, 0x0510
 
    mov al, byte [es:di]
    push ax
 
    mov al, byte [ds:si]
    push ax
 
    mov byte [es:di], 0x00
    mov byte [ds:si], 0xFF
 
    cmp byte [es:di], 0xFF
 
    pop ax
    mov byte [ds:si], al
 
    pop ax
    mov byte [es:di], al
 
    mov ax, 0
    je .check_a20_done
 
    mov ax, 1
.check_a20_done:
    pop si
    pop di
    pop es
    pop ds
    popf
 
    ret

%endif