const std = @import("std");

const Framebuffer = @import("framebuffer.zig");

const fontData = @embedFile("VGA8.F16");
pub const DefaultFont = BitmapFont.init(fontData, 256, 1);

pub const BitmapFont = struct {
    characters: []const u8,
    /// the number of characters in the font
    count: usize,
    /// the width of a character in bits
    width: u16,
    /// the height of character in bits
    height: u16,

    /// Create a bitmap font embedded in the provided file with count characters which are width bytes wide.
    pub fn init(comptime data: []const u8, comptime count: usize, comptime width: u16) BitmapFont {
        std.debug.assert(@mod(data.len, count) == 0);
        const bytesPerChar = data.len / count;
        const height: u16 = @truncate(bytesPerChar / width);

        return .{
            .characters = data,
            .count = count,
            .width = 8 * width,
            .height = height,
        };
    }

    /// Returns a row-major array of the character data at that index
    pub fn getChar(self: BitmapFont, index: usize) []const u8 {
        const bytesPerChar = (self.width >> 3) * self.height;
        const offset = index * bytesPerChar;
        return self.characters[offset .. offset + bytesPerChar];
    }
};

fb: Framebuffer,
font: BitmapFont,

width: u16,
height: u16,

charWidth: u16,
charHeight: u16,
charStride: u16,

x: u16 = 0,
y: u16 = 0,

fg: u32 = 0xffffff,
bg: u32 = 0x0,

const Self = @This();

/// Create a terminal with the provided framebuffer and font.
pub fn init(fb: Framebuffer, font: BitmapFont, width: u8, height: u8, stride: u16) Self {
    const charWidth: u16 = @truncate(@as(usize, fb.width) / width - stride);
    const charHeight = fb.height / height;

    return .{
        .fb = fb,
        .font = font,
        .width = width,
        .height = height,
        .charWidth = @truncate(charWidth),
        .charHeight = @truncate(charHeight),
        .charStride = stride,
    };
}

fn drawChar(self: Self, x: u16, y: u16, char: u8) void {
    const data = self.font.getChar(char);
    const stride = (self.font.width + 7) / 8;

    for (0..self.charHeight) |dy| {
        const src_y = (dy * self.font.height) / self.charHeight;
        const row = data[src_y * stride];
        for (0..self.charWidth) |dx| {
            const src_x = (dx * self.font.width) / self.charWidth;
            // const idx = src_x >> 3;
            const mask = @as(u8, 0x80) >> @as(u3, @truncate(src_x & 7));

            const ix: u16 = @truncate(x + dx);
            const iy: u16 = @truncate(y + dy);

            if (row & mask != 0) {
                self.fb.set(ix, iy, self.fg);
            } else {
                self.fb.set(ix, iy, self.bg);
            }
        }
    }
}

pub fn setPosition(self: *Self, x: u16, y: u16) void {
    self.x = x;
    self.y = y;
}

pub fn incrementPosition(self: *Self) void {
    if (self.x == self.width - 1) self.y = @mod(self.y + 1, self.height);
    self.x = @mod(self.x + 1, self.width);
}

pub fn putch(self: *Self, char: u8) void {
    switch (char) {
        '\n' => {
            self.setPosition(self.x, @mod(self.y + 1, self.height));
        },
        '\r' => {
            self.setPosition(0, self.y);
        },
        else => {
            self.drawChar(self.x * (self.charWidth + self.charStride) + self.charStride, self.y * self.charHeight, char);
            self.incrementPosition();
        },
    }
}

pub fn write(self: *Self, msg: []const u8) void {
    for (msg) |it| {
        self.putch(it);
    }
}
