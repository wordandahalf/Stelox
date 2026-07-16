//! A driver for a simple memory-mapped graphics adapter which uses a linear framebuffer

fb: [*]volatile u32,
width: u16,
height: u16,

const Self = @This();

pub fn init(address: usize, width: u16, height: u16) Self {
    return .{
        .fb = @ptrFromInt(address),
        .width = width,
        .height = height,
    };
}

pub fn set(self: Self, x: u16, y: u16, color: u32) void {
    self.fb[@as(usize, y) * self.width + x] = color;
}

pub fn fill(self: Self, x: u16, y: u16, width: u16, height: u16, color: u32) void {
    for (0..height) |it| {
        const offset = (@as(usize, y) + it) * self.width + x;
        @memset(self.fb[offset .. offset + width], color);
    }
}

pub fn clear(self: Self, color: u32) void {
    const length: usize = @as(usize, self.width) * self.height;
    @memset(self.fb[0..length], color);
}
