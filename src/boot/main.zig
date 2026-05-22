const std = @import("std");
const utf16 = std.unicode.utf8ToUtf16LeStringLiteral;
const uefi = std.os.uefi;

const Console = @import("console.zig");
const iso9660 = @import("fs/iso9660.zig");
const elf = @import("exe/elf.zig");
const multiboot = @import("protoc/multiboot.zig");
const ceilDiv = @import("utils.zig").ceilDiv;

pub const PageSize = @typeInfo(uefi.Page).array.len;

fn hang() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    const con = uefi.system_table.con_out.?;
    con.setAttribute(.{ .background = .red, .foreground = .white }) catch unreachable;
    con.clearScreen() catch unreachable;

    _ = con.outputString(utf16("An error occurred whilst booting: \r\n\r\n")) catch unreachable;
    _ = con.outputString(std.unicode.utf8ToUtf16LeAllocZ(uefi.pool_allocator, msg) catch unreachable) catch unreachable;
    _ = con.outputString(utf16("\r\n\r\nStacktrace: \r\n<empty>")) catch unreachable;

    hang();
}

pub fn main() uefi.Error!void {
    boot() catch |err| {
        const con = uefi.system_table.con_out.?;
        _ = try con.outputString(utf16("Boot failed: "));
        _ = try con.outputString(
            std.unicode.utf8ToUtf16LeAllocZ(uefi.pool_allocator, @errorName(err)) catch unreachable
        );
        hang();
    };
}

pub fn load_kernel(alloc: std.mem.Allocator, bs: *uefi.tables.BootServices, con: *Console, filename: []const u8) !struct { usize, usize } {
    const handles = (try bs.locateHandleBuffer(.{ .by_protocol = &uefi.protocol.BlockIo.guid })).?;
    defer bs.freePool(@ptrCast(@alignCast(handles.ptr))) catch unreachable;

    // probe block devices for an iso1660 filesystem
    var device: ?*uefi.protocol.BlockIo = null;
    try con.log(.info, "found {d} block devices to probe", .{ handles.len });
    for (handles) |handle| {
        const io = (try bs.handleProtocol(uefi.protocol.BlockIo, handle)) orelse continue;
        if (io.media.logical_partition) continue;
        if (iso9660.probe(alloc, io)) device = io;
    }
    try con.log(.debug, "found prospective iso9660/ecma-119 fs", .{});

    if (device == null) return error.NoBootableDevice;

    // construct model of fs and search for kernel image
    const pvd = try iso9660.find_volume_descriptor(alloc, device.?, .primary);
    defer pvd.deinit(alloc);

    var path_table = try iso9660.load_path_table(alloc, device.?, pvd);
    defer path_table.deinit(alloc);

    const file = try iso9660.load_file(alloc, device.?, path_table, filename);
    defer alloc.free(file);

    try con.log(.debug, "located kernel image on fs", .{});

    // parse elf file and program headers
    const file_header = try elf.FileHeader.parse(file);
    if (file_header != .@"64" or file_header.@"64".@"type" != .executable) return error.BadKernelImage;
    const elf_header = file_header.@"64";

    const program_headers = try elf.ProgramHeaders.parse(file);
    if (program_headers != .@"64") return error.BadKernelImage;
    const elf_program_headers = program_headers.@"64";

    // find the page-aligned block of contiguous memory to allocate for the kernel
    var start_address: usize = 0; var end_address: usize = 0;
    for (elf_program_headers) |it| {
        if (it.type != .load) continue;
        if (start_address == 0 or it.vaddr < start_address) start_address = it.vaddr;
        if (end_address == 0 or it.vaddr + it.memsz > end_address) end_address = it.vaddr + it.memsz;
    }
    start_address = (start_address / PageSize) * PageSize;
    end_address = ceilDiv(usize, end_address, PageSize) * PageSize;

    // todo: this is a hack, really I need to construct the section table and look at the entries,
    // todo: but this will suffice for now.
    var header_address: usize = 0;

    // allocate memory for the kernel and copy the segments into it
    const mem: []u8 align(PageSize) = @ptrCast(try bs.allocatePages(.{ .address = @ptrFromInt(start_address) }, .boot_services_data, (end_address - start_address) / PageSize));
    @memset(mem, 0);
    for (elf_program_headers) |it| {
        if (it.type != .load) continue;
        if (it.flags.execute and header_address == 0) header_address = it.paddr;
        @memcpy(mem[it.paddr - start_address..it.paddr - start_address + it.filesz], file[it.offset .. it.offset + it.filesz]);
    }

    try con.log(.info, "loaded kernel, entrypoint at 0x{x}", .{ elf_header.entry });
    return .{ header_address, elf_header.entry };
}

pub fn boot() !void {
    const alloc = uefi.pool_allocator;
    const bs = uefi.system_table.boot_services.?;

    var con = Console.init(alloc, uefi.system_table.con_out.?);
    try con.reset();

    const header_address, const entry = try load_kernel(alloc, bs, &con, "KERNEL/KERNEL64.ELF");
    try multiboot.execute(alloc, &con, header_address, entry);
}
