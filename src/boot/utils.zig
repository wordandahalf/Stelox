const std = @import("std");
const Type = std.builtin.Type;

pub fn NoPadding(T: type) type {
    const info = @typeInfo(T);
    if (info != .@"struct") @panic("NoPadding only applies to structs");
    if (info.@"struct".decls.len != 0) @panic("NoPadding only applies to structs without declarations");

    const structInfo = info.@"struct";
    const N = comptime info.@"struct".fields.len;
    var field_names: [N][]const u8 = undefined;
    var field_types: [N]type = undefined;
    var field_attrs: [N]Type.StructField.Attributes = undefined;

    for (0.., structInfo.fields) |i, it| {
        field_names[i] = it.name;
        field_types[i] = it.type;
        field_attrs[i] = .{ .@"comptime" = it.is_comptime, .@"align" = 1, .default_value_ptr = it.default_value_ptr };
    }

    return @Struct(structInfo.layout, structInfo.backing_integer, &field_names, &field_types, &field_attrs);
}

pub fn ceilDiv(T: type, a: T, b: T) T {
    return (a + b - 1) / b;
}
