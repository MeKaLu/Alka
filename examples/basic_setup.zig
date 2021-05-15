const std = @import("std");
const alka = @import("alka");

usingnamespace alka.log;

pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

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

    try alka.init(callbacks, 1024, 768, "Basic Setup", 0, false, &gpa.allocator);

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
