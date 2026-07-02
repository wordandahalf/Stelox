const std = @import("std");
const uefi = std.os.uefi;

pub fn outputString(con: *uefi.protocol.SimpleTextOutput, comptime msg: []const u8) void {
    _ = con.outputString(std.unicode.utf8ToUtf16LeStringLiteral(msg)) catch unreachable;
}

pub fn outputStringAlloc(con: *uefi.protocol.SimpleTextOutput, msg: []const u8) void {
    const converted = std.unicode.utf8ToUtf16LeAllocZ(uefi.pool_allocator, msg) catch unreachable;
    _ = con.outputString(converted) catch unreachable;
}

pub fn outputStringFmtAlloc(con: *uefi.protocol.SimpleTextOutput, comptime fmt: []const u8, args: anytype) void {
    const formatted = std.fmt.allocPrint(uefi.pool_allocator, fmt, args) catch unreachable;
    const converted = std.unicode.utf8ToUtf16LeAllocZ(uefi.pool_allocator, formatted) catch unreachable;
    _ = con.outputString(converted) catch unreachable;
}
