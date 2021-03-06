const std = @import("std");
const math = std.math;
const mem = std.mem;
const meta = std.meta;

// XXX: Why is this necessary?
comptime {
    _ = ColorblindnessFlavor;
    _ = RGB;
    _ = HSV;
    _ = HSL;
    _ = XYZ;
    _ = LMS;
    _ = hsl_to_rgb;
    _ = rgb_to_hsv;
    _ = rgb_to_hsl;
    _ = rgb_to_xyz;
    _ = hsv_to_rgb;
    _ = xyz_to_rgb;
    _ = xyz_to_lms;
    _ = lms_adjust_for_colorblindness;
    _ = lms_to_xyz;
}

pub const ColorblindnessFlavor = extern enum {
    Protanopia = 1, Deuteranopia = 2, Tritanopia = 3
};

// XXX: stahp reformatting my space alignment !!!
// {{{
pub const RGB = extern struct {
    r: u8,
    g: u8,
    b: u8,

    pub fn to_hsv(rgb: *const RGB) HSV {
        // XXX: guh type inference is a thing
        var hue: f64 = 0.0;
        var saturation: f64 = 0.0;
        var value: f64 = 0.0;

        const tr = @intToFloat(f64, rgb.r) / 255.0;
        const tg = @intToFloat(f64, rgb.g) / 255.0;
        const tb = @intToFloat(f64, rgb.b) / 255.0;

        // XXX: why is max in mem
        const Cmax = mem.max(f64, &[_]f64{ tr, tg, tb });
        const Cmin = mem.min(f64, &[_]f64{ tr, tg, tb });
        const C = Cmax - Cmin;

        value = Cmax;
        saturation = if (Cmax == 0) 0 else C / Cmax;

        if (C == 0.0) {
            hue = 0;
        } else if (Cmax == tr) {
            hue = 60.0 * (((tg - tb) / C) + 0.0);
        } else if (Cmax == tg) {
            hue = 60.0 * (((tb - tr) / C) + 2.0);
        } else if (Cmax == tb) {
            hue = 60.0 * (((tr - tg) / C) + 4.0);
        }

        if (hue < 0.0) hue += 360.0;

        return .{
            .h = hue,
            .s = saturation * 100,
            .v = value * 100,
        };
    }

    pub fn to_hsl(rgb: *const RGB) HSL {
        var hsl: HSL = HSL{ .h = 0.0, .s = 0.0, .l = 0.0 };

        const tr = @intToFloat(f64, rgb.r) / 255.0;
        const tg = @intToFloat(f64, rgb.g) / 255.0;
        const tb = @intToFloat(f64, rgb.b) / 255.0;

        // XXX: Why do I have to pass the type along everywhere
        const Cmax = mem.max(f64, &[_]f64{ tr, tg, tb });
        const Cmin = mem.min(f64, &[_]f64{ tr, tg, tb });
        const C = Cmax - Cmin;

        hsl.l = (Cmax + Cmin) / 2;

        if (C == 0) { // achromatic
            hsl.h = 0.0;
            hsl.s = 0.0;
        } else {
            hsl.s = C / (1.0 - math.fabs(2.0 * hsl.l - 1.0));

            hsl.h = if (Cmax == tr)
                (tg - tb) / C
            else if (Cmax == tg)
                (tb - tr) / C + 2.0
            else if (Cmax == tb)
                (tr - tg) / C + 4.0
            else
                @panic("The sky is falling~");

            hsl.h = @mod(hsl.h / 6.0, 1.0);
        }

        hsl.h *= 360.0;
        hsl.s *= 100.0;
        hsl.l *= 100.0;

        return hsl;
    }
    pub fn expectNearlyEq(want: RGB, have: RGB) void {
        if ((@as(isize, want.r) - @as(isize, have.r)) >= 1.0) {
            std.debug.panic("Expect RGB.r {}, found {}", .{ want.r, have.r });
        }
        if ((@as(isize, want.g) - @as(isize, have.g)) >= 1.0) {
            std.debug.panic("Expect RGB.g {}, found {}", .{ want.g, have.g });
        }
        if ((@as(isize, want.b) - @as(isize, have.b)) >= 1.0) {
            std.debug.panic("Expect RGB.b {}, found {}", .{ want.b, have.b });
        }
    }

    pub fn to_xyz(rgb: *const RGB) XYZ {
        var r = @intToFloat(f64, rgb.r) / 255.0;
        var g = @intToFloat(f64, rgb.g) / 255.0;
        var b = @intToFloat(f64, rgb.b) / 255.0;

        r = if (r > 0.04045) math.pow(f64, ((r + 0.055) / 1.055), 2.4) else r / 12.92;
        g = if (g > 0.04045) math.pow(f64, ((g + 0.055) / 1.055), 2.4) else g / 12.92;
        b = if (b > 0.04045) math.pow(f64, ((b + 0.055) / 1.055), 2.4) else b / 12.92;

        // observer = 2°; illuminant = D65
        return .{
            .x = r * 0.4124 + g * 0.3576 + b * 0.1805,
            .y = r * 0.2126 + g * 0.7152 + b * 0.0722,
            .z = r * 0.0193 + g * 0.1192 + b * 0.9505,
        };
    }

    pub fn as_hex(s: *RGB) usize {
        return @as(usize, s.r) << 16 | @as(usize, s.g) << 8 | @as(usize, s.b);
    }

    pub fn from_hex(rgb: usize) RGB {
        return .{
            .r = @intCast(u8, (rgb >> 16) & 0xFF),
            .g = @intCast(u8, (rgb >> 08) & 0xFF),
            .b = @intCast(u8, (rgb >> 00) & 0xFF),
        };
    }
}; // XXX: et tu, zig?
// }}}

// Hue, Saturation, Value
// {{{
pub const HSV = extern struct {
    h: f64,
    s: f64,
    v: f64,

    pub fn new(h: f64, s: f64, v: f64) HSV {
        return .{ .h = h, .s = s, .v = v };
    }

    pub fn expectNearlyEq(want: HSV, have: HSV) void {
        if ((want.h - have.h) >= 1.0) {
            std.debug.panic("Expect HSV.h {}, found {}", .{ want.h, have.h });
        }
        if ((want.s - have.s) >= 1.0) {
            std.debug.panic("Expect HSV.s {}, found {}", .{ want.s, have.s });
        }
        if ((want.v - have.v) >= 1.0) {
            std.debug.panic("Expect HSV.v {}, found {}", .{ want.v, have.v });
        }
    }

    pub fn to_rgb(hsv: *const HSV) RGB {
        const h = hsv.h;
        const s = hsv.s / 100;
        const v = hsv.v / 100;

        if (s <= 0.0) {
            return .{
                .r = @floatToInt(u8, v),
                .g = @floatToInt(u8, v),
                .b = @floatToInt(u8, v),
            };
        }

        const hh = (if (h >= 360.0) 0.0 else h) / 60.0;
        const i = @floatToInt(usize, hh);
        const ff = hh - @intToFloat(f64, i);
        const p = v * (1.0 - s);
        const q = v * (1.0 - (s * ff));
        const t = v * (1.0 - (s * (1.0 - ff)));

        var tr: f64 = 0.0;
        var tg: f64 = 0.0;
        var tb: f64 = 0.0;

        // XXX: switch cases are lovely
        switch (@floatToInt(usize, math.round(h / 60.0))) {
            0 => {
                tr = v;
                tg = t;
                tb = p;
            },
            1 => {
                tr = q;
                tg = v;
                tb = p;
            },
            2 => {
                tr = p;
                tg = v;
                tb = t;
            },
            3 => {
                tr = p;
                tg = q;
                tb = v;
            },
            else => {
                tr = v;
                tg = p;
                tb = q;
            },
        }

        return .{
            .r = @floatToInt(u8, math.round(tr * 255.0)),
            .g = @floatToInt(u8, math.round(tg * 255.0)),
            .b = @floatToInt(u8, math.round(tb * 255.0)),
        };
    }
};
// }}}

// Hue, Saturation, Lightness
/// {{{
pub const HSL = extern struct {
    h: f64,
    s: f64,
    l: f64,

    pub fn new(h: f64, s: f64, l: f64) HSL {
        return .{ .h = h, .s = s, .l = l };
    }

    fn _hue_to_rgb(p: f64, q: f64, _t: f64) f64 {
        // XXX: let me assign to my params!
        var t = _t;

        if (t < 0.0) t += 1.0;
        if (t > 1.0) t -= 1.0;

        if (t < 1.0 / 6.0)
            return p + (q - p) * 6.0 * t;
        if (t < 1.0 / 2.0)
            return q;
        if (t < 2.0 / 3.0)
            return p + (q - p) * (2.0 / 3.0 - t) * 6.0;

        return p;
    }

    pub fn to_rgb(hsl: *const HSL) RGB {
        const h = hsl.h / 360.0;
        const s = hsl.s / 100.0;
        const l = hsl.l / 100.0;

        var r: f64 = 0.0;
        var g: f64 = 0.0;
        var b: f64 = 0.0;

        if (s == 0.0) { // achromatic
            r = l;
            g = l;
            b = l;
        } else {
            var q = if (l < 0.5) l * (1.0 + s) else l + s - l * s;
            var p = 2.0 * l - q;

            r = _hue_to_rgb(p, q, h + (1.0 / 3.0));
            g = _hue_to_rgb(p, q, h);
            b = _hue_to_rgb(p, q, h - (1.0 / 3.0));
        }

        return .{
            .r = @floatToInt(u8, math.round(r * 255.0)),
            .g = @floatToInt(u8, math.round(g * 255.0)),
            .b = @floatToInt(u8, math.round(b * 255.0)),
        };
    }

    pub fn expectNearlyEq(want: HSL, have: HSL) void {
        if ((want.h - have.h) >= 1.0) {
            std.debug.panic("Expect hsl({}, {}, {}), found hsl({}, {}, {})", .{ want.h, want.s, want.l, have.h, have.s, have.l });
        }
        if ((want.s - have.s) >= 1.0) {
            std.debug.panic("Expect hsl({}, {}, {}), found hsl({}, {}, {})", .{ want.h, want.s, want.l, have.h, have.s, have.l });
        }
        if ((want.l - have.l) >= 1.0) {
            std.debug.panic("Expect hsl({}, {}, {}), found hsl({}, {}, {})", .{ want.h, want.s, want.l, have.h, have.s, have.l });
        }
    }
};
// }}}

// CIE 1931 colorspace
// https://en.wikipedia.org/wiki/CIE_1931_color_space
// {{{
pub const XYZ = extern struct {
    x: f64,
    y: f64,
    z: f64,

    pub fn new(x: f64, y: f64, z: f64) XYZ {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn to_lms(xyz: *const XYZ) LMS {
        return .{
            .l = 0.38971 * xyz.x + 0.68898 * xyz.y - 0.07868 * xyz.z,
            .m = -0.22981 * xyz.x + 1.18340 * xyz.y + 0.04641 * xyz.z,
            .s = 0.00000 * xyz.x + 0.00000 * xyz.y + 1.00000 * xyz.z,
        };
    }

    fn _adj(f: f64) f64 {
        // if (math.fabs(f) < 0.0031308) {
        //     return 12.92 * f;
        // }
        // return 1.055 * math.pow(f64, f, 0.41666) - 0.055;
        return f;
    }

    pub fn to_rgb(xyz: *const XYZ) RGB {
        const r = 3.2404542 * xyz.x - 1.5371385 * xyz.y - 0.4985314 * xyz.z;
        const g = -0.9692660 * xyz.x + 1.8760108 * xyz.y + 0.0415560 * xyz.z;
        const b = 0.0556434 * xyz.x - 0.2040259 * xyz.y + 1.0572252 * xyz.z;

        return .{
            .r = @floatToInt(u8, math.clamp(math.round(r * 255), 0, 255)),
            .g = @floatToInt(u8, math.clamp(math.round(g * 255), 0, 255)),
            .b = @floatToInt(u8, math.clamp(math.round(b * 255), 0, 255)),
        };
    }

    pub fn expectNearlyEq(want: XYZ, have: XYZ) void {
        const diff = .{ .x = want.x - have.x, .y = want.y - have.y, .z = want.z - have.z };
        if (diff.x >= 1.0 or diff.y >= 1.0 or diff.z >= 1.0) {
            std.debug.panic("Expect xyz({:.2}, {:.2}, {:.2}), found xyz({:.2}, {:.2}, {:.2})", .{ want.x, want.y, want.z, have.x, have.y, have.z });
        }
    }
};
// }}}

// LMS (long, medium, short) colorspace
// https://en.wikipedia.org/wiki/LMS_color_space
// {{{
pub const LMS = extern struct {
    l: f64,
    m: f64,
    s: f64,

    pub fn to_xyz(lms: *const LMS) XYZ {
        return .{
            .x = 1.91020 * lms.l - 1.112_120 * lms.m + 0.201_908 * lms.s,
            .y = 0.37095 * lms.l + 0.629_054 * lms.m + 0.000_000 * lms.s,
            .z = 0.00000 * lms.l + 0.000_000 * lms.m + 1.000_000 * lms.s,
        };
    }

    // https://ixora.io/projects/colorblindness/color-blindness-simulation-research/
    pub fn adjust_for_colorblindness(lms: *LMS, cb: ColorblindnessFlavor) LMS {
        return switch (cb) {
            .Protanopia => .{
                // Missing L cones
                .l = 1.051_182_94 * lms.m - 0.051_160_99 * lms.s,
                .m = lms.m,
                .s = lms.s,
            },
            .Deuteranopia => .{
                // Missing M cones
                .l = lms.l,
                .m = 0.951_309_2 * lms.l + 0.048_669_92 * lms.s,
                .s = lms.s,
            },
            .Tritanopia => .{
                // Missing S cones
                .l = lms.l,
                .m = lms.m,
                .s = -0.867_447_36 * lms.l + 1.867_270_89 * lms.m,
            },
        };
    }
};
// }}}

// C wrapper functions, works around ABI problems
// {{{

// XXX: No C ABI, huh?
export fn rgb_to_hsv(rgb: *RGB, out: *HSV) void {
    const tmp = rgb.to_hsv();
    out.h = tmp.h;
    out.s = tmp.s;
    out.v = tmp.v;
}

export fn rgb_to_hsl(rgb: *RGB, out: *HSL) void {
    const tmp = rgb.to_hsl();
    out.h = tmp.h;
    out.s = tmp.s;
    out.l = tmp.l;
}

export fn rgb_to_xyz(rgb: *RGB, out: *XYZ) void {
    const tmp = rgb.to_xyz();
    out.x = tmp.x;
    out.y = tmp.y;
    out.z = tmp.z;
}

export fn hsv_to_rgb(hsv: *HSV, out: *RGB) void {
    const tmp = hsv.to_rgb();
    out.r = tmp.r;
    out.g = tmp.g;
    out.b = tmp.b;
}

export fn hsl_to_rgb(hsl: *HSL, out: *RGB) void {
    const tmp = hsl.to_rgb();
    out.r = tmp.r;
    out.g = tmp.g;
    out.b = tmp.b;
}

export fn xyz_to_rgb(xyz: *XYZ, out: *RGB) void {
    const tmp = xyz.to_rgb();
    out.r = tmp.r;
    out.g = tmp.g;
    out.b = tmp.b;
}

export fn xyz_to_lms(xyz: *XYZ, out: *LMS) void {
    const tmp = xyz.to_lms();
    out.l = tmp.l;
    out.m = tmp.m;
    out.s = tmp.s;
}

export fn lms_adjust_for_colorblindness(lms: *LMS, cb: ColorblindnessFlavor, out: *LMS) void {
    const tmp = lms.adjust_for_colorblindness(cb);
    out.l = tmp.l;
    out.m = tmp.m;
    out.s = tmp.s;
}

export fn lms_to_xyz(lms: *LMS, out: *XYZ) void {
    const tmp = lms.to_xyz();
    out.x = tmp.x;
    out.y = tmp.y;
    out.z = tmp.z;
}

// }}}

// Tests
// {{{
test "hsv->rgb" {
    RGB.from_hex(0x1fc8d1).expectNearlyEq(HSV.new(183, 85, 82).to_rgb());
    RGB.from_hex(0x8c3183).expectNearlyEq(HSV.new(306, 65, 55).to_rgb());
    RGB.from_hex(0xf2f5a6).expectNearlyEq(HSV.new(62, 32, 96).to_rgb());
    RGB.from_hex(0x32a852).expectNearlyEq(HSV.new(136, 70, 66).to_rgb());
}

test "rgb->hsv" {
    HSV.new(183, 85, 82).expectNearlyEq(RGB.from_hex(0x1fc8d1).to_hsv());
    HSV.new(306, 65, 55).expectNearlyEq(RGB.from_hex(0x8c3183).to_hsv());
    HSV.new(62, 32, 96).expectNearlyEq(RGB.from_hex(0xf2f5a6).to_hsv());
    HSV.new(136, 70, 66).expectNearlyEq(RGB.from_hex(0x32a852).to_hsv());
}

test "hsl->rgb" {
    RGB.from_hex(0xe6b3b3).expectNearlyEq(HSL.new(359, 50, 80).to_rgb());
    RGB.from_hex(0x1fc8d1).expectNearlyEq(HSL.new(183, 74, 47).to_rgb());
    RGB.from_hex(0xffffff).expectNearlyEq(HSL.new(0, 0, 100).to_rgb());
    RGB.from_hex(0x8c3183).expectNearlyEq(HSL.new(306, 48, 37).to_rgb());
    RGB.from_hex(0xf2f5a6).expectNearlyEq(HSL.new(62, 79, 81).to_rgb());
    RGB.from_hex(0x32a852).expectNearlyEq(HSL.new(136, 54, 43).to_rgb());
}

test "rgb->hsl" {
    HSL.new(0, 50, 80).expectNearlyEq(RGB.from_hex(0xe6b3b3).to_hsl());
    HSL.new(183, 74, 47).expectNearlyEq(RGB.from_hex(0x1fc8d1).to_hsl());
    HSL.new(0, 0, 100).expectNearlyEq(RGB.from_hex(0xffffff).to_hsl());
    HSL.new(306, 48, 37).expectNearlyEq(RGB.from_hex(0x8c3183).to_hsl());
    HSL.new(62, 79, 81).expectNearlyEq(RGB.from_hex(0xf2f5a6).to_hsl());
    HSL.new(136, 54, 43).expectNearlyEq(RGB.from_hex(0x32a852).to_hsl());
}

test "xyz->rgb" {
    RGB.from_hex(0xffffff).expectNearlyEq(XYZ.new(0.9505, 1.0000, 1.08900).to_rgb());
    RGB.from_hex(0xff0000).expectNearlyEq(XYZ.new(0.4123, 0.2126, 0.01933).to_rgb());
}

test "rgb->hsl->rgb" {
    var hue: usize = 359;
    while (hue > 0) : (hue -= 1) {
        const hsl1 = HSL.new(@intToFloat(f64, hue), 50, 80);
        const rgb1 = hsl1.to_rgb();
        const hsl2 = rgb1.to_hsl();
        const rgb2 = hsl2.to_rgb();
        rgb1.expectNearlyEq(rgb2);
    }
}

test "rgb->xyz->rgb" {
    var hue: usize = 359;
    while (hue > 0) : (hue -= 1) {
        const hsl = HSL.new(@intToFloat(f64, hue), 50, 80);

        const rgb1 = hsl.to_rgb();
        const xyz = rgb1.to_xyz();
        const rgb2 = xyz.to_rgb();
        rgb1.expectNearlyEq(rgb2);
    }
}

test "rgb->xyz->lms->xyz->rgb" {
    var hue: usize = 359;
    while (hue > 0) : (hue -= 1) {
        const hsl = HSL.new(@intToFloat(f64, hue), 50, 80);

        const rgb1 = hsl.to_rgb();
        const xyz1 = rgb1.to_xyz();
        const lms = xyz1.to_lms();
        const xyz2 = lms.to_xyz();
        const rgb2 = xyz2.to_rgb();
        xyz1.expectNearlyEq(xyz2);
        rgb1.expectNearlyEq(rgb2);
    }
}
// }}}

// XXX: test framework stops on first failed test?
