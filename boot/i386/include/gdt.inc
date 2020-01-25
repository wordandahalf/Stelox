%ifndef _GDT_INC_
%define _GDT_INC_

gdt_start:
    ;; Null descriptor
    dd 0x0
    dd 0x0

    ;; Code descriptor
    dw 0xFFFF       ; First two bytes of the limit address
    dw 0x0000       ; First two bytes of the base address
    db 0x00         ; Third byte of the base address
    db 10011010b    ; Access byte
    db 11001111b    ; Next nibble of the limit followed by the flags
    db 0x00         ; The last byte of the base

    ;; Data descriptor
    dw 0xFFFF       ; First two bytes of the limit address
    dw 0x0000       ; First two bytes of the base address
    db 0x00         ; Third byte of the base address
    db 10010010b    ; Access byte
    db 11001111b    ; Next nibble of the limit followed by the flags
    db 0x00         ; The last byte of the base		
gdt_end:

gdtp:
    dw gdt_end - gdt_start - 1
    dd gdt_start

%endif