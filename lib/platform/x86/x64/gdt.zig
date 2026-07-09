const lib = @import("lib");
const gdt = lib.platform.x86.x32.gdt;
const NoPadding = lib.utils.NoPadding;

/// On x64_64 machines in long mode, the system descriptor is extended to allow for a full
/// 64-bit base
pub const SystemDescriptor = packed struct(u128) {
    limit_low: u16,
    base_low: u24,
    access: gdt.Access,
    limit_high: u4,
    flags: gdt.Flags,
    base_high: u40,
    _: u32 = 0,

    /// Returns true if this is a system segment descriptor, defined by bit 4 of the access field being zero.
    pub fn isSystem(self: SystemDescriptor) bool {
        return self.access.codeData.is_system == 0;
    }

    /// Returns the full 20-bit limit of this descriptor
    pub fn limit(self: SystemDescriptor) u20 {
        return (@as(u20, self.limit_high) << 16) | self.limit_low;
    }

    // Returns the full 64-bit base of this descriptor
    pub fn base(self: SystemDescriptor) u64 {
        return (@as(u32, self.base_high) << 24) | self.base_low;
    }
};

/// Constructs a segment descriptor from the provided values.
pub fn segmentDescriptor(limit: u20, base: u32, access: gdt.Access, flags: gdt.Flags) gdt.Descriptor {
    return gdt.segmentDescriptor(limit, base, access, flags);
}

/// Constructs a system segment descriptor from the provided values.
pub fn systemSegmentDescriptor(limit: u20, base: u64, access: gdt.SystemAccess, flags: gdt.Flags) SystemDescriptor {
    return .{
        .limit_low = @truncate(limit),
        .base_low = @truncate(base),
        .access = .{ .system = access },
        .limit_high = @truncate(limit >> 16),
        .flags = flags,
        .base_high = @truncate(base >> 24),
    };
}

pub fn setSegments(comptime code_offset: usize, comptime data_offset: usize) void {
    asm volatile (
        \\ push %[code_segment_offset]
        \\ lea 1f(%rip), %rax
        \\ push %rax
        \\ lretq
        \\
        \\ 1:
        \\     mov %[data_segment_offset], %ax
        \\     mov %ax, %ds
        \\     mov %ax, %es
        \\     mov %ax, %fs
        \\     mov %ax, %gs
        \\     mov %ax, %ss
        :
        : [code_segment_offset] "i" (code_offset),
          [data_segment_offset] "i" (data_offset),
        : .{ .rax = true, .memory = true });
}
