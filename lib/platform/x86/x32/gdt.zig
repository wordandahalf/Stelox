pub const PrivilegeLevel = u2;

pub const CodeDataAccess = packed struct(u8) {
    accessed: u1,
    rw: u1,
    dc: u1,
    executable: u1,
    system: u1 = 1,
    privilege: PrivilegeLevel,
    present: u1,
};

pub const SystemSegmentType = enum(u4) {
    /// 16-bit TSS, available
    task_segment_available_16 = 0x1,
    /// LDT for a particular task
    local_descriptor = 0x2,
    /// 16-bit TSS, busy
    task_segment_busy_16 = 0x3,
    // 32-/64-bit TSS, available
    task_segment_available_word = 0x9,
    // 32-/64-bit TSS, busy
    task_segment_busy_word = 0xb,
};

pub const SystemAccess = packed struct(u8) {
    type: SystemSegmentType,
    is_system: u1 = 0,
    privilege: PrivilegeLevel,
    present: u1,
};

pub const Access = packed union { codeData: CodeDataAccess, system: SystemAccess };

pub const SegmentSize = enum(u2) { @"16" = 0b00, @"32" = 0b10, @"64" = 0b01, _ };
pub const LimitGranularity = enum(u1) { byte = 0, page = 1 };

pub const Flags = packed struct(u4) {
    _: u1,
    size: SegmentSize,
    granularity: LimitGranularity,
};

pub const Descriptor = packed struct(u64) {
    limit_low: u16,
    base_low: u24,
    access: Access,
    limit_high: u4,
    flags: Flags,
    base_high: u8,

    /// Returns true if this is a system segment descriptor, defined by bit 4 of the access field being zero.
    pub fn isSystem(self: Descriptor) bool {
        return self.access.codeData.system == 0;
    }

    /// Returns the full 20-bit limit of this descriptor
    pub fn limit(self: Descriptor) u20 {
        return (@as(u20, self.limit_high) << 16) | self.limit_low;
    }

    // Returns the full 32-bit base of this descriptor
    pub fn base(self: Descriptor) u32 {
        return (@as(u32, self.base_high) << 24) | self.base_low;
    }
};

/// The null segment descriptor. Used as the zeroth entry in the GDT and can be used as a placeholder
/// for constructing 64-bit system segment descriptors.
pub const null_descriptor: Descriptor = @bitCast(@as(u64, 0));

/// Constructs a segment descriptor from the provided values.
pub fn segmentDescriptor(limit: u20, base: u32, access: CodeDataAccess, flags: Flags) Descriptor {
    return .{
        .limit_low = @truncate(limit),
        .base_low = @truncate(base),
        .access = .{ .codeData = access },
        .limit_high = @truncate(limit >> 16),
        .flags = flags,
        .base_high = @truncate(base >> 24),
    };
}

/// Constructs a system segment descriptor from the provided values.
pub fn systemSegmentDescriptor(limit: u20, base: u32, access: SystemAccess, flags: Flags) Descriptor {
    return .{
        .limit_low = @truncate(limit),
        .base_low = @truncate(base),
        .access = .{ .system = access },
        .limit_high = @truncate(limit >> 16),
        .flags = flags,
        .base_high = @truncate(base >> 24),
    };
}
