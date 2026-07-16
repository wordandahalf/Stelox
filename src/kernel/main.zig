const lib = @import("lib");

const video = lib.periph.video;
const Logger = @import("logger.zig");

const mb2 = lib.mb2;

const hal = @import("hal").x86.x64;
const init = @import("init/root.zig");

export var multiboot align(8) linksection(".multiboot") =
    mb2.create_header(.i386, .{
        mb2.header_tag_framebuffer{ .width = 1024, .height = 768, .depth = 24 },
        mb2.information_request(&[_]mb2.tag_type{.framebuffer}),
    });

export var stack_bytes: [16 * 1024]u8 align(16) linksection(".bss") = undefined;

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

noinline fn kmain(rax: usize, rbx: usize) callconv(.c) noreturn {
    var state: init.info.Platform = undefined;

    if (rax == mb2.BOOTLOADER_MAGIC) {
        state = init.mb2.run(@ptrFromInt(rbx)) catch unreachable;
    } else {
        while (true) asm volatile ("hlt");
    }

    const fb = video.Framebuffer.init(state.fb.address, state.fb.width, state.fb.height);
    var term = video.Terminal.init(fb, video.Terminal.DefaultFont, 128, 48, 0);
    fb.clear(0);

    var logger = Logger.init(&term);
    logger.log("stelox loaded", .info);

    while (true) asm volatile ("hlt");
}
