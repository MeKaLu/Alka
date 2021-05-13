const std = @import("std");
const alka = @import("alka");
const core = @import("alka_core");

const m = core.math;
usingnamespace core.log;

pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

fn draw() !void {
    const r = m.Rectangle{ .position = m.Vec2f{ .x = 100.0, .y = 200.0 }, .size = m.Vec2f{ .x = 50.0, .y = 50.0 } };
    const col = alka.Colour{ .r = 1, .g = 1, .b = 1, .a = 1 };
    try alka.drawRectangleAdv(r, m.Vec2f{ .x = 25, .y = 25 }, m.deg2radf(45), col);
    //try alka.drawRectangleLinesAdv(r, m.Vec2f{ .x = 25, .y = 25 }, m.deg2radf(45), col);

    const r2 = m.Rectangle{ .position = m.Vec2f{ .x = 200.0, .y = 200.0 }, .size = m.Vec2f{ .x = 30.0, .y = 30.0 } };
    const col2 = alka.Colour.rgba(30, 80, 200, 255);
    try alka.drawRectangle(r2, col2);
    //try alka.drawRectangleLines(r2, col2);

    // start, end, thickness, colour
    try alka.drawLine(m.Vec2f{ .x = 300, .y = 300 }, m.Vec2f{ .x = 400, .y = 350 }, 1, col);

    var i: f32 = 0;
    while (i < 10) : (i += 2) {
        try alka.drawPixel(m.Vec2f{ .x = 300 + i, .y = 400 }, col);
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const callbacks = alka.Callbacks{
        .update = null,
        .fixed = null,
        .draw = draw,
        .resize = null,
        .close = null,
    };

    try alka.init(callbacks, 1024, 768, "Shape Drawing", 0, false, &gpa.allocator);

    try alka.open();
    try alka.update();
    try alka.close();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
