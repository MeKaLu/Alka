const std = @import("std");
const alka = @import("alka.zig");

const m = alka.math;
usingnamespace alka.log;

pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

fn fupdate(dt: f32) !void {
    alka.getCamera2DPtr().offset.x += 100 * dt;
}

fn draw() !void {
    const r = m.Rectangle{ .position = m.Vec2f{ .x = 100.0, .y = 200.0 }, .size = m.Vec2f{ .x = 50.0, .y = 50.0 } };
    const col = alka.Colour{ .r = 1, .g = 1, .b = 1, .a = 1 };
    try alka.drawRectangleAdv(r, m.Vec2f{ .x = 25, .y = 25 }, m.deg2radf(45), col);

    const r2 = m.Rectangle{ .position = m.Vec2f{ .x = 200.0, .y = 200.0 }, .size = m.Vec2f{ .x = 30.0, .y = 30.0 } };
    const col2 = alka.Colour.rgba(30, 80, 200, 255);
    try alka.drawRectangle(r2, col2);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const callbacks = alka.Callbacks{
        .update = null,
        .fixed = fupdate,
        .draw = draw,
        .resize = null,
        .close = null,
    };

    try alka.init(&gpa.allocator, callbacks, 1024, 768, "Camera 2D", 0, false);

    try alka.open();
    try alka.update();
    try alka.close();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
