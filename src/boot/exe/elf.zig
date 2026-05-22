const std = @import("std");
const Allocator = std.mem.Allocator;

const NoPadding = @import("lib").utils.NoPadding;

pub const Class = enum(u8) { @"32" = 1, @"64" = 2 };
pub const Endianess = enum(u8) { little = 1, big = 2 };
pub const OsAbi = enum(u8) {
    systemv     = 0x00,
    hp_ux       = 0x01,
    netbsd      = 0x02,
    linux       = 0x03,
    gnu_hurd    = 0x04,
    solaris     = 0x06,
    aix         = 0x07,
    irix        = 0x08,
    freebsd     = 0x09,
    tru64       = 0x0a,
    modesto     = 0x0b,
    openbsd     = 0x0c,
    openvms     = 0x0d,
    nsk         = 0x0e,
    arcos       = 0x0f,
    fenix       = 0x10,
    cloudabi    = 0x11,
    openvos     = 0x12,
};
pub const Type = enum(u16) { relocatable = 1, executable = 2, shared = 3, core = 4 };
pub const Machine = enum(u16) {
    unspecific  = 0x00,
    sparc       = 0x02,
    x86         = 0x03,
    mips        = 0x08,
    powerpc     = 0x14,
    arm         = 0x28,
    superh      = 0x2a,
    ia_64       = 0x32,
    x86_64      = 0x3e,
    aarch64     = 0xb7,
    riscv       = 0xf3,
};

pub const Identity = NoPadding(struct {
    magic: [4]u8,
    class: Class,
    data: Endianess,
    version: u8,
    os_abi: OsAbi,
    abi_version: u8,
    pad: [7]u8,
});

pub const HeaderParseError = error { BufferTooShort, BadElfMagic, UnsupportedVersion };

pub const FileHeader = union(Class) {
    @"32": FileHeader32,
    @"64": FileHeader64,

    pub fn parse(data: []const u8) HeaderParseError!FileHeader {
        if (data.len < @sizeOf(Identity)) return HeaderParseError.BufferTooShort;

        const header_offset = @sizeOf(Identity);
        const ident: *const Identity = std.mem.bytesAsValue(Identity, data[0..header_offset]);
        if (!std.mem.eql(u8, &ident.magic, "\x7fELF")) return HeaderParseError.BadElfMagic;
        if (ident.version != 1) return HeaderParseError.UnsupportedVersion;

        const header_length: usize = switch (ident.class) {
            .@"32" => @sizeOf(FileHeader32),
            .@"64" => @sizeOf(FileHeader64)
        };

        if (data.len < header_offset + header_length) return HeaderParseError.BufferTooShort;

        switch (ident.class) {
            .@"32" => {
                return @unionInit(
                    FileHeader,
                    @tagName(Class.@"32"),
                    std.mem.bytesAsValue(FileHeader32, data).*
                );
            },
            .@"64" => {
                return @unionInit(
                    FileHeader,
                    @tagName(Class.@"64"),
                    std.mem.bytesAsValue(FileHeader64, data).*
                );
            }
        }
    }
};

pub const FileHeader32 = NoPadding(struct {
    ident: Identity,
    @"type": Type,
    machine: Machine,
    version: u32,
    entry:   u32,
    program_header_offset: u32,
    section_header_offset: u32,
    flags: u32,
    header_size: u16,
    program_header_entry_size: u16,
    program_header_count: u16,
    section_header_entry_size: u16,
    section_header_count: u16,
    section_header_names_index: u16
});

pub const FileHeader64 = NoPadding(struct {
    ident: Identity,
    @"type": Type,
    machine: Machine,
    version: u32,
    entry:   u64,
    program_header_offset: u64,
    section_header_offset: u64,
    flags: u32,
    header_size: u16,
    program_header_entry_size: u16,
    program_header_count: u16,
    section_header_entry_size: u16,
    section_header_count: u16,
    section_header_names_index: u16
});

pub const ProgramHeaders = union(Class) {
    @"32": []const ProgramHeader32,
    @"64": []const ProgramHeader64,

    pub const Type = enum(u32) {
        null    = 0,
        load    = 1,
        dynamic = 2,
        interp  = 3,
        note    = 4,
        shlib   = 5,
        phdr    = 6,
        tls     = 7,
        _
    };

    pub const Flags = packed struct(u32) {
        execute: bool,
        write:   bool,
        read:    bool,
        _:       u29,
    };

    pub fn parse(data: []const u8) !ProgramHeaders {
        const file_header = try FileHeader.parse(data);
        switch (file_header) {
            .@"32" => {
                const fh = file_header.@"32";
                const ph_offset: usize = fh.program_header_offset;
                const ph_entry_size: usize = fh.program_header_entry_size;
                const ph_count: usize = fh.program_header_count;

                if (data.len < ph_offset + ph_entry_size * ph_count) {
                    return HeaderParseError.BufferTooShort;
                }

                return @unionInit(
                    ProgramHeaders,
                    @tagName(Class.@"32"),
                    std.mem.bytesAsSlice(ProgramHeader32, data[ph_offset..ph_offset + ph_entry_size * ph_count])
                );
            },
            .@"64" => {
                const fh = file_header.@"64";
                const ph_offset: usize = fh.program_header_offset;
                const ph_entry_size: usize = fh.program_header_entry_size;
                const ph_count: usize = fh.program_header_count;

                if (data.len < ph_offset + ph_entry_size * ph_count) {
                    return HeaderParseError.BufferTooShort;
                }

                return @unionInit(
                    ProgramHeaders,
                    @tagName(Class.@"64"),
                    std.mem.bytesAsSlice(ProgramHeader64, data[ph_offset..ph_offset + ph_entry_size * ph_count])
                );
            }
        }
    }
};

pub const ProgramHeader32 = NoPadding(struct {
    @"type": ProgramHeaders.Type,
    offset: u32,
    vaddr:  u32,
    paddr:  u32,
    filesz: u32,
    memsz: u32,
    flags: ProgramHeaders.Flags,
    @"align": u32,
});

pub const ProgramHeader64 = NoPadding(struct {
    @"type": ProgramHeaders.Type,
    flags:  ProgramHeaders.Flags,
    offset: u64,
    vaddr:  u64,
    paddr:  u64,
    filesz: u64,
    memsz:  u64,
    @"align": u64,
});
