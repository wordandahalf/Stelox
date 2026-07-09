pub inline fn inb(addr: u16) u8 {
    return asm volatile ("inb %[add], %[val]"
        : [val] "={al}" (-> u8),
        : [add] "N{dx}" (addr),
    );
}

pub inline fn outb(addr: u16, val: u8) void {
    asm volatile ("outb %[val], %[addr]"
        :
        : [val] "{al}" (val),
          [addr] "N{dx}" (addr),
    );
}
