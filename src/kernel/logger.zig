const lib = @import("lib");
const Terminal = lib.periph.video.Terminal;

pub const Level = enum(u2) { debug = 0, info, warn, @"error" };

const levelColor = [4]u32{ 0xff00ff, 0x00ffff, 0xffff00, 0xff0000 };
const levelText = [4][]const u8{ "DEBUG", "INFO ", "WARN ", "ERROR" };

const Self = @This();

t: *Terminal,

pub fn init(t: *Terminal) Self {
    return .{ .t = t };
}

pub fn log(self: *Self, msg: []const u8, level: Level) void {
    const fg = self.t.fg;
    self.t.fg = 0xffffff;
    self.t.write("[");
    self.t.fg = levelColor[@intFromEnum(level)];
    self.t.write(levelText[@intFromEnum(level)]);
    self.t.fg = 0xffffff;
    self.t.write("] ");
    self.t.fg = fg;

    self.t.write(msg);
    self.t.write("\r\n");
}
