const std = @import("std");
const lib = @import("lib");
const x86 = lib.platform.x86;

const systemTable = x86.tables.systemTable;
const Gdt = x86.x32.Gdt;
const Idt = x86.x64.Idt;

const CodeDescriptorOffset = @import("gdt.zig").CodeDescriptorOffset;

pub const GateType = enum { interrupt, trap, fault, abort, reserved };
pub const Gate = struct { mnemonic: ?[]const u8 = null, name: ?[]const u8 = null, type: GateType, error_code: bool = false };

/// A type of exception raised after an invalid operation is made (and rolled back) in which the return address points to
/// the faulting instruction.
fn fault(mnemonic: []const u8, name: []const u8, error_code: bool) Gate {
    return .{ .mnemonic = mnemonic, .name = name, .type = .fault, .error_code = error_code };
}

/// A type of recoverable exception in which the return address points to after the trapping instruction..
fn trap(mnemonic: []const u8, name: []const u8) Gate {
    return .{ .mnemonic = mnemonic, .name = name, .type = .trap };
}

/// A type of unrecoverable exception.
fn abort(mnemonic: []const u8, name: []const u8, error_code: bool) Gate {
    return .{ .mnemonic = mnemonic, .name = name, .type = .abort, .error_code = error_code };
}

fn interrupt() Gate {
    return .{ .type = .interrupt };
}

/// Indicates the corresponding gate should not be used.
fn reserved() Gate {
    return .{ .type = .reserved };
}

pub const Gates: [256]Gate = [32]Gate{
    fault("DE", "Divide Error", false),
    trap("DB", "Debug Exception"),
    interrupt(),
    trap("BP", "Breakpoint"),
    trap("OF", "Overflow"),
    fault("BR", "Bound Range Exceeded", false),
    fault("UD", "Undefined Opcode", false),
    fault("NM", "Device Not Available", false),
    abort("DF", "Double Fault", true),
    reserved(),
    fault("TS", "Invalid TSS", true),
    fault("NP", "Segment Not Present", true),
    fault("SS", "Stack Segment Fault", true),
    fault("GP", "General Protection Fault", true),
    fault("PF", "Page Fault", true),
    reserved(),
    fault("MF", "Math Fault", false),
    fault("AC", "Alignment Check", true),
    abort("MC", "Machine Check", false),
    fault("XM", "SIMD Floating-Point Exception", false),
    fault("VE", "Virtualization Exception", false),
    fault("CP", "Control Protection Exception", true),
    reserved(),
    reserved(),
    reserved(),
    reserved(),
    reserved(),
    reserved(),
    Gate{ .mnemonic = "HV", .name = "Hypervisor Injection Exception", .type = .interrupt, .error_code = false },
    fault("VC", "VMM Communication Exception", true),
    Gate{ .mnemonic = "SX", .name = "Security Exception", .type = .interrupt, .error_code = true },
    reserved(),
} ++ [_]Gate{interrupt()} ** 224;
pub const GateCount = Gates.len;

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

/// The array of internal service routines used to delegate to handlers
var serviceRoutines = blk: {
    @setEvalBranchQuota(65536);
    var handlers: [GateCount]Idt.ServiceRoutine = undefined;
    for (0..handlers.len) |i| {
        handlers[i] = createServiceRoutine(i);
    }
    break :blk handlers;
};

/// Type of fn pointer called by service routines
const Handler = *const fn (stack: *StackFrame) callconv(.c) void;

/// The array of registered handlers for each interrupt.
export var Handlers = [_]Handler{unhandledInterrupt} ** (256);

fn unhandledInterrupt(stack: *StackFrame) callconv(.c) void {
    // display some red to show that we're dead
    const framebuffer: [*]u32 = @ptrFromInt(0x80000000);
    @memset(framebuffer[0..0x0010_0000], 0xff0000);
    _ = stack;
    x86.halt();
}

/// Type of fn pointer used for an IDT gate's ISR
const AsmHandler = *const fn () callconv(.naked) void;
fn createServiceRoutine(comptime idx: usize) AsmHandler {
    const gate = Gates[idx];
    return &struct {
        fn handler() callconv(.naked) void {
            @setEvalBranchQuota(65536);

            // push error code if not provided
            if (!gate.error_code) x86.push("$0");
            // push interrupt index
            x86.push(std.fmt.comptimePrint("${d}", .{idx}));
            // push remaining general-purpose registers
            x86.pusha();
            asm volatile ("mov %rsp, %rdi");
            asm volatile ("call *(Handlers + (" ++ std.fmt.comptimePrint("{d}", .{idx}) ++ "))");
            // pop general-purpose registers
            x86.popa();
            // discard interrupt index and error code
            asm volatile ("add $16, %rsp");
            asm volatile ("iretq");
        }
        comptime {
            @export(&handler, .{ .name = isrName(idx) });
        }
    }.handler;
}

var idt = systemTable("lidt", blk: {
    var gates: [GateCount]Idt.Descriptor = undefined;
    for (0..gates.len) |i| {
        const gate = Gates[i];
        const descriptorType: ?x86.x32.Idt.GateType = switch (gate.type) {
            .trap, .fault, .abort => .trap_word,
            .interrupt => .interrupt_word,
            else => null,
        };

        if (descriptorType) |it| {
            gates[i] = Idt.descriptor(i, CodeDescriptorOffset, it, 3, 1);
        }
    }
    break :blk gates;
});

pub fn init() void {
    for (0..idt.entries.len) |i| {
        const offset = @intFromPtr(serviceRoutines[i]);
        idt.entries[i].offset_low = @truncate(offset);
        idt.entries[i].offset_high = @truncate(offset >> 16);
    }
    idt.load();
}
