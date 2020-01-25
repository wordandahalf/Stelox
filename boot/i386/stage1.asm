BITS 16

jmp stage1

%include    "bios.inc"
%include    "a20.inc"
%include    "gdt.inc"

loading_message     db  "Loading...", 0xD, 0xA, 0x0

error_message  db  "Unrecoverable error, please try restarting...", 0xD, 0xA, 0x0

global stage1
stage1:
    mov     si, loading_message
    call    print_string

    call    enable_a20
    cmp     ax, 0x1                     ; The sub enable_a20 sets ax to 1 iff it successfully enabled the A20
    je      enter_protected_mode

    mov     si, error_message
    call    print_string

    cli
    hlt
enter_protected_mode:
    cli

    xor     eax, eax
    mov     ds, ax                      ; The GDT is located at DS:gdtp

    lgdt    [gdtp]

    mov     eax, cr0                    
    or      al, 0x1                     ; Set the protected mode bit of the control register
    mov     cr0, eax

    jmp 0x08:protected_mode_main        ; The GDT's code descriptor is 8 bytes from the offset

    hlt

BITS 32
extern loader_main
protected_mode_main:
    mov     ax, 0x10                    ; The GDT's data descriptor is 16 bytes from the offset
    mov     ds, ax
    mov     es, ax
    mov     fs, ax
    mov     gs, ax
    mov     ss, ax

    mov     esp, 0x90000

    jmp     loader_main                 ; Jump to the C loader
hang:
    jmp     hang