#ifndef __MULTIBOOT2_H_
#define __MULTIBOOT2_H_

#include <stddef.h>

#include "types.h"
#include "terminal.h"
#include "multiboot2_tags.h"

enum multiboot_load_preference { NONE, LOWEST, HIGHEST };

// Contains the information about where and how to load the kernel.
struct multiboot_load_info {
    uintptr_t   header_address;     // Address of the kernel's MB2 header

    uintptr_t   min_load_address;   // Minimum address for the kernel to be loaded at
    uintptr_t   max_load_address;   // Maximum adddress for the kernel to be loaded at
    uint8_t     load_preference;    // Contains the preference of the kernel for where to load it
    uint32_t    load_alignment;     // Contains the byte alignment of the kernel

    uintptr_t   load_end_address;   // Address of the end of the data segment
    uintptr_t   bss_end_address;    // Address of the end of the BSS segment; initialize to 0 by the loader

    uintptr_t   entry_address;      // Address of the entry point of the kernel
};

struct multiboot_framebuffer_info {
    uint32_t    width;              // Width of the preferred graphics graphics mode
                                    // (pixels if depth != 0, chars if depth = 0)
    uint32_t    height;             // Height ""
    uint32_t    depth;              // Number of bits per pixel (value of 0 indicates text mode)
    bool        ega_support;        // Indicates the kernel supports EGA text mode
};

// load_size: file->size - offset or load_end_addr - load_addr
// start:   source + load_size
// end:     bss_end_addr - load_addr - load_size

// Contains the information necessary to load the kernel
// and provide the correct, expected environment.
struct multiboot_boot_state {
    uint32_t                           *requested_info;         // Contains a list of requested MBI
    struct multiboot_load_info          load_info;              // Contains information necessary to load the kernel
    bool                                modules_page_aligned;   // Indicates whether loaded modules should be page aligned
    bool                                supports_boot_services; // Indicates the kernel supports starting
                                                                // without the termination of the EFI boot services
    struct multiboot_framebuffer_info   framebuffer_info;       // Contains information for setting the graphics environment
};

static struct multiboot_boot_state *boot_state;

/*
*   Returns a pointer to a Multiboot 2 header, if found; otherwise, it returns NULL.
*/
static struct multiboot_header *multiboot2_find_header(uintptr_t start_address)
{
    uint32_t *header_ptr = (uint32_t*) start_address;

    // As per section 3.1 of the specification, the header must be 8-byte aligned and within the first 32768 bytes of the image.
    for(uint16_t off = 0; off < MULTIBOOT_SEARCH; off += MULTIBOOT_HEADER_ALIGN)
    {
        // If the magic is found...
        if(*(header_ptr + off) == MULTIBOOT2_HEADER_MAGIC)
        {
            // ... then the checksum needs to be verified! See section 3.1.2.
            struct multiboot_header *header = (struct multiboot_header*) (header_ptr + off);
            uint32_t checksum = MULTIBOOT2_HEADER_MAGIC + header->architecture + header->header_length + header->checksum; 

            if(checksum == 0) {
                return header;
            } else {
                log("MB2 header failed checksum verification:", ERROR);
                log("checksum = 0x%x, should be 0x0.", ERROR, checksum);
                return NULL;
            }
        }
    }

    return NULL;
}

/*
*   Platform-dependent method for relinquishing control to the kernel.
*   Must comply with the relevant section in the MB2 spec (sections 3.2 - 3.5).
*/
static void multiboot2_call_kernel(uintptr_t kernel_address, uintptr_t mbi_struct);

/*
*   Parses the MB2 tags found following the kernel's header, returning a pointer to
*   the created MBI structure.
*/
static uintptr_t multiboot2_parse_tags(struct multiboot_boot_state *boot_state, uintptr_t start_address);

/*
*   Attempts to find a (valid) MB2 header starting at the provided address and execute it.
*   If a header is not found, it will simply jump to start_address.
*/
void multiboot2_boot(uintptr_t start_address) {
    struct multiboot_header *header = (struct multiboot_header*) multiboot2_find_header(start_address);
    uintptr_t kernel_address = start_address;

    if(header)
    {
        log("Found MB2 header!", INFO);
        kernel_address += header->header_length;
        
        // Parse image header...
        multiboot2_parse_tags(boot_state, (uintptr_t) header + sizeof(struct multiboot_header));

        // Collect necessary information and set up environment
        multiboot2_handle_tags(boot_state);

        // Call the kernel with the struct
        multiboot2_call_kernel(kernel_address, mbi_struct);
    }
    else
    {
        log("Did not find valid MB2 header...", INFO);
        asm volatile("jmp %0\n\t" : : "g" (kernel_address));
    }
}

static void multiboot2_parse_tags(struct multiboot_boot_state *state, uintptr_t start_address) {
    struct multiboot_header_tag *tag = (struct multiboot_header_tag*) start_address;
    for(; tag->type; tag = (struct multiboot_header_tag*) (start_address += tag->size)) {
        // Handle the 10 different tag types (spec sections 3.1.4 - 3.1.13)
        switch(tag->type) {
            // 3.1.4
            case MULTIBOOT_HEADER_TAG_INFORMATION_REQUEST:
            {
                struct multiboot_header_tag_information_request *information_request_tag = (struct multiboot_header_tag_information_request*) tag;
                state->requested_info = (uint32_t*) ((uintptr_t) information_request_tag + offsetof(struct multiboot_header_tag_information_request, requests));
                break;
            }
            // (3.1.5) Contains the information necessary to load non-ELF formatted kernels: the physical addresses
            // of the text, data, and bss segments of the kernel.
            case MULTIBOOT_HEADER_TAG_ADDRESS:
            {
                struct multiboot_header_tag_address *address_tag = (struct multiboot_header_tag_address*) tag;
                state->load_info.header_address     = address_tag->header_addr;
                state->load_info.max_load_address   = address_tag->load_addr;
                state->load_info.min_load_address   = address_tag->load_addr;
                state->load_info.load_end_address   = address_tag->load_end_addr;
                state->load_info.bss_end_address    = address_tag->bss_end_addr;
                break;
            }
            // (3.1.6) Contains the physical address to jump to in order to give control to the kernel.
            case MULTIBOOT_HEADER_TAG_ENTRY_ADDRESS:
            {
                struct multiboot_header_tag_entry_address *entry_address_tag = (struct multiboot_header_tag_entry_address*) tag;
                state->load_info.entry_address = entry_address_tag->entry_addr;
                break;
            }
            // (3.1.7) Contains the physical address to jump to in order to give control to the kernel--when
            // running on a EFI i386 platform. Since Stelox does not support EFI i386 (it supports BIOS booting on i386),
            // this tag is always ignored. 
            case MULTIBOOT_HEADER_TAG_ENTRY_ADDRESS_EFI32:
            {
                struct multiboot_header_tag_entry_address *entry_address_efi32_tag = (struct multiboot_header_tag_entry_address*) tag;
                state->load_info.entry_address = entry_address_efi32_tag->entry_addr;
                break;
            }
            // (3.1.8) Contains the physical address to jump to in order to give control to the kernel--when
            // running on a EFI amd64 platform.
            case MULTIBOOT_HEADER_TAG_ENTRY_ADDRESS_EFI64:
            {
                struct multiboot_header_tag_entry_address *entry_address_efi64_tag = (struct multiboot_header_tag_entry_address*) tag;
                state->load_info.entry_address = entry_address_efi64_tag->entry_addr;
                break;
            }
            // (3.1.9) Indicates whether the preferred graphics mode is required or if the kernel supports EGA text mode.
            case MULTIBOOT_HEADER_TAG_CONSOLE_FLAGS:
            {
                struct multiboot_header_tag_console_flags *console_flags_tag = (struct multiboot_header_tag_console_flags*) tag;
                // TODO: Bit 0 indicates required console support...
                state->framebuffer_info.ega_support = console_flags_tag->console_flags & 0x2;
                break;
            }
            // (3.1.10) Specifies the kernel's preferred graphics mode.
            case MULTIBOOT_HEADER_TAG_FRAMEBUFFER:
            {
                struct multiboot_header_tag_framebuffer *framebuffer_tag = (struct multiboot_header_tag_framebuffer*) tag;
                state->framebuffer_info.width   = framebuffer_tag->width;
                state->framebuffer_info.height  = framebuffer_tag->height;
                state->framebuffer_info.depth   = framebuffer_tag->depth;
                break;
            }
            // (3.1.11) Indicates that modules must be page aligned.
            case MULTIBOOT_HEADER_TAG_MODULE_ALIGN:
                state->modules_page_aligned = true;
                break;
            // (3.1.12) Indicates that the kernel supports starting without the termination of EFI boot services.
            case MULTIBOOT_HEADER_TAG_EFI_BS:
                state->supports_boot_services = true;
                break;
            // (3.1.13) Indicates that the kernel is relocatable and provides the information necessary to perform the relocation.
            case MULTIBOOT_HEADER_TAG_RELOCATABLE:
            {
                struct multiboot_header_tag_relocatable *relocatable_tag = (struct multiboot_header_tag_relocatable*) tag;
                state->load_info.max_load_address   = relocatable_tag->max_addr;
                state->load_info.min_load_address   = relocatable_tag->min_addr;
                state->load_info.load_alignment     = relocatable_tag->align;
                state->load_info.load_preference    = relocatable_tag->preference;
                break;
            }
        }
    }
}

static void multiboot2_set_framebuffer(struct multiboot_framebuffer_info *info);

static void multiboot2_handle_tags(struct multiboot_boot_state *state) {
    // Set framebuffer
    uint8_t state = multiboot2_set_framebuffer(state->framebuffer_info);
    if(state != 0)
        log("Could not apply the requested framebuffer: %d.", ERROR, state);
}

#endif