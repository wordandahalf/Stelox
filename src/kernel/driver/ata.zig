const std = @import("std");
const io = @import("../io.zig");

const primary_io_base = 0x1f0;
const primary_control_base = 0x3f6;
const secondary_io_base = 0x170;
const secondary_control_base = 0x376;

const reg_data = 0x0;
const reg_error = 0x1;
const reg_features = 0x1;
const reg_sector_count = 0x2;
const reg_lba_low = 0x3;
const reg_lba_mid = 0x4;
const reg_lba_high = 0x5;
const reg_select_drive_head = 0x6;
const reg_status = 0x7;
const reg_command = 0x7;

const reg_status_alternative = 0x0;
const reg_drive_control = 0x0;
const reg_drive_address = 0x1;

const identify_ata = 0xec;
const identify_atapi = 0xa1;

pub const Error = error {
Timeout, Unspecified
};

pub const Identity = extern struct {
    flags: u16,
    _: [9]u16,
    serial: [20]u8,
    __: [3]u16,
    firmware: [8]u8,
    model: [40]u8,
    sectors_per_int: u16,
    ___: u16,
    capabilities: [2]u16,
    ____: [2]u16,
    valid_ext_data: u16,
    _____: [5]u16,
    size_of_rw_mult: u16,
    sectors_28: u32,
    ______: [38]u16,
    sectors_48: u64,
    _______: [152]u16
};

pub const Capacity = extern struct {
    block_size: u32,
    lba_count: u32
};

pub const Status = packed struct(u8) {
    err: bool,
    idx: u1 = 0,
    cor: u1 = 0,
    drq: bool,
    srv: u1,
    df:  bool,
    rdy: bool,
    bsy: bool
};

pub const DriveType = enum(u16) {
    empty = 0xffff,
    pata = 0x0000,
    sata = 0xc33c,
    patapi = 0xeb14,
    satapi = 0x9669,
    _
};

pub const Port = struct { io_base: u16, control_base: u16, slave: bool };

pub const primary_master_port = Port{ .io_base = primary_io_base, .control_base = primary_control_base, .slave = false };
pub const primary_slave_port = Port{ .io_base = primary_io_base, .control_base = primary_control_base, .slave = true };
pub const secondary_master_port = Port{ .io_base = secondary_io_base, .control_base = secondary_control_base, .slave = false };
pub const secondary_slave_port = Port{ .io_base = secondary_io_base, .control_base = secondary_control_base, .slave = true };

pub fn detect_devices(driveType: DriveType) ?Device {
    if (Device.detect(primary_master_port)) |it| {
        if (it.type == driveType) return it;
    }
    if (Device.detect(primary_slave_port)) |it| {
        if (it.type == driveType) return it;
    }
    if (Device.detect(secondary_master_port)) |it| {
        if (it.type == driveType) return it;
    }
    if (Device.detect(secondary_slave_port)) |it| {
        if (it.type == driveType) return it;
    }
    return null;
}

pub const Device = struct {
    port: Port,
    identity: Identity,
    capacity: Capacity,
    type: DriveType,

    pub fn detect(port: Port) ?Device {
        var device = Device{ .port = port, .identity = undefined, .capacity = undefined, .type = .empty };

        device.softReset();
        device.delay();
        device.select();

        var status: Status = device.getStatus();
        var timeout: u32 = 0xffffffff;
        while (status.bsy and (timeout > 0)) {
            status = device.getStatus();
            timeout -= 1;
        }

        if (timeout == 0) {
            return null;
        }

        device.type = std.meta.intToEnum(DriveType,
            (@as(u16, io.inb(port.io_base + reg_lba_high)) << 8) | io.inb(port.io_base + reg_lba_mid)
        ) catch {
            return null;
        };

        if (device.type == .empty) return null;

        Device.init(&device);
        return device;
    }

    pub fn getStatus(self: *Device) Status {
        return @bitCast(io.inb(self.port.io_base + reg_status));
    }

    pub fn delay(self: *Device) void {
        _ = io.inb(self.port.io_base + reg_status);
        _ = io.inb(self.port.io_base + reg_status);
        _ = io.inb(self.port.io_base + reg_status);
        _ = io.inb(self.port.io_base + reg_status);
    }

    pub fn softReset(self: *Device) void {
        io.outb(self.port.control_base, 0x04);
        self.delay();
        io.outb(self.port.control_base, 0x0);
    }

    pub fn wait(self: *Device) Status {
        var status = self.getStatus();

        while (status.bsy) {
            status = self.getStatus();
        }

        return status;
    }

    pub fn select(self: *Device) void {
        const select_byte: u8 = if (self.port.slave) 0xB0 else 0xA0;
        io.outb(self.port.io_base + reg_select_drive_head, select_byte);
        self.delay();
    }

    pub fn init(self: *Device) void {
        io.outb(self.port.io_base + 1, 0x1);
        io.outb(self.port.control_base, 0x0);

        self.select();

        const identify: u8 = if (self.type == .pata or self.type == .sata) identify_ata else identify_atapi;
        io.outb(self.port.io_base + reg_command, identify);

        self.delay();
        self.delay();

        _ = self.wait();

        var buf: []u16 = std.mem.bytesAsSlice(u16, std.mem.asBytes(&self.identity));
        for (0..256) |i| {
            buf[i] = io.inw(self.port.io_base);
        }
    }
};
