const lib = @import("lib");
const mb2 = lib.mb2;

const hal = @import("hal").x86.x64;
const info = @import("root.zig").info;

pub fn run(mb2_info: *mb2.fixed_info_tag) info.Error!info.Platform {
    var plat: info.Platform = undefined;

    const addr = @intFromPtr(mb2_info);
    var offset: usize = @sizeOf(@TypeOf(mb2_info.*));
    while (offset < mb2_info.total_size) {
        const tag: *mb2.tag = @ptrFromInt(addr + offset);
        switch (tag.type) {
            .framebuffer => {
                const fb: *mb2.tag_framebuffer = @ptrCast(@alignCast(tag));
                if (fb.fb_type != .rgb) return error.UnsupportedFramebuffer;
                const rgb = fb.get_info().rgb;

                if (rgb.red_mask_size != 8 or rgb.green_mask_size != 8 or rgb.blue_mask_size != 8)
                    return error.UnsupportedFramebuffer;

                const r_idx = rgb.red_field_position / 8;
                const g_idx = rgb.green_field_position / 8;

                const order: info.Framebuffer.ColorOrder = switch (r_idx + g_idx * 10) {
                    10 => .rgb,
                    // todo: properly support alternate channel packings
                    // 12 => .bgr,
                    else => return error.UnsupportedFramebuffer,
                };

                plat.fb = .{
                    .address = fb.addr,
                    .width = @truncate(fb.width),
                    .height = @truncate(fb.height),
                    .bpp = fb.bpp,
                    .order = order,
                };
            },
            else => {},
        }

        offset += tag.size;
    }

    return plat;
}
