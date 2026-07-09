const gdt = @import("x32/gdt.zig");

/// On x86, system tables are loaded by passing the processor a 16-bit + pointer-sized register containing
/// one less the size of the table in bytes located at the provided address.
pub const SystemTablRegister = packed struct { limit: u16, base: usize };

/// Create an automatically loadable system table via the proivded instruction with the indicated array of entries.
pub fn SystemTable(comptime instr: []const u8, comptime entries: anytype) type {
    const T = @TypeOf(entries);

    const info = @typeInfo(T);
    if (info != .array or @typeInfo(info.array.child) != .@"struct") @compileError("SystemTable entries must be an array of structures");

    return struct {
        entries: T = entries,
        register: SystemTablRegister = undefined,

        const Self = @This();

        fn initRegister(self: *Self) void {
            // because the memory location of the entries cannot be comptime-known, we have to do this at runtime.
            // todo: strictly speaking, we should check that the table size is < 64k, but that is unlikely to happen by accident...
            self.register = .{ .base = @intFromPtr(&self.entries), .limit = @truncate(@sizeOf(T) - 1) };
        }

        /// Load the system table.
        pub inline fn load(self: *Self) void {
            self.initRegister();
            asm volatile (instr ++ " (%[reg])"
                :
                : [reg] "r" (&self.register),
            );
        }
    };
}

pub fn systemTable(comptime instr: []const u8, comptime entries: anytype) SystemTable(instr, entries) {
    return .{};
}
