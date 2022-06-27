#ifndef __MULTIBOOT2_IMPL_H_
#define __MULTIBOOT2_IMPL_H_

#include "types.h"
#include "multiboot2.h"
#include "multiboot2_tags.h"

void multiboot2_call_kernel(uintptr_t kernel_address, uintptr_t mbi_struct)
{
  asm volatile(
    "mov %1, %%rax\n\t"
    "mov %2, %%rbx\n\t"
    "jmp *%0\n\t"
      :
      : "g" (kernel_address),
        "g" (MULTIBOOT2_BOOTLOADER_MAGIC),
        "g" (mbi_struct)
      : "rax", "rbx"
    );
}

void multiboot2_set_framebuffer(struct multiboot_framebuffer_info *info)
{
  if(EFI_ERROR(uefi_call_wrapper()))
}

#endif