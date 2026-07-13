const lib = @import("lib");
const x86 = lib.platform.x86;

const gdt = @import("gdt.zig");
const interrupts = @import("interrupts.zig");

pub const Serial = x86.periph.Serial;

pub fn init() void {
    gdt.init();
    interrupts.init();
}
