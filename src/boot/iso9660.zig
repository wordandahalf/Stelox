/// Implementation of the ISO9660 / ECMA-119 filesystem specification.

const std = @import("std");
const uefi = std.os.uefi;
const Console = @import("console.zig");
const utf16 = std.unicode.utf8ToUtf16LeStringLiteral;

const utils = @import("utils.zig");
const NoPadding = utils.NoPadding;
const ceilDiv = utils.ceilDiv;

pub const DirectoryRecord = struct {
    pub const Header = NoPadding(struct {
        /// the length of the header in bytes
        record_length: u8,
        extended_attributes_length: u8,
        directory_extent_lba_little: u32,
        directory_extent_lba_big: u32,
        /// the length of the extent in bytes. for a file, this is the number of bytes
        /// to read from the extent to get the entire file.
        /// for a directory, this is the total number of bytes occupied by all of the directory's records.
        directory_extent_length_little: u32,
        directory_extent_length_big: u32,
        recording_date_time: DateTime,
        file_flags: FileFlags,
        file_unit_size: u8,
        interleave_gap_size: u8,
        volume_sequence_number_little: u16,
        volume_sequence_number_big: u16,
        file_identifier_length: u8
    });

    header: Header,
    file_identifier: []u8,

    pub fn init(alloc: std.mem.Allocator, data: []u8) !DirectoryRecord {
        if (data.len < @sizeOf(Header)) return ReadError.BufferToShort;

        var header: Header = undefined;
        const headerPtr: []u8 = @ptrCast(@alignCast(&header));
        @memcpy(headerPtr, data.ptr);

        const record_length = header.record_length;
        if (record_length == 0 or record_length > data.len) return ReadError.IllegalRecordLength;

        const file_identifier_length: u32 = header.file_identifier_length;
        if (@sizeOf(Header) + file_identifier_length > record_length) return ReadError.RecordTooShort;

        const record: DirectoryRecord = .{
            .header = header,
            .file_identifier = try alloc.alloc(u8, file_identifier_length)
        };
        @memcpy(record.file_identifier.ptr, data[@sizeOf(Header)..@sizeOf(Header) + file_identifier_length]);

        return record;
    }

    pub fn deinit(self: DirectoryRecord, alloc: std.mem.Allocator) void {
        alloc.free(self.file_identifier);
    }
};

pub const RootDirectoryRecord = NoPadding(struct {
    record_length: u8,
    extended_attributes_length: u8,
    directory_extent_lba_little: u32,
    directory_extent_lba_big: u32,
    directory_extent_length_little: u32,
    directory_extent_length_big: u32,
    recording_date_time: DateTime,
    file_flags: FileFlags,
    file_unit_size: u8,
    interleave_gap_size: u8,
    volume_sequence_number_little: u16,
    volume_sequence_number_big: u16,
    file_identifier_length: u8,
    file_identifier: u8
});

pub const DateTime = NoPadding(struct {
    year: u8,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
    second: u8,
    timezone_offset: i8
});

pub const FileFlags = packed struct(u8) {
    is_hidden: bool,
    is_directory: bool,
    is_associated_file: bool,
    has_record: bool,
    has_permissions: bool,
    _: u2,
    additional_extents: bool
};

pub const VolumeDescriptor = union(Type) {
    pub const Type = enum(u8) {
        boot_record = 0,
        primary = 1,
        supplementary = 2,
        volume_partition = 3,
        set_terminator = 255
    };

    pub const Generic = NoPadding(struct {
        type: Type,
        identifier: [5]u8,
        version: u8,
        data: [2041]u8
    });

    boot_record: BootRecord,
    primary: PrimaryVolumeDescriptor,
    supplementary: Generic,
    volume_partition: Generic,
    set_terminator: Generic,

    pub fn init(alloc: std.mem.Allocator, buf: []u8) !*VolumeDescriptor {
        const vd_type: Type = @enumFromInt(buf[0]);

        switch (vd_type) {
            inline else => |it| {
                const new = try alloc.create(VolumeDescriptor);
                new.* = @unionInit(VolumeDescriptor, @tagName(it), undefined);

                const fieldPtr: []u8 = @ptrCast(@alignCast(&@field(new.*, @tagName(it))));
                @memcpy(fieldPtr, buf);
                return new;
            }
        }
    }
    
    pub fn deinit(self: *VolumeDescriptor, alloc: std.mem.Allocator) void {
        alloc.destroy(self);
    }
};

pub const BootRecord = NoPadding(struct {
    type: u8,
    identifier: [5]u8,
    version: u8,
    boot_system_identifier: [32]u8,
    boot_identifier: [32]u8,
    __: [1977]u8
});

pub const PrimaryVolumeDescriptor = NoPadding(struct {
    type: u8,
    identifier: [5]u8,
    version: u8,
    _: u8,
    system_identifier: [32]u8,
    volume_identifier: [32]u8,
    __: [8]u8,
    volume_space_size: u32,
    msb_volume_space_size: u32,
    ___: [32]u8,
    volume_set_size: u16,
    msb_volume_set_size: u16,
    volume_sequence_number: u16,
    msb_volume_sequence_number: u16,
    logical_block_size: u16,
    msb_logical_block_size: u16,
    path_table_size: u32,
    msb_path_table_size: u32,
    path_table_lba: u32,
    optional_path_table_lba: u32,
    msb_path_table_lba: u32,
    msb_optional_path_table_lba: u32,
    root_directory_record: RootDirectoryRecord,
    volume_set_identifier: [128]u8,
    publisher_identifier: [128]u8,
    data_preparer_identifier: [128]u8,
    application_identifier: [128]u8,
    copyright_file_identifier: [37]u8,
    abstract_file_identifier: [37]u8,
    bibliographic_file_identifier: [37]u8,
    creation_date_time: [17]u8,
    modification_date_time: [17]u8,
    expiration_date_time: [17]u8,
    effective_date_time: [17]u8,
    file_structure_version: u8,
    ____: u8,
    application_used: [512]u8,
    _____: [653]u8
});

pub const vd_size = 2048;
pub const pvd_id = "CD001";
pub const pvd_offset: u64 = 0x10;

pub const ReadError = error { IllegalRecordLength, RecordTooShort, BufferToShort, NotFound };
pub const ProbeError = error { NotFound, BadIdentifier, UnsupportedGeometry };

/// Returns true if the provided block device appears to contain an ISO9660 filesystem.
pub fn probe(alloc: std.mem.Allocator, io: *uefi.protocol.BlockIo) bool {
    const media = io.media;
    const block_size = media.block_size;

    if (vd_size % block_size != 0) return false;
    const blocks_per_vd = vd_size / block_size;
    const pvd_lba = 16 * blocks_per_vd;

    if (pvd_lba + blocks_per_vd - 1 > media.last_block) return false;

    const vd = alloc.create(VolumeDescriptor.Generic) catch return false;
    defer alloc.destroy(vd);

    io.readBlocks(media.media_id, pvd_lba, @ptrCast(@alignCast(vd))) catch return false;

    return std.mem.eql(u8, &vd.identifier, "CD001") and vd.version == 1;
}

/// Returns a pointer to the first volume descriptor of the specified type, or an error if not found or if the geometry is unsupported.
pub fn find_volume_descriptor(alloc: std.mem.Allocator, io: *uefi.protocol.BlockIo, typ: VolumeDescriptor.Type) !*VolumeDescriptor {
    const media = io.media;
    const block_size = media.block_size;

    if (vd_size % block_size != 0) return ProbeError.UnsupportedGeometry;

    const blocks_per_vd: u32 = vd_size / block_size;
    const buf = try alloc.alloc(u8, vd_size);
    defer alloc.free(buf);

    var offset: u64 = pvd_offset * blocks_per_vd;
    while (offset <= media.last_block) : (offset += blocks_per_vd) {
        try io.readBlocks(io.media.media_id, offset, buf);

        const vd_type: VolumeDescriptor.Type = @enumFromInt(buf[0]);
        if (vd_type == .set_terminator) break;
        if (vd_type == typ) return try VolumeDescriptor.init(alloc, buf);
    }

    return ProbeError.NotFound;
}

/// Loads the root directory record from the provided primary volume descriptor,
/// and returns a DirectoryRecord containing the file identifier and extent information for the root directory.
/// The caller is responsible for deinitializing the returned record when finished.
pub fn load_root(alloc: std.mem.Allocator, io: *uefi.protocol.BlockIo, pvd: *PrimaryVolumeDescriptor) !DirectoryRecord {
    const media = io.media;

    const root = pvd.root_directory_record;
    const buf = try alloc.alloc(u8, root.directory_extent_length_little);
    try io.readBlocks(media.media_id, root.directory_extent_lba_little, buf);

    defer alloc.free(buf);
    return try DirectoryRecord.init(alloc, buf);
}

/// Returns the directory portion of the provided path.
pub fn dirname(path: []const u8) []const u8 {
    const last_slash = std.mem.lastIndexOfScalar(u8, path, '/');
    return if (last_slash) |i| path[0..i] else ".";
}

/// Returns the basename of the provided path, excluding any version component.
pub fn basename(path: []const u8) []const u8 {
    const last_slash = std.mem.lastIndexOfScalar(u8, path, '/');
    const filename = if (last_slash) |i| path[i + 1..] else path;
    const semicolon = std.mem.indexOfScalar(u8, filename, ';');
    return if (semicolon) |i| filename[0..i] else filename;
}

/// Returns the first directory component of the provided path, or the entire path if it contains no slashes.
pub fn first_dirname(path: []const u8) []const u8 {
    const first_slash = std.mem.indexOfScalar(u8, path, '/');
    return if (first_slash) |i| path[0..i] else path;
}

pub const PathTable = struct {
    pub const Entry = struct {
        lba: u32,
        parent: u16,
        identifier: []u8,

        pub fn deinit(self: Entry, alloc: std.mem.Allocator) void {
            alloc.free(self.identifier);
        }
    };

    value: Entry,
    children: std.ArrayList(*PathTable),

    fn init(alloc: std.mem.Allocator, entry: Entry) !*PathTable {
        const new = try alloc.create(PathTable);
        new.* = PathTable{
            .value = entry,
            .children = try std.ArrayList(*PathTable).initCapacity(alloc, 8)
        };
        return new;
    }

    fn from_raw_table(alloc: std.mem.Allocator, table_size: u32, buf: []u8) !*PathTable {
        var entries = try std.ArrayList(*PathTable).initCapacity(alloc, 8);
        defer entries.deinit(alloc);

        var offset: usize = 0;
        while (offset < table_size) {
            const identifier_length: u8 = buf[offset];

            const entry_filename = try alloc.alloc(u8, identifier_length);
            @memcpy(entry_filename, buf[offset + 8..offset + 8 + identifier_length]);

            // spec indicates 1-based indexing
            const parent: u16 = std.mem.bytesAsValue(u16, buf[offset + 6..offset + 6 + 2]).*;
            const entry = try init(alloc, .{
                .lba = std.mem.bytesAsValue(u32, buf[offset + 2..offset + 2 + 4]).*,
                .parent = parent,
                .identifier = entry_filename
            });

            if (parent - 1 < entries.items.len) {
                try entries.items[parent - 1].children.append(alloc, entry);
            }

            try entries.append(alloc, entry);
            offset += 8 + identifier_length + (identifier_length % 2);
        }

        return entries.items[0];
    }

    pub fn deinit(self: *PathTable, alloc: std.mem.Allocator) void {
        self.value.deinit(alloc);
        defer alloc.destroy(self);
        defer self.children.deinit(alloc);

        for (self.children.items) |child| {
            child.deinit(alloc);
        }
    }

    pub fn find(self: *PathTable, filename: []const u8) ?*PathTable {
        const top = first_dirname(filename);

        if (std.mem.eql(u8, top, filename)) return self;
        for (self.children.items) |child| {
            if (std.mem.eql(u8, child.value.identifier, top)) {
                // add one to length to skip the path separator, which is guaranteed to be present.
                return find(child, filename[top.len + 1..]);
            }
        }

        return null;
    }
};

pub fn load_path_table(alloc: std.mem.Allocator, io: *uefi.protocol.BlockIo, vd: *VolumeDescriptor) !*PathTable {
    if (vd.* != .primary) return ReadError.NotFound;
    const pvd = vd.primary;

    const media = io.media;
    const path_table_size = pvd.path_table_size;
    const path_table_lba = pvd.path_table_lba;

    const buffer_length = ceilDiv(u32, path_table_size, media.block_size) * media.block_size;
    const buf = try alloc.alloc(u8, buffer_length);
    defer alloc.free(buf);

    try io.readBlocks(media.media_id, path_table_lba, buf);
    return try PathTable.from_raw_table(alloc, path_table_size, buf);
}

pub fn load_file(alloc: std.mem.Allocator, io: *uefi.protocol.BlockIo, table: *PathTable, filename: []const u8) ![]u8 {
    const parent = table.find(filename) orelse return ReadError.NotFound;    
    
    const media = io.media;
    var directory_lba = parent.value.lba;

    const buf = try alloc.alloc(u8, media.block_size);
    var offset: usize = 0; var consumed: usize = 0;
    defer alloc.free(buf);

    try io.readBlocks(media.media_id, directory_lba, buf);

    var record: DirectoryRecord = try DirectoryRecord.init(alloc, buf[offset..]);
    const parent_length = record.header.directory_extent_length_little;

    // 6.8.1.1 mandates that the remaining bytes in the sector after the last directory record in a directory must be filled with 0s,
    // so a record length of 0 indicates the end of the directory.
    while (record.header.record_length != 0 and consumed < parent_length) {
        const is_dir = record.header.file_flags.is_directory;
        
        if (!is_dir and std.mem.eql(u8, basename(record.file_identifier), basename(filename))) {
            defer record.deinit(alloc);

            const file_size = ceilDiv(u32, record.header.directory_extent_length_little, media.block_size) * media.block_size;
            const file_buffer = try alloc.alloc(u8, file_size);
            try io.readBlocks(media.media_id, record.header.directory_extent_lba_little, file_buffer);
            return file_buffer;
        }
        
        consumed += record.header.record_length; offset += record.header.record_length;
        record.deinit(alloc);
        
        // if next record is in the next sector, read it in. 6.8.1.1 also requires that each record must end in
        // the sector which it starts in, so we won't have to worry about records spanning multiple sectors.
        if (record.header.record_length == 0 and consumed < parent_length) {
            // consume any (guaranteed zero) bytes in the buffer, then read in the next sector.
            consumed += buf.len - offset;
            directory_lba += 1;
            try io.readBlocks(media.media_id, directory_lba, buf);
            // start at the beginning of the buffer for the next record.
            offset = 0;
        }

        record = try DirectoryRecord.init(alloc, buf[offset..]);
    }

    return ReadError.NotFound;
}
