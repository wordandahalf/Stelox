const std = @import("std");

pub fn outb(port: u16, val: u8) callconv(.@"inline") void {
    asm volatile (
        \\ outb %[val], %[port]
        :   // no output
        :   [val] "{al}" (val),
            [port] "i{dx}" (port)
    );
}

pub fn inb(port: u16) callconv(.@"inline") u8 {
    return asm volatile (
        \\ inb %[port], %[ret]
        :   [ret] "={al}" (-> u8),
        :   [port] "i{dx}" (port)
    );
}

pub fn outw(port: u16, val: u16) callconv(.@"inline") void {
    asm volatile (
        \\ outw %[val], %[port]
        :   // no output
        :   [val] "{ax}" (val),
            [port] "i{dx}" (port)
    );
}

pub fn inw(port: u16) callconv(.@"inline") u16 {
    return asm volatile (
        \\ inw %[port], %[ret]
        :   [ret] "={ax}" (-> u16),
        :   [port] "i{dx}" (port)
    );
}

pub fn outl(port: u16, val: u32) callconv(.@"inline") void {
    asm volatile (
        \\ outl %[val], %[port]
        :   // no output
        :   [val] "{eax}" (val),
            [port] "i{dx}" (port)
    );
}

pub fn inl(port: u16) callconv(.@"inline") u32 {
    return asm volatile (
        \\ inl %[port], %[ret]
        :   [ret] "={eax}" (-> u32),
        :   [port] "i{dx}" (port)
    );
}
