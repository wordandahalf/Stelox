//! Multiboot2 constants, structures, and header construction.
//!
//! Spec: https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html
//! Original C header: Copyright (C) 1999,2003,2007,2008,2009,2010  Free Software Foundation, Inc.
//!
//! Permission is hereby granted, free of charge, to any person obtaining a copy
//! of this software and associated documentation files (the "Software"), to
//! deal in the Software without restriction, including without limitation the
//! rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//! sell copies of the Software, and to permit persons to whom the Software is
//! furnished to do so, subject to the following conditions:
//!
//! The above copyright notice and this permission notice shall be included in
//! all copies or substantial portions of the Software.
//!
//! THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//! IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//! FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL ANY
//! DEVELOPER OR DISTRIBUTOR BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//! WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
//! IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//!

const std = @import("std");
const NoPadding = @import("utils.zig").NoPadding;

// Search / alignment constants.

/// How many bytes from the start of the file we search for the header.
pub const SEARCH: u32 = 32768;
pub const HEADER_ALIGN: u32 = 8;
pub const TAG_ALIGN: u32 = 8;
/// Alignment of multiboot modules.
pub const MOD_ALIGN: u32 = 0x00001000;
/// Alignment of the multiboot info structure.
pub const INFO_ALIGN: u32 = 0x00000008;

/// Value that must be in the `magic` field of the multiboot header.
pub const HEADER_MAGIC: u32 = 0xe85250d6;

/// Value placed in `%eax` / `%rax` by the bootloader before jumping to the kernel.
pub const BOOTLOADER_MAGIC: u32 = 0x36d76289;

pub const architecture = enum(u32) {
    i386 = 0,
    mips32 = 4,
};

/// Tag types present in the boot-information structure passed by the bootloader.
pub const tag_type = enum(u32) {
    end = 0,
    cmdline = 1,
    boot_loader_name = 2,
    module = 3,
    basic_meminfo = 4,
    bootdev = 5,
    mmap = 6,
    vbe = 7,
    framebuffer = 8,
    elf_sections = 9,
    apm = 10,
    efi32 = 11,
    efi64 = 12,
    smbios = 13,
    acpi_old = 14,
    acpi_new = 15,
    network = 16,
    efi_mmap = 17,
    efi_bs = 18,
    efi32_ih = 19,
    efi64_ih = 20,
    load_base_addr = 21,
    _,
};

/// Tag types embedded inside the multiboot header itself (requests to the bootloader).
pub const header_tag_type = enum(u16) {
    end = 0,
    information_request = 1,
    address = 2,
    entry_address = 3,
    console_flags = 4,
    framebuffer = 5,
    module_align = 6,
    efi_bs = 7,
    entry_address_efi32 = 8,
    entry_address_efi64 = 9,
    relocatable = 10,
    _,
};

pub const memory_type = enum(u32) {
    available = 1,
    reserved = 2,
    acpi_reclaimable = 3,
    nvs = 4,
    badram = 5,
    _,
};

pub const framebuffer_type = enum(u8) {
    indexed = 0,
    rgb = 1,
    ega_text = 2,
    _,
};

pub const load_preference = enum(u32) {
    none = 0,
    low = 1,
    high = 2,
};

// Flags and packed bitfields.

pub const header_tag_flags = packed struct(u16) {
    /// When set the bootloader may ignore this tag.
    optional: bool = false,
    _pad: u15 = 0,
};

pub const console_flags = packed struct(u32) {
    console_required: bool = false,
    ega_text_supported: bool = false,
    _pad: u30 = 0,
};

// Multiboot header structures (written into the kernel image).

/// The main multiboot2 header that must appear within the first `SEARCH` bytes
/// of the kernel image, aligned to `HEADER_ALIGN`.
pub const header = extern struct {
    magic: u32,
    architecture: u32,
    header_length: u32,
    /// Must satisfy: magic +% architecture +% header_length +% checksum == 0
    checksum: u32,

    /// Compute a valid `header` at comptime (or runtime).
    ///
    /// `header_length` should be the total byte size of the entire multiboot
    /// header region (this struct plus any trailing header tags plus the
    /// mandatory end tag). When the header contains no extra tags, pass
    /// `@sizeOf(header)`.
    pub fn init(arch: architecture, header_length: u32) header {
        const magic: u32 = HEADER_MAGIC;
        const architecture_value: u32 = @intFromEnum(arch);
        const checksum: u32 = 0 -% (magic +% architecture_value +% header_length);
        return .{
            .magic = magic,
            .architecture = architecture_value,
            .header_length = header_length,
            .checksum = checksum,
        };
    }
};

pub const header_tag = extern struct {
    type: header_tag_type,
    flags: header_tag_flags,
    size: u32,
};

const packed_header_tag = struct {
    tag: header_tag,
    data: []const u8,
};

pub const header_tag_information_request = struct {
    // unfortunately need to explicitly specify alignment because
    // reified structs cannot have decls.
    type: header_tag_type align(1) = .information_request,
    flags: header_tag_flags align(1) = .{},
    size: u32 align(1),

    /// Returns a slice of the subsequent requested information tag types, given a pointer to the
    /// header tag
    pub fn requests(self: *const header_tag_information_request) []const tag_type {
        const data: [*]const tag_type = @ptrFromInt(@intFromPtr(self) + @sizeOf(header_tag_information_request));
        const count = (self.size - @sizeOf(header_tag_information_request)) / @sizeOf(tag_type);
        return data[0..count];
    }
};

pub fn information_request(comptime requests: []const tag_type) packed_header_tag {
    const size: u32 = @sizeOf(header_tag_information_request) + @sizeOf(tag_type) * requests.len;
    const data: []const u8 align(1) = @alignCast(std.mem.sliceAsBytes(requests));

    return .{
        .tag = .{
            .type = .information_request,
            .flags = .{},
            .size = size,
        },
        .data = data,
    };
}

pub const header_tag_address = extern struct {
    type: header_tag_type = .address,
    flags: header_tag_flags = .{},
    size: u32 = @sizeOf(header_tag_address),
    header_addr: u32,
    load_addr: u32,
    load_end_addr: u32,
    bss_end_addr: u32,
};

pub const header_tag_entry_address = extern struct {
    type: header_tag_type = .entry_address,
    flags: header_tag_flags = .{},
    size: u32 = @sizeOf(header_tag_entry_address),
    entry_addr: u32,
};

pub const header_tag_console_flags = extern struct {
    type: header_tag_type = .console_flags,
    flags: header_tag_flags = .{},
    size: u32 = @sizeOf(header_tag_console_flags),
    console_flags: console_flags,
};

pub const header_tag_framebuffer = extern struct {
    type: header_tag_type = .framebuffer,
    flags: header_tag_flags = .{},
    size: u32 = @sizeOf(header_tag_framebuffer),
    width: u32,
    height: u32,
    depth: u32,
};

pub const header_tag_module_align = extern struct {
    type: header_tag_type = .module_align,
    flags: header_tag_flags = .{},
    size: u32 = @sizeOf(header_tag_module_align),
};

pub const header_tag_relocatable = extern struct {
    type: header_tag_type = .relocatable,
    flags: header_tag_flags = .{},
    size: u32 = @sizeOf(header_tag_relocatable),
    min_addr: u32,
    max_addr: u32,
    alignment: u32,
    preference: load_preference,
};

/// Sentinel tag that terminates the list of header tags.
pub const header_tag_end: header_tag = .{
    .type = .end,
    .flags = .{},
    .size = @sizeOf(header_tag),
};

fn align_up(value: usize, alignment: usize) usize {
    return std.mem.alignForward(usize, value, alignment);
}

fn header_blob_length(comptime header_tags: anytype) usize {
    var length: usize = @sizeOf(header);

    inline for (header_tags) |it| {
        const tag_length = switch (@TypeOf(it)) {
            packed_header_tag => it.tag.size,
            else => it.size,
        };

        length = align_up(length + tag_length, TAG_ALIGN);
    }

    return length + @sizeOf(header_tag);
}

/// Build a complete multiboot header blob at comptime.
///
/// `header_tags` is a comptime tuple of header-tag values. Each tag must have
/// a valid `.size` field. The returned byte array contains:
/// - fixed `header`
/// - each tag (8-byte aligned)
/// - the mandatory `header_tag_end`
pub fn create_header(comptime arch: architecture, comptime header_tags: anytype) [header_blob_length(header_tags)]u8 {
    const length = header_blob_length(header_tags);
    var assembled_header: [length]u8 = [_]u8{0} ** length;
    var offset: usize = 0;

    const prefix = header.init(arch, @intCast(length));
    const prefix_bytes = std.mem.asBytes(&prefix);
    @memcpy(assembled_header[offset .. offset + prefix_bytes.len], prefix_bytes);
    offset += prefix_bytes.len;

    inline for (header_tags) |it| {
        switch (@TypeOf(it)) {
            packed_header_tag => {
                const tag_bytes = std.mem.asBytes(&it.tag);
                const data_bytes = it.data;

                @memcpy(assembled_header[offset .. offset + tag_bytes.len], tag_bytes);
                @memcpy(
                    assembled_header[offset + tag_bytes.len .. offset + tag_bytes.len + data_bytes.len],
                    data_bytes,
                );
                offset = align_up(offset + it.tag.size, TAG_ALIGN);
            },
            else => {
                const tag_bytes = std.mem.asBytes(&it);
                @memcpy(assembled_header[offset .. offset + tag_bytes.len], tag_bytes);
                offset = align_up(offset + it.size, TAG_ALIGN);
            },
        }
    }

    const end_tag_bytes = std.mem.asBytes(&header_tag_end);
    @memcpy(assembled_header[offset .. offset + end_tag_bytes.len], end_tag_bytes);

    return assembled_header;
}

// Boot-information tags (provided by the bootloader).
pub const fixed_info_tag = extern struct {
    total_size: u32,
    reserved: u32 = 0,
};

pub const tag = extern struct {
    type: tag_type,
    size: u32,
};

pub const tag_string = extern struct {
    type: tag_type,
    size: u32,
    // Followed immediately in memory by a null-terminated string.

    /// Return a pointer to the null-terminated string that follows this tag.
    pub fn string(self: *const tag_string) [*:0]const u8 {
        return @ptrCast(@as([*]const u8, @ptrCast(self)) + @sizeOf(tag_string));
    }
};

pub const tag_module = extern struct {
    type: tag_type = .module,
    size: u32,
    mod_start: u32,
    mod_end: u32,
    // Followed immediately in memory by a null-terminated cmdline string.

    pub const info = struct {
        /// Physical address range of the loaded module.
        start: u32,
        end: u32,
        /// Command-line string for this module (may be empty).
        cmdline: [:0]const u8,
    };

    /// Return all module information, including the trailing command-line string.
    pub fn get_info(self: *const tag_module) info {
        const ptr: [*:0]const u8 = @ptrCast(@as([*]const u8, @ptrCast(self)) + @sizeOf(tag_module));
        return .{
            .start = self.mod_start,
            .end = self.mod_end,
            .cmdline = std.mem.span(ptr),
        };
    }
};

pub const tag_basic_meminfo = extern struct {
    type: tag_type = .basic_meminfo,
    size: u32 = @sizeOf(tag_basic_meminfo),
    /// Lower memory size in kilobytes (starting at address 0).
    mem_lower: u32,
    /// Upper memory size in kilobytes (starting at 1 MiB).
    mem_upper: u32,
};

pub const tag_bootdev = extern struct {
    type: tag_type = .bootdev,
    size: u32 = @sizeOf(tag_bootdev),
    biosdev: u32,
    slice: u32,
    part: u32,
};

pub const mmap_entry = extern struct {
    addr: u64,
    len: u64,
    type: memory_type,
    _zero: u32 = 0,
};

pub const tag_mmap = extern struct {
    type: tag_type = .mmap,
    size: u32,
    entry_size: u32,
    entry_version: u32,
    // Followed immediately in memory by `mmap_entry` records.

    /// Return a slice of all memory-map entries in this tag.
    pub fn entries(self: *const tag_mmap) []const mmap_entry {
        const base: [*]const mmap_entry = @ptrCast(@as([*]const u8, @ptrCast(self)) + @sizeOf(tag_mmap));
        const count = (self.size - @sizeOf(tag_mmap)) / self.entry_size;
        return base[0..count];
    }
};

pub const color = extern struct {
    red: u8,
    green: u8,
    blue: u8,
};

pub const tag_framebuffer = extern struct {
    type: tag_type = .framebuffer,
    size: u32,
    addr: u64,
    /// the number of bytes in a row; not necessarily width * bpp
    pitch: u32,
    width: u32,
    height: u32,
    bpp: u8,
    fb_type: framebuffer_type,
    _reserved: u16 = 0,

    /// Indexed-color mode: a palette of up to 256 entries.
    pub const indexed_info = struct {
        palette: []const color,
    };

    /// Direct-color (RGB) mode: bit-field positions and sizes for each channel.
    pub const rgb_info = extern struct {
        red_field_position: u8,
        red_mask_size: u8,
        green_field_position: u8,
        green_mask_size: u8,
        blue_field_position: u8,
        blue_mask_size: u8,
    };

    /// Discriminated union over the three framebuffer modes.
    pub const info = union(enum) {
        /// Indexed color: palette follows the fixed header in memory.
        indexed: indexed_info,
        /// Direct RGB color: channel layout follows the fixed header.
        rgb: rgb_info,
        /// EGA text mode has no extra data.
        ega_text: void,
    };

    /// Decode the mode-specific data that follows the fixed header.
    pub fn get_info(self: *const tag_framebuffer) info {
        const extra: [*]const u8 = @as([*]const u8, @ptrCast(self)) + @sizeOf(tag_framebuffer);
        return switch (self.fb_type) {
            .indexed => blk: {
                const num: u16 = @as(*align(1) const u16, @ptrCast(extra)).*;
                const palette: [*]const color = @ptrCast(extra + @sizeOf(u16));
                break :blk .{ .indexed = .{ .palette = palette[0..num] } };
            },
            .rgb => .{ .rgb = @as(*align(1) const rgb_info, @ptrCast(extra)).* },
            .ega_text => .ega_text,
            _ => @panic("unknown framebuffer type"),
        };
    }
};

pub const tag_elf_sections = extern struct {
    type: tag_type = .elf_sections,
    size: u32,
    num: u32,
    entsize: u32,
    shndx: u32,
    // Followed by raw section-header data.
};

pub const tag_apm = extern struct {
    type: tag_type = .apm,
    size: u32 = @sizeOf(tag_apm),
    version: u16,
    cseg: u16,
    offset: u32,
    cseg_16: u16,
    dseg: u16,
    flags: u16,
    cseg_len: u16,
    cseg_16_len: u16,
    dseg_len: u16,
};

pub const vbe_info_block = extern struct {
    external_specification: [512]u8,
};

pub const vbe_mode_info_block = extern struct {
    external_specification: [256]u8,
};

pub const tag_vbe = extern struct {
    type: tag_type = .vbe,
    size: u32 = @sizeOf(tag_vbe),
    vbe_mode: u16,
    vbe_interface_seg: u16,
    vbe_interface_off: u16,
    vbe_interface_len: u16,
    vbe_control_info: vbe_info_block,
    vbe_mode_info: vbe_mode_info_block,
};

pub const tag_efi32 = extern struct {
    type: tag_type = .efi32,
    size: u32 = @sizeOf(tag_efi32),
    pointer: u32,
};

pub const tag_efi64 = extern struct {
    type: tag_type = .efi64,
    size: u32 = @sizeOf(tag_efi64),
    pointer: u64,
};

pub const tag_smbios = extern struct {
    type: tag_type = .smbios,
    size: u32,
    major: u8,
    minor: u8,
    _reserved: [6]u8 = [_]u8{0} ** 6,
    // Followed by raw SMBIOS table data.
};

/// ACPI 1.0 RSDP tag (type 14). The RSDP bytes follow the fixed header.
pub const tag_old_acpi = extern struct {
    type: tag_type = .acpi_old,
    size: u32,
    // Followed by RSDP bytes.
};

/// ACPI 2.0 RSDP tag (type 15). The RSDP bytes follow the fixed header.
pub const tag_new_acpi = extern struct {
    type: tag_type = .acpi_new,
    size: u32,
    // Followed by RSDP bytes.
};

pub const tag_network = extern struct {
    type: tag_type = .network,
    size: u32,
    // Followed by DHCP acknowledgement packet bytes.
};

pub const tag_efi_mmap = extern struct {
    type: tag_type = .efi_mmap,
    size: u32,
    descr_size: u32,
    descr_vers: u32,
    // Followed by EFI memory-map entries.
};

pub const tag_efi32_ih = extern struct {
    type: tag_type = .efi32_ih,
    size: u32 = @sizeOf(tag_efi32_ih),
    pointer: u32,
};

pub const tag_efi64_ih = extern struct {
    type: tag_type = .efi64_ih,
    size: u32 = @sizeOf(tag_efi64_ih),
    pointer: u64,
};

pub const tag_load_base_addr = extern struct {
    type: tag_type = .load_base_addr,
    size: u32 = @sizeOf(tag_load_base_addr),
    load_base_addr: u32,
};
