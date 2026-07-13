const std = @import("std");

pub const x32 = @import("x32/root.zig");
pub const x64 = @import("x64/root.zig");

pub const periph = @import("periph/root.zig");
pub const io = @import("io.zig");
pub const tables = @import("tables.zig");

pub const GeneralPurposeRegisters = enum { rax, rbx, rcx, rdx, rsi, rdi, rbp, r9, r10, r11, r12, r13, r14, r15 };

/// Halts the processor
pub inline fn halt() noreturn {
    while (true) asm volatile ("hlt");
}

/// Push a value onto the stack
pub inline fn push(comptime reg: []const u8) void {
    asm volatile ("push " ++ reg);
}

/// Pop a value off of the stack
pub inline fn pop(comptime reg: []const u8) void {
    asm volatile ("pop " ++ reg);
}

/// Push all general-purpose registers onto the stack
pub inline fn pusha() void {
    inline for (comptime std.meta.fieldNames(GeneralPurposeRegisters)) |it| {
        push(std.fmt.comptimePrint("%{s}", .{it}));
    }
}

/// Pops all general-purpose registers from the stack
pub inline fn popa() void {
    const registers = comptime std.meta.fieldNames(GeneralPurposeRegisters);
    inline for (0..registers.len) |i| {
        pop(std.fmt.comptimePrint("%{s}", .{registers[registers.len - i - 1]}));
    }
}
