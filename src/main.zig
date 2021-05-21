const std = @import("std");
const alka = @import("alka.zig");

usingnamespace alka.log;

pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

fn update(dt: f32) !void {}

fn fupdate(dt: f32) !void {}

fn draw() !void {}

fn resize(w: i32, h: i32) void {}

fn close() void {}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const callbacks = alka.Callbacks{
        .update = update,
        .fixed = fupdate,
        .draw = draw,
        .resize = resize,
        .close = close,
    };

    try alka.init(&gpa.allocator, callbacks, 1024, 768, "main", 0, false);

    var w = alka.getWindow();
    try w.setIcon(alka.getAllocator(), "assets/test.png");

    try alka.open();
    try alka.update();
    try alka.close();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
