const std = @import("std");

pub fn NoPadding(T: type) type {
    var info = @typeInfo(T);
    if (info != .@"struct") @panic("NoPadding only applies to structs");
    if (info.@"struct".decls.len != 0) @panic("NoPadding only applies to structs without declarations");

    var fields: [info.@"struct".fields.len]std.builtin.Type.StructField = undefined;

    for (0.., info.@"struct".fields) |i, it| {
        var field = it;
        field.alignment = 1;
        fields[i] = field;
    }

    info.@"struct".fields = &fields;
    return @Type(info);
}

pub fn ceilDiv(T: type, a: T, b: T) T {
    return (a + b - 1) / b;
}

pub fn copyAndIncrement(comptime T: type, dest: *[*]u8, src: T) void {
    switch (@typeInfo(T)) {
        .@"struct", .@"union" => {
            const ptr = std.mem.asBytes(&src);
            const len = @sizeOf(T);

            @memcpy(dest.*[0..len], ptr);
            dest.* = dest.* + len;
        },
        else => @compileError("unsupported copy source type '" ++ @typeName(@TypeOf(src)) ++ "'")
    }
}
