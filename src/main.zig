const std = @import("std");
const alka = @import("alka.zig");
const m = alka.math;

usingnamespace alka.log;
pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

fn update(dt: f32) !void {
    const debug = try alka.getDebug();
    defer alka.getAllocator().free(debug);
    mlog.debug("{s}", .{debug});
}

fn draw() !void {}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const callbacks = alka.Callbacks{
        .update = update,
        .fixed = null,
        .draw = draw,
        .resize = null,
        .close = null,
    };

    try alka.init(&gpa.allocator, callbacks, 1024, 768, "title go brrr", 0, false);

    var list = try alka.utils.UniqueListGeneric(f32).init(&gpa.allocator, 0);

    try list.append(0, 10.2);
    try list.append(1, 15.5);
    try list.append(5, 25.0);

    //try list.remove(5);

    const lzero = try list.get(0);
    const lone = try list.get(1);
    const lfive = try list.get(5);

    mlog.info("zero: {d}", .{lzero});
    mlog.info("one: {d}", .{lone});
    mlog.info("five: {d}", .{lfive});

    list.deinit();

    //try alka.open();
    //try alka.update();
    //try alka.close();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
