const gdt = @import("gdt.zig");

pub const Table = enum(u1) { gdt = 0, idt = 1 };

pub const GateType = enum(u4) {
    task = 0b010,
    interrupt_16 = 0b0110,
    trap_16 = 0b0111,
    interrupt_word = 0b1110,
    trap_word = 0b1111,
};

pub const Selector = packed struct(u16) {
    privilege: gdt.PrivilegeLevel,
    table: Table,
    index: u13,
};

pub const Descriptor = packed struct(u64) {
    offset_low: u16,
    selector: u16,
    _: u8 = 0,
    gate_type: GateType,
    __: u1 = 0,
    privilege: gdt.PrivilegeLevel,
    present: u1,
    offset_high: u16,

    pub fn offset(self: Descriptor) u32 {
        return (@as(u32, self.offset_high) << 16) | self.offset_low;
    }
};

pub fn descriptor(offset: u32, selector: u16, gate_type: GateType, privilege: gdt.PrivilegeLevel, present: u1) Descriptor {
    return .{
        .offset_low = @truncate(offset),
        .selector = selector,
        .gate_type = gate_type,
        .privilege = privilege,
        .present = present,
        .offset_high = @truncate(offset >> 16),
    };
}
