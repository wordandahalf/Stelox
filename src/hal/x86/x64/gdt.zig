const std = @import("std");
const lib = @import("lib");
const x86 = lib.platform.x86;

pub const Serial = x86.periph.Serial;

const systemTable = x86.tables.systemTable;
const Gdt = x86.x32.Gdt;

// GDT offsets for our code and data descriptors
pub const CodeDescriptorOffset: u16 = 0x08;
pub const DataDescriptorOffset: u16 = 0x10;

var gdt = systemTable("lgdt", [_]Gdt.Descriptor{
    Gdt.null_descriptor,
    Gdt.segmentDescriptor(0xFFFFF, 0, @bitCast(@as(u8, 0x9a)), @bitCast(@as(u4, 0xa))),
    Gdt.segmentDescriptor(0xFFFFF, 0, @bitCast(@as(u8, 0x92)), @bitCast(@as(u4, 0xc))),
    // TSS descriptor, filled in at runtime
    Gdt.null_descriptor,
    Gdt.null_descriptor,
});

pub fn init() void {
    gdt.load();
    x86.x64.Gdt.setSegments(CodeDescriptorOffset, DataDescriptorOffset);
}
