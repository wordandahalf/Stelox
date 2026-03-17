const std = @import("std");
const console = @import("console.zig");

const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;
const VGA_SIZE = VGA_WIDTH * VGA_HEIGHT;

var g_row: usize = 0;
var g_column: usize = 0;
var g_color: Color = .init(.light_gray, .black);
var g_buffer = @as([*]volatile u16, @ptrFromInt(0xB8000));

pub const ColorType = enum(u4) {
    black = 0,
    blue = 1,
    green = 2,
    cyan = 3,
    red = 4,
    magenta = 5,
    brown = 6,
    light_gray = 7,
    dark_gray = 8,
    light_blue = 9,
    light_green = 10,
    light_cyan = 11,
    light_red = 12,
    light_magenta = 13,
    light_brown = 14,
    white = 15,
};

const Color = packed struct(u8) {
    fg: ColorType,
    bg: ColorType,

    pub fn init(fg: ColorType, bg: ColorType) Color {
        return .{ .fg = fg, .bg = bg };
    }

    /// Combine vga color and char. The upper byte will be color and lower byte will be character
    pub fn getVgaChar(self: Color, char: u8) u16 {
        return @as(u16, @as(u8, @bitCast(self))) << 8 | char;
    }
};

/// Initialize VGA
pub fn init() void {
    clear();
}

/// Set Color for VGA
pub fn setColor(fg: Color, bg: Color) void {
    g_color = Color.init(fg, bg);
}

/// Clear the screen
pub fn clear() void {
    @memset(g_buffer[0..VGA_SIZE], Color.getVgaChar(g_color, ' '));
}

/// Print character with color at specific position
pub fn printCharAt(char: u8, color: Color, x: usize, y: usize) void {
    const index = y * VGA_WIDTH + x;
    g_buffer[index] = color.getVgaChar(char);
}

/// INFO: Scrolling is left as an exercise for the reader
fn checkAndScroll() void {
    if (g_row == VGA_HEIGHT) {
        g_row = 0;
    }
}

/// Print character to the VGA
pub fn printChar(char: u8) void {
    switch (char) {
        '\n' => {
            g_column = 0;
            g_row += 1;
            checkAndScroll();
        },
        else => {
            printCharAt(char, g_color, g_column, g_row);
            g_column += 1;
            if (g_column == VGA_WIDTH) {
                g_column = 0;
                g_row += 1;
                checkAndScroll();
            }
        },
    }
}

/// Implementation of std.Io.Writer.vtable.drain function.
/// When flush is called or the writer buffer is full this function is called.
/// This function first writes all data of writer buffer after that it writes
/// the argument data in which the last element is written splat times.
fn drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) !usize {
    // the length of data must not be zero
    std.debug.assert(data.len != 0);

    var consumed: usize = 0;
    const pattern = data[data.len - 1];
    const splat_len = pattern.len * splat;

    // If buffer is not empty write it first
    if (w.end != 0) {
        printString(w.buffered());
        w.end = 0;
    }

    // Now write all data except last element
    for (data[0 .. data.len - 1]) |bytes| {
        printString(bytes);
        consumed += bytes.len;
    }

    // If out patter (i.e. last element of data) is non zero len then write splat times
    switch (pattern.len) {
        0 => {},
        else => {
            for (0..splat) |_| {
                printString(pattern);
            }
        },
    }
    // Now we have to return how many bytes we consumed from data
    consumed += splat_len;
    return consumed;
}

/// Returns std.Io.Writer implementation for this console
pub fn writer(buffer: []u8) std.Io.Writer {
    return .{
        .buffer = buffer,
        .end = 0,
        .vtable = &.{
            .drain = drain,
        },
    };
}

/// Print string to VGA
pub fn printString(str: []const u8) void {
    for (str) |char| {
        printChar(char);
    }
}

/// Print with standard zig format to VGA
pub fn print(comptime fmt: []const u8, args: anytype) void {
    var w = writer(&.{});
    w.print(fmt, args) catch return;
}
