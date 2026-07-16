pub const Framebuffer = struct {
    pub const ColorOrder = enum { rgb, bgr };
    address: usize,
    width: u16,
    height: u16,
    bpp: u8,
    order: ColorOrder,
};

pub const Platform = struct { fb: Framebuffer };

pub const Error = error{UnsupportedFramebuffer};
