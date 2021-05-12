const std = @import("std");
const alka = @import("alka.zig");
const core = @import("core/core.zig");

usingnamespace core.log;
pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .debug;

fn update(dt: f32) !void {
    const debug = try alka.getDebug();
    defer alka.getAllocator().free(debug);
    mlog.info("{s}", .{debug});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const callbacks = alka.Callbacks{
        .update = update,
        .fixed = null,
        .draw = null,
        .resize = null,
        .close = null,
    };

    try alka.init(callbacks, 1024, 768, "title go brrr", 0, false, &gpa.allocator);

    try alka.open();
    try alka.update();
    try alka.close();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
