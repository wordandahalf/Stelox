const Gdt = @import("lib").platform.x86.x32.Gdt;
const Idt = @import("lib").platform.x86.x32.Idt;

pub const Descriptor = packed struct(u128) {
    offset_low: u16,
    selector: u16,
    _: u8 = 0,
    gate_type: Idt.GateType,
    __: u1 = 0,
    privilege: Gdt.PrivilegeLevel,
    present: u1,
    offset_high: u48,
    ___: u32 = 0,

    pub fn offset(self: Descriptor) u64 {
        return (@as(u64, self.offset_high) << 16) | self.offset_low;
    }
};

pub fn descriptor(offset: u64, selector: u16, gate_type: Idt.GateType, privilege: Gdt.PrivilegeLevel, present: u1) Descriptor {
    return .{
        .offset_low = @truncate(offset),
        .selector = selector,
        .gate_type = gate_type,
        .privilege = privilege,
        .present = present,
        .offset_high = @truncate(offset >> 16),
    };
}

pub const ServiceRoutine = *const fn () callconv(.naked) void;
