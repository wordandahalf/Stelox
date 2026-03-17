const std = @import("std");
const uefi = std.os.uefi;

const mb2 = @import("lib").mb2;
const Console = @import("console.zig");
const ceilDiv = @import("utils.zig").ceilDiv;

const State = struct {
    alloc: std.mem.Allocator,
    bs: *uefi.tables.BootServices,
    con: *Console,
    mode: ?*uefi.protocol.GraphicsOutput.Mode.Info,
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
        .framebuffer => {
            const fb: *mb2.header_tag_framebuffer = @ptrCast(tag);
            const gop = try bs.locateProtocol(uefi.protocol.GraphicsOutput, null) orelse return;

            for (0..gop.mode.max_mode) |i| {
                const info = try gop.queryMode(@truncate(i));
                if (info.horizontal_resolution == fb.width and info.vertical_resolution == fb.height) {
                    state.mode = info;
                    try gop.setMode(@truncate(i));
                    break;
                }
            }
            try con.log(.info, "{x} {x}", .{ gop.mode.frame_buffer_base, gop.mode.frame_buffer_size });
        },
        .information_request => {
            const req: *mb2.header_tag_information_request = @ptrCast(tag);
            const requests = req.requests();

            try con.log(.info, "found information request header tag with {d} requests: {any}", .{ requests.len, requests });
        },
        else => {
            try con.log(.warn, "ignoring unsupported multiboot header tag {s}", .{ @tagName(tag.type) });
        }
    }
}

pub fn execute(alloc: std.mem.Allocator, con: *Console, header_offset: usize, entrypoint: usize) !noreturn {
    const header = try find_header(header_offset);
    const bs = uefi.system_table.boot_services.?;

    var state = State{
        .alloc = alloc,
        .bs = bs,
        .con = con,
        .mode = null,
    };

    const addr: usize = @intFromPtr(header);
    var off:  usize = @sizeOf(mb2.header);

    var tag: *mb2.header_tag = @ptrFromInt(addr + off);
    while (off < header.header_length and tag.type != .end) : (tag = @ptrFromInt(addr + off)) {
        try handle_header_tag(&state, tag);
        // all header tags must be aligned, but the size does not include any padding amount;
        // so, we must manually calculate by hand.
        off = ceilDiv(usize, off + tag.size, mb2.HEADER_ALIGN) * mb2.HEADER_ALIGN;
    }

    try con.log(.info, "exiting uefi environment and jumping to kernel", .{});
    var memory_descriptors: [64]uefi.tables.MemoryDescriptor = undefined;
    const memory_map = try bs.getMemoryMap(@ptrCast(&memory_descriptors));
    try bs.exitBootServices(uefi.handle, memory_map.info.key);

    asm volatile (
        \\ jmp *%[entry]
        :
        : [entry] "r" (entrypoint),
          [magic] "{rax}" (mb2.BOOTLOADER_MAGIC),
          [hdr]   "{rbx}" (@intFromPtr(header))
    );

    @panic("kernel entrypoint returned");
}
