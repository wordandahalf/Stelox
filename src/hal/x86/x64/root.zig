const lib = @import("lib");
const x86 = lib.platform.x86;

pub const Serial = x86.periph.Serial;

const systemTable = x86.tables.systemTable;
const gdt = x86.x32.gdt;

var Gdt = systemTable("lgdt", [_]gdt.Descriptor{
    gdt.null_descriptor,
    gdt.segmentDescriptor(0xFFFFF, 0, @bitCast(@as(u8, 0x9a)), @bitCast(@as(u4, 0xa))),
    gdt.segmentDescriptor(0xFFFFF, 0, @bitCast(@as(u8, 0x92)), @bitCast(@as(u4, 0xc))),
    // TSS descriptor, filled in at runtime
    gdt.null_descriptor,
    gdt.null_descriptor,
});

pub fn init() void {
    Gdt.load();
    x86.x64.gdt.setSegments(0x08, 0x10);
}
