const std = @import("std");
const lib = @import("lib");
const x86 = lib.platform.x86;

const systemTable = x86.tables.systemTable;
const Gdt = x86.x32.Gdt;
const Idt = x86.x64.Idt;

const CodeDescriptorOffset = @import("gdt.zig").CodeDescriptorOffset;

// The first 32 gates are reserved for exceptions; those which have been assigned can be seen below
// in the Exception enumeration.
pub const ExceptionsCount = 32;
pub const ExceptionsGateOffset = 0;

// Then, we use 16 of the remaining 224 external interrupts.
pub const InterruptsCount = 16;
pub const InterruptsGateOffset = ExceptionsCount;

pub const GateCount = ExceptionsCount + InterruptsCount;

const Exception = enum(usize) {
    division = 0,
    debug = 1,
    nmi = 2,
    breakpoint = 3,
    overflow = 4,
    bound_range_exceeded = 5,
    invalid_opcode = 6,
    device_not_available = 7,
    double_fault = 8,
    coprocessor_segment_overrun = 9,
    invalid_tss = 10,
    segment_not_present = 11,
    stack_segment_fault = 12,
    general_protection_fault = 13,
    page_fault = 14,
    x87_fp = 16,
    alignment_check = 17,
    machine_check = 18,
    simd_fp = 19,
    virtualization = 20,
    control_protection = 21,
    hypervisor_injection = 28,
    vmm_communication = 29,
    security = 30,
    _,
};

pub const StackFrame = packed struct {
    // General purpose registers.
    r15: u64,
    r14: u64,
    r13: u64,
    r12: u64,
    r11: u64,
    r10: u64,
    r9: u64,
    r8: u64,
    rbp: u64,
    rdi: u64,
    rsi: u64,
    rdx: u64,
    rcx: u64,
    rbx: u64,
    rax: u64,

    // Interrupt vector number.
    interrupt_number: u64,
    // Associated error code, or 0.
    error_code: u64,

    // Registers pushed by the CPU when an interrupt is fired.
    rip: u64,
    cs: u64,
    rflags: u64,
    rsp: u64,
    ss: u64,
};

fn isrName(comptime gate: usize) []const u8 {
    return std.fmt.comptimePrint("isr_{d}", .{gate});
}

var interrupt_handlers = blk: {
    @setEvalBranchQuota(32768);
    var temp: [GateCount]Idt.ServiceRoutine = undefined;
    for (0..temp.len) |i| {
        temp[i] = @extern(
            Idt.ServiceRoutine,
            .{ .name = isrName(i) },
        );
    }
    break :blk temp;
};

fn interruptGate(index: usize, privilege: Gdt.PrivilegeLevel) Idt.Descriptor {
    return Idt.descriptor(
        // offset is set at runtime using the index
        index,
        CodeDescriptorOffset,
        .interrupt_word,
        privilege,
        1,
    );
}

fn interruptGates(offset: usize, length: usize, privilege: Gdt.PrivilegeLevel) [length]Idt.Descriptor {
    var gates: [length]Idt.Descriptor = undefined;
    for (0..gates.len) |i| {
        gates[i] = interruptGate(offset + i, privilege);
    }
    return gates;
}

/// Type of fn pointer called by ISR
const Handler = *const fn (stack: *StackFrame) callconv(.c) void;
export var isrs = [_]Handler{unhandledInterrupt} ** (256);

fn unhandledInterrupt(stack: *StackFrame) callconv(.c) void {
    // display some red to show that we're dead
    const framebuffer: [*]u32 = @ptrFromInt(0x80000000);
    @memset(framebuffer[0..0x0010_0000], 0xff0000);
    _ = stack;
    x86.halt();
}

fn handleDivByZero(stack: *StackFrame) callconv(.c) void {
    // display some red to show that we're dead
    const framebuffer: [*]u32 = @ptrFromInt(0x80000000);
    @memset(framebuffer[0..0x0010_0000], 0xffff00);
    _ = stack;
}

/// Type of fn pointer used for an IDT gate's ISR
const AsmHandler = *const fn () callconv(.naked) void;
fn createHandler(comptime i: usize) AsmHandler {
    return &struct {
        fn handler() callconv(.naked) void {
            @setEvalBranchQuota(65536);
            // x86.push(std.fmt.comptimePrint("${d}", .{i}));
            x86.pusha();
            asm volatile ("mov %rsp, %rdi");
            asm volatile (std.fmt.comptimePrint("call *(isrs + ({d}))", .{i}));
            x86.popa();
            asm volatile (
                \\ add $16, %rsp
                \\ iretq
            );
        }
        comptime {
            @export(&handler, .{ .name = isrName(i) });
        }
    }.handler;
}

comptime {
    for (0..256) |i| _ = createHandler(i);
}

var idt = systemTable(
    "lidt",
    // exceptions
    interruptGates(ExceptionsGateOffset, ExceptionsCount, 3) ++
        // interrupt requests
        interruptGates(InterruptsGateOffset, InterruptsCount, 3),
);

pub fn init() void {
    for (0..idt.entries.len) |i| {
        const offset = @intFromPtr(interrupt_handlers[i]);
        idt.entries[i].offset_low = @truncate(offset);
        idt.entries[i].offset_high = @truncate(offset >> 16);
    }
    isrs[0] = handleDivByZero;
    idt.load();
}
