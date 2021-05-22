const std = @import("std");
const alka = @import("alka.zig");

usingnamespace alka.log;

pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

const virtualwidth: i32 = 1024;
const virtualheight: i32 = 768;

fn update(dt: f32) !void {}

fn fupdate(dt: f32) !void {}

fn draw() !void {}

fn resize(w: i32, h: i32) void {
    mlog.notice("resize", .{});
    alka.autoResize(virtualwidth, virtualheight, w, h);
}

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

    try alka.init(&gpa.allocator, callbacks, 1024, 768, "Basic Setup", 0, true);
    alka.autoResize(virtualwidth, virtualheight, 1024, 768);

    try alka.open();
    try alka.update();
    try alka.close();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
