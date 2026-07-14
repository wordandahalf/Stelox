const std = @import("std");
const uefi = std.os.uefi;

const lib = @import("lib");
const mb2 = lib.mb2;
const Console = @import("../console.zig");
const utils = lib.utils;

const State = struct {
    // global state
    alloc: std.mem.Allocator,
    bs: *uefi.tables.BootServices,
    con: *Console,

    info_header_tail: [*]u8,

    framebuffer: ?*uefi.protocol.GraphicsOutput.Mode.Info,
    terminate_boot_services: bool = true,
};

fn find_header(address: usize) !*mb2.header {
    const ptr: [*]u32 = @ptrFromInt(address);

    var offset: u16 = 0;
    while (offset < mb2.SEARCH) : (offset += (mb2.HEADER_ALIGN / @sizeOf(u32))) {
        if (ptr[offset] == mb2.HEADER_MAGIC) {
            const header: *mb2.header = @ptrCast(ptr + offset);
            const checksum = header.magic +% header.architecture +% header.header_length;
            if ((checksum +% header.checksum) != 0) return error.InvalidMultibootChecksum;
            return header;
        }
    }

    return error.NoMultibootHeaderFound;
}

fn handle_header_tag(state: *State, tag: *mb2.header_tag) !void {
    const con = state.con;
    const bs = state.bs;

    switch (tag.type) {
        .console_flags => {
            const cf: *mb2.header_tag_console_flags = @ptrCast(tag);
            if (cf.console_flags.console_required and cf.console_flags.ega_text_supported) {
                try con.log(.warn, "requested EGA text mode is unsupported.", .{});
            }
        },
        .module_align => {
            // do nothing; we only use the EFI page allocator, so all modules will be page-aligned by default
        },
        .efi_bs => {
            state.terminate_boot_services = false;
        },
        .framebuffer => {
            const fb: *mb2.header_tag_framebuffer = @ptrCast(tag);
            const gop = try bs.locateProtocol(uefi.protocol.GraphicsOutput, null) orelse return;

            for (0..gop.mode.max_mode) |i| {
                const info = try gop.queryMode(@truncate(i));
                if (info.horizontal_resolution == fb.width and info.vertical_resolution == fb.height) {
                    state.framebuffer = info;
                    try gop.setMode(@truncate(i));
                    break;
                }
            }

            const mode = gop.mode;
            utils.copyAndIncrement(mb2.tag_framebuffer, &state.info_header_tail, .{
                .size = @sizeOf(mb2.tag_framebuffer) + @sizeOf(mb2.tag_framebuffer.info),
                .addr = mode.frame_buffer_base,
                .pitch = @truncate(mode.frame_buffer_size / mode.info.vertical_resolution),
                .width = mode.info.horizontal_resolution,
                .height = mode.info.vertical_resolution,
                .bpp = 24,
                .fb_type = .rgb,
            });
            utils.copyAndIncrement(mb2.tag_framebuffer.info, &state.info_header_tail, .{ .rgb = .{
                .red_field_position = 0,
                .red_mask_size = 8,
                .green_field_position = 8,
                .green_mask_size = 8,
                .blue_field_position = 16,
                .blue_mask_size = 8,
            } });
        },
        else => {
            try con.log(.warn, "ignoring unsupported multiboot header tag '{s}'", .{@tagName(tag.type)});
        },
    }
}

pub fn execute(alloc: std.mem.Allocator, con: *Console, header_offset: usize, entrypoint: usize) !noreturn {
    const header = try find_header(header_offset);
    const bs = uefi.system_table.boot_services.?;

    // naively assume we can fit all our information in one page
    const info_header_head = @intFromPtr((try bs.allocatePages(.any, .boot_services_data, 1)).ptr);

    var state = State{
        .alloc = alloc,
        .bs = bs,
        .con = con,
        .info_header_tail = @ptrFromInt(info_header_head + @sizeOf(mb2.fixed_info_tag)),
        .framebuffer = null,
    };

    const addr: usize = @intFromPtr(header);
    var off: usize = @sizeOf(mb2.header);

    var tag: *mb2.header_tag = @ptrFromInt(addr + off);
    while (off < header.header_length and tag.type != .end) : (tag = @ptrFromInt(addr + off)) {
        try handle_header_tag(&state, tag);
        // all header tags must be aligned, but the size does not include any padding amount;
        // so, we must manually calculate by hand.
        off = utils.ceilDiv(usize, off + tag.size, mb2.HEADER_ALIGN) * mb2.HEADER_ALIGN;
    }

    // write info length at the head
    @as([*]u32, @ptrFromInt(info_header_head))[0] = @truncate(@intFromPtr(state.info_header_tail) - info_header_head);

    try con.log(.info, "exiting uefi environment and jumping to kernel", .{});
    var memory_descriptors: [64]uefi.tables.MemoryDescriptor = undefined;
    const memory_map = try bs.getMemoryMap(@ptrCast(&memory_descriptors));

    if (state.terminate_boot_services)
        try bs.exitBootServices(uefi.handle, memory_map.info.key);

    asm volatile (
        \\ jmp *%[entry]
        :
        : [entry] "r" (entrypoint),
          [magic] "{rax}" (mb2.BOOTLOADER_MAGIC),
          [hdr] "{rbx}" (info_header_head),
    );

    @panic("kernel entrypoint returned");
}
