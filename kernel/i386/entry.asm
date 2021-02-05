; The constants for the Multiboot 2 header
MAGIC			equ 0xE85250D6
ARCHITECTURE	equ	0x0
CHECKSUM		equ	-(MAGIC + ARCHITECTURE + HEADER_LENGTH)
HEADER_LENGTH	equ	multiboot_end - multiboot_start
 
; Declare a multiboot header that marks the program as a kernel. These are magic
; values that are documented in the multiboot standard. The bootloader will
; search for this signature in the first 8 KiB of the kernel file, aligned at a
; 32-bit boundary. The signature is in its own section so the header can be
; forced to be within the first 8 KiB of the kernel file.
section .multiboot
multiboot_start:
align 8
	dd 	MAGIC
	dd 	ARCHITECTURE
	dd 	HEADER_LENGTH
	dd 	CHECKSUM
	
	; MB2 tags are of the following format:
	; u16 type
	; u16 flags
	; u32 size
	;
	; They signal to the bootloader information to provide to the OS
	; or specific elements of the environment to set up.

	; Terminator tag
	dw	0x0
	dw	0x0
	dd	0x8
 multiboot_end:
; The multiboot standard does not define the value of the stack pointer register
; (esp) and it is up to the kernel to provide a stack. This allocates room for a
; small stack by creating a symbol at the bottom of it, then allocating 16384
; bytes for it, and finally creating a symbol at the top. The stack grows
; downwards on x86. The stack is in its own section so it can be marked nobits,
; which means the kernel file is smaller because it does not contain an
; uninitialized stack. The stack on x86 must be 16-byte aligned according to the
; System V ABI standard and de-facto extensions. The compiler will assume the
; stack is properly aligned and failure to align the stack will result in
; undefined behavior.
section .bss
align 16
stack_bottom:
resb 16384 ; 16 KiB
stack_top:
 
; The linker script specifies _start as the entry point to the kernel and the
; bootloader will jump to this position once the kernel has been loaded. It
; doesn't make sense to return from this function as the bootloader is gone.
; Declare _start as a function symbol with the given symbol size.
section .text
global start:function (start.end - start)
start:
    mov esp, stack_top
 
    ; Pass the parameters to kernel_main by pushing them on the stack,
    ; first parameter last.
    push ebx
    push eax

    extern kernel_main
    call kernel_main
 
    cli
.hang:	hlt
    jmp .hang
.end: