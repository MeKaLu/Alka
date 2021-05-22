const std = @import("std");
const alka = @import("alka");

usingnamespace alka.log;

pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

const virtualwidth: i32 = 1280;
const virtualheight: i32 = 720;

fn update(dt: f32) !void {
    mlog.notice("update", .{});
}

fn fupdate(dt: f32) !void {
    mlog.notice("fixed update", .{});
}

fn draw() !void {
    mlog.notice("draw", .{});
}

// cannot let out error, it's a C callback
fn resize(w: i32, h: i32) void {
    mlog.notice("resize", .{});
    alka.autoResize(virtualwidth, virtualheight, w, h);
}

// cannot let out error, it's a C callback
fn close() void {
    mlog.notice("close", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const callbacks = alka.Callbacks{
        .update = update,
        .fixed = fupdate,
        .draw = draw,
        .resize = resize,
        .close = close,
    };

    // .. fpslimit if zero vsync=on, is resizable?
    try alka.init(&gpa.allocator, callbacks, 1024, 768, "Basic Setup", 0, false);
    alka.autoResize(virtualwidth, virtualheight, 1024, 768);

    // opens the window
    try alka.open();
    // runs the loop
    try alka.update();
    // closes the window
    try alka.close();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
