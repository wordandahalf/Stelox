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

; Maximum number of entries in the map
memory_map_length			equ 0x0200

; Location for the memory map
memory_map_location			equ 0x0500

; Layout of memory map (copied from memory_map.h):
; typedef struct
; {
;     uint8_t        length;
;     MemoryMapEntry  *entries;
; } MemoryMap;

memory_map_entry_size		equ 0x18

; Location for the memory map entry
memory_map_entry_location 	equ memory_map_location - memory_map_entry_size

; Layour of memory map entry (copied from memory_map.h):
; typedef struct
; {
;     uint64_t        base_address;
;     uint64_t        length;
;     uint32_t		  type;
;     uint32_t		  extended_attributes;
; } MemoryMapEntry;

; ----------------------------------------------------------------------------------
; Attempts to retrieve a memory map using INT 0x15, AX = 0xE820
;
; Return:
; CF set if service is not supported
; ----------------------------------------------------------------------------------
get_memory_map:
	; First, ensure the memory map struct is clear

	; Memory map struct is located at ES:EDI
	xor		ax, ax
	mov		es, ax
	mov		edi, memory_map_location

	; Clear it!
	push	edi
	mov		ecx, (1 + memory_map_length * memory_map_entry_size)
	rep		stosb			; Store AL in ES:EDI to ES:(EDI + ECX)
	pop		edi				; Restore the starting address

	; ES:ESI contains the address of the buffer to read new MemoryMapEntries into
	mov		esi, memory_map_entry_location

	; The interrupt expects the buffers to be swapped
	xchg	esi, edi

	xor 	ebx, ebx
.get_memory_map_entry:
	; EBX: 		0x0
	; ES:EDI: 	Segmented address of the location to read new memory map entries
	; ES:ESI: 	Segmented address of the location of the MemoryMap struct

	mov		eax, 0x0000E820		; Tell INT 0x15 to give us a memory map
	mov		edx, 0x534D4150		; 'SMAP', the interrupt checks for this value
	mov		ecx, 0x00000020
	int		0x15
	jnc		short .good_entry	; CF is clear if the interrupt

	; Carry being set indicates that the service is done--how many entries that were copied determines
	; whether the service worked or not.
	movzx	eax, byte [es:esi]	; Move Zero eXtend the word at memory_map_location (the number of entries read) into EAX
	sub		eax, 1				; Subtract 1 from EAX, setting the CF if EAX == 0
	ret 
.good_entry:
	; A valid entry CX bytes long was written to ES:EDI
	push	ebx
	mov		eax, [es:esi]					; Load the number of entries already retrieved into EAX
	mov		ecx, memory_map_entry_size		; Load the size of each entry into ECX
	mul		ecx								; EAX *= ECX; calculate the offset from the start of the MemoryMapEntry array to store the next entry

	mov		ebx, memory_map_location + 1	; Load EBX with the address of the start of the MemoryMapEntry array
	add		ebx, eax						; Add EBX to EAX, leaving EBX with the address to put the next MemoryMapEntry in the array
	
	mov		eax, [es:edi]					; Load EAX with the low dword of the base adress
	mov		[es:ebx], eax					; Copy into array
	mov		eax, [es:edi + 4]				; Load EAX with the high dword of the base adress
	mov		[es:ebx + 4], eax				; Copy into array

	mov		eax, [es:edi + 8]				; Load EAX with the low dword of the length
	mov		[es:ebx + 8], eax				; Copy into array
	mov		eax, [es:edi + 12]				; Load EAX with the high dword of the length
	mov		[es:ebx + 12], eax				; Copy into array

	mov		ax, [es:edi + 16]				; Load EAX with the type
	mov		[es:ebx + 16], ax				; Copy into array

	inc		byte [es:esi]					; Increment the number of retrieved entries
	pop		ebx
	or		ebx, ebx
	jnz		.get_memory_map_entry

	clc
	ret

%endif