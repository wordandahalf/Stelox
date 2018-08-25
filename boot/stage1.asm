[BITS 16]
[ORG 0x500]

jmp main

%include    "bios.inc"

%include    "a20.inc"

loading_message     db  "Loading...", 0xD, 0xA, 0x0

a20_message_worked  db  "The A20 was successfully enabled!", 0xD, 0xA, 0x0

main:
    mov     si, loading_message
    call    print_string

    call    enable_a20
    cmp     ax, 0x1
    je      .a20_worked
    jmp     done

.a20_worked:
    mov     si, a20_message_worked
    call    print_string

done:
    cli
    hlt
