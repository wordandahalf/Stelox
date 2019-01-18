[BITS 16]
[ORG 0x500]

jmp main

%include    "bios.inc"
%include    "a20.inc"
%include    "gdt.inc"

loading_message     db  "Loading...", 0xD, 0xA, 0x0

a20_message_worked  db  "The A20 was successfully enabled!", 0xD, 0xA, 0x0
a20_message_failed  db  "The A20 could not be enabled, please try restarting...", 0xD, 0xA, 0x0

entering_pmode      db  "Entering protected mode...", 0xD, 0xA, 0x0

main:
    mov     si, loading_message
    call    print_string

    call    enable_a20
    cmp     ax, 0x1                 ; The sub enable_a20 sets ax to 1 iff
    je      .a20_worked

    mov     si, a20_message_failed
    call    print_string

    cli
    hlt
.a20_worked:
    mov     si, a20_message_worked
    call    print_string

    mov     si, entering_pmode
    call    print_string

    jmp     enter_protected_mode

enter_protected_mode:
    cli

    xor     ax, ax
    mov     ds, ax                  ; The GDT is located at DS:gdtp

    lgdt    [gdtp]

    mov     eax, cr0
    or      al, 0x1
    mov     cr0, eax

    jmp 0x08:protected_mode_main    ; The GDT's code descriptor is 8 bytes from the offset

    hlt

[BITS 32]
protected_mode_main:
    mov     ax, 0x10                ; The GDT's data descriptor is 16 bytes from the offset
    mov     ds, ax
    mov     es, ax
    mov     fs, ax
    mov     gs, ax
    mov     ss, ax

    mov     esp, 0x90000

    mov     [0xB8000], byte 'P'
    mov     [0xB8001], byte 0x1B
hang:
    jmp     hang