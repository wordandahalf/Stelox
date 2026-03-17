const std = @import("std");
const uefi = std.os.uefi;
const SimpleTextOutput = uefi.protocol.SimpleTextOutput;
const Allocator = std.mem.Allocator;

const Self = @This();

pub const LogLevel = enum {
    debug, info, warn, err
};

out: *uefi.protocol.SimpleTextOutput,
alloc: Allocator,

pub fn init(alloc: Allocator, out: *uefi.protocol.SimpleTextOutput) Self {
    return Self{ .out = out, .alloc = alloc };
}

pub fn reset(self: *Self) !void {
    try self.set_colors(.white, .black);
    try self.out.reset(true);
    try self.out.clearScreen();
}

pub fn set_colors(self: *Self, fg: SimpleTextOutput.Attribute.ForegroundColor, bg: SimpleTextOutput.Attribute.BackgroundColor) !void {
    try self.out.setAttribute(.{ .foreground = fg, .background = bg });
}

pub fn log(self: *Self, level: LogLevel, comptime fmt: []const u8, args: anytype) !void {
    const prefix = switch (level) {
        .debug => "DEBUG",
        .info => "INFO ",
        .warn => "WARN ",
        .err => "ERR  ",
    };
    const color = switch (level) {
        .debug => SimpleTextOutput.Attribute.ForegroundColor.lightmagenta,
        .info => SimpleTextOutput.Attribute.ForegroundColor.lightcyan,
        .warn => SimpleTextOutput.Attribute.ForegroundColor.yellow,
        .err => SimpleTextOutput.Attribute.ForegroundColor.red,
    };

    try self.print("[", .{});
    try self.set_colors(color, .black);
    try self.print("{s}", .{ prefix });
    try self.set_colors(.white, .black);
    try self.print("] ", .{});

    try self.println(fmt, args);
}

pub fn println(self: *Self, comptime fmt: []const u8, args: anytype) !void {
    try self.print(fmt, args);
    _ = try self.out.outputString(std.unicode.utf8ToUtf16LeStringLiteral("\r\n"));
}

pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) !void {
    const formatted = try std.fmt.allocPrint(self.alloc, fmt, args);
    defer self.alloc.free(formatted);

    const converted = try std.unicode.utf8ToUtf16LeAllocZ(self.alloc, formatted);
    defer self.alloc.free(converted);

    _ = try self.out.outputString(converted);
}
