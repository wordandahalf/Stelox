const mb2 = @import("lib").mb2;
const console = @import("console.zig");

export var multiboot align(8) linksection(".multiboot") =
    mb2.create_header(.i386, .{
        mb2.header_tag_framebuffer{
            .width = 1024, .height = 768, .depth = 24
        },
        mb2.information_request(&[_]mb2.tag_type{ .framebuffer }),
    });

export var stack_bytes: [16 * 1024]u8 align(16) linksection(".bss") = undefined;

// We specify that this function is "naked" to let the compiler know
// not to generate a standard function prologue and epilogue, since
// we don't have a stack yet.
export fn _start() callconv(.naked) noreturn {
    asm volatile (
        \\ movabs %[stack_top], %%rsp
        \\ xorq %%rbp, %%rbp
        \\ movq %%rax, %%rdi
        \\ movq %%rbx, %%rsi
        \\ call %[kmain:P]
        :
        : [stack_top] "i" (&@as([*]align(16) u8, @ptrCast(&stack_bytes))[stack_bytes.len]),
          [kmain] "X" (&kmain),
    );
}

// We use noinline to make sure it don't get inlined by compiler
noinline fn kmain(rax: usize, rbx: usize) callconv(.c) noreturn {
    if (rax == mb2.BOOTLOADER_MAGIC) {
        mb2_main(@ptrFromInt(rbx));
    }

    while (true) {
        asm volatile ("hlt");
    }
}

fn mb2_main(_: *mb2.fixed_info_tag) void {
    const framebuffer: [*]u32 = @ptrFromInt(0x80000000);
    @memset(framebuffer[0..10240], 0x00ff00);
}