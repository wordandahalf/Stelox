const io = @import("lib").platform.x86.io;

pub const Port = enum(u16) {
    COM1 = 0x3f8,
    COM2 = 0x2f8,
    COM3 = 0x3e8,
    COM4 = 0x2e8,
    COM5 = 0x5f8,
    COM6 = 0x4f8,
    COM7 = 0x5e8,
    COM8 = 0x4e8,
    _,
};

/// The number of bits in a character is variable. Having fewer bits is, of course, faster,
/// but they store less information. If you are only sending ASCII text, you probably only need 7 bits.
///
/// Set this value by writing to the two least significant bits of the Line Control Register [PORT + 3].
pub const CharacterLength = enum(u2) {
    @"5" = 0b00,
    @"6" = 0b01,
    @"7" = 0b10,
    @"8" = 0b11,
};

/// The serial controller can be configured to send a number of bits after each character of data.
/// These reliable bits can be used to by the controller to verify that the sending and receiving devices are in phase.
///
/// If the character length is specifically 5 bits, the stop bits can only be set to 1 or 1.5. For other character lengths,
/// the stop bits can only be set to 1 or 2.
///
/// To set the number of stop bits, set bit 2 of the Line Control Register [PORT + 3].
pub const StopBits = enum(u1) {
    @"1" = 0b0,
    @"2" = 0b1,
};

/// The controller can be made to add or expect a parity bit at the end of each character of data transmitted. With this parity bit,
/// if a single bit of data is inverted by interference, a parity error can be raised. The parity type can be NONE, EVEN, ODD, MARK or SPACE.
///
/// If parity is set to NONE, no parity bit will be added and none will be expected. If one is sent by the transmitter and not expected by the receiver, it will likely cause an error.
///
/// If the parity is MARK or SPACE, the parity bit will be expected to be always set to 1 or 0 respectively.
///
/// If the parity is set to EVEN or ODD, the controller calculates the accuracy of the parity by adding together the values of all the data bits and the parity bit.
/// If the port is set to have EVEN parity, the result must be even. If it is set to have ODD parity, the result must be odd.
///
/// To set the port parity, set bits 3, 4 and 5 of the Line Control Register [PORT + 3].
pub const Parity = enum(u3) {
    none = 0b000,
    odd = 0b001,
    even = 0b011,
    mark = 0b101,
    space = 0b111,
};

pub const LineControl = packed struct(u8) {
    data: CharacterLength = .@"8",
    stop: StopBits = .@"1",
    parity: Parity = .none,
    @"break": u1 = 0,
    divisor_latch: u1 = 0,
};

/// To communicate with a serial port in interrupt mode, the interrupt-enable-register (see table above) must be set correctly.
/// To determine which interrupts should be enabled, a value with the following bits (0 = disabled, 1 = enabled) must be written to the interrupt-enable-register:
pub const InterruptEnable = packed struct(u8) {
    data_available: u1 = 0,
    tx_empty: u1 = 0,
    recv_status: u1 = 0,
    modem_status: u1 = 0,
    _: u4 = 0,
};

/// The Interrupt Trigger Level is used to configure how much data must be received in the FIFO Receive buffer before triggering a Received Data Available Interrupt.
pub const InterruptTriggerLevel = enum(u2) {
    @"1" = 0b00,
    @"4" = 0b01,
    @"8" = 0b10,
    @"14" = 0b11,
};

/// The First In / First Out Control Register (FCR) is for controlling the FIFO buffers. Access this register by writing to port offset +2.
/// Bit 2 being set clears the Transmit FIFO buffer while Bit 1 being set clears the Receive FIFO buffer. Both bits will set themselves back to 0 after they are done being cleared.
pub const FifoControl = packed struct(u8) {
    enable: u1 = 0,
    rx_clear: u1 = 0,
    tx_clear: u1 = 0,
    dma_mode: u1 = 0,
    _: u2 = 0,
    trigger_level: InterruptTriggerLevel = .@"1",
};

/// After Interrupt Pending is set, the Interrupt State shows the interrupt that has occurred. They have varying levels of priority,
/// with high-value interrupts handled first, and low-value interrupts being handled last.
pub const InterruptState = enum(u2) {
    modem_status = 0b00,
    tx_empty = 0b01,
    rx_available = 0b10,
    recv_status = 0b11,
};

pub const FifoState = enum(u2) {
    not_enabled = 0b00,
    not_usable = 0b01,
    enabled = 0b10,
};

/// The Interrupt Identification Register (IIR) is for identifying pending interrupts.
/// Access this register by reading from port offset +2.
pub const InterruptIdentity = packed struct(u8) {
    not_pending: u1,
    int_state: InterruptState,
    timeout_pending: u1,
    _: u2 = 0,
    fifo_state: FifoState,
};

/// The Modem Control Register is one half of the hardware handshaking registers.
/// While most serial devices no longer use hardware handshaking, the lines are still included in all 16550 compatible UARTS.
/// These can be used as general purpose output ports, or to actually perform handshaking. By writing to the Modem Control Register, it will set those lines active.
pub const ModemControl = packed struct(u8) {
    /// Controls the Data Terminal Ready Pin
    dtr: u1 = 0,
    /// Controls the Request to Send Pin
    rts: u1 = 0,
    /// Controls a hardware pin (OUT1) which is unused in PC implementations
    out1: u1 = 0,
    /// Controls a hardware pin (OUT2) which is used to enable the IRQ in PC implementations
    out2: u1 = 0,
    /// Provides a local loopback feature for diagnostic testing of the UART
    loop: u1 = 0,
    /// Unused
    _: u3 = 0,
};

/// The line status register is useful to check for errors and enable polling.
pub const LineStatus = packed struct(u8) {
    /// Set if there is data that can be read
    dr: u1,
    /// Set if there has been data lost
    oe: u1,
    /// Set if there was an error in the transmission as detected by parity
    pe: u1,
    /// Set if a stop bit was missing
    fe: u1,
    /// Set if there is a break in data input
    bi: u1,
    /// Set if the transmission buffer is empty (i.e. data can be sent)
    thre: u1,
    /// Set if the transmitter is not doing anything
    temt: u1,
    /// Set if there is an error with a word in the input buffer
    impending_error: u1,
};

/// This register provides the current state of the control lines from a peripheral device.
/// In addition to this current-state information, four bits of the MODEM Status Register provide change information.
/// These bits are set to a logic 1 whenever a control input from the MODEM changes state. They are reset to logic 0 whenever the CPU reads the MODEM Status Register.
///
/// If Bit 4 of the MCR (LOOP bit) is set, the upper 4 bits will mirror the 4 status output lines set in the Modem Control Register.
pub const ModemStatus = packed struct(u8) {
    /// Indicates that CTS input has changed state since the last time it was read
    dcts: u1,
    /// Indicates that DSR input has changed state since the last time it was read
    ddsr: u1,
    /// Indicates that RI input to the chip has changed from a low to a high state
    teri: u1,
    /// Indicates that DCD input has changed state since the last time it ware read
    ddcd: u1,
    /// Inverted CTS Signal
    cts: u1,
    /// Inverted DSR Signal
    dsr: u1,
    /// Inverted RI Signal
    ri: u1,
    /// Inverted DCD Signal
    dcd: u1,
};

const Self = @This();

// pub const Serial = struct {
port: Port,
int_en: InterruptEnable = .{},
fifo: FifoControl = .{},
line: LineControl = .{},
modem: ModemControl = .{},

fn offset(self: Self) u16 {
    return @intFromEnum(self.port);
}

pub fn init(port: Port, line: LineControl) Self {
    return .{ .port = port, .line = line };
}

pub fn write(self: Self, val: u8) void {
    while (self.lineStatus().temt == 0) {}
    io.outb(self.offset(), val);
}

pub fn writeAll(self: Self, val: []const u8) void {
    for (val) |it| self.write(it);
}

pub fn update(self: Self) void {
    io.outb(self.offset() + 1, @bitCast(self.int_en));
    io.outb(self.offset() + 2, @bitCast(self.fifo));
    io.outb(self.offset() + 3, @bitCast(self.line));
    io.outb(self.offset() + 4, @bitCast(self.modem));
}

pub fn setBaudDivisor(self: *Self, divisor: u16) void {
    self.line.divisor_latch = 1;
    self.update();
    io.outb(self.offset(), @truncate(divisor));
    io.outb(self.offset() + 1, @truncate(divisor >> 8));
    self.line.divisor_latch = 0;
    self.update();
}

pub fn lineStatus(self: Self) LineStatus {
    return @bitCast(io.inb(self.offset() + 5));
}

pub fn modemStatus(self: Self) ModemStatus {
    return @bitCast(io.inb(self.offset() + 6));
}
// };
