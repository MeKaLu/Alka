const std = @import("std");
const alka = @import("alka.zig");
const core = @import("core/core.zig");

usingnamespace core.log;
pub const log_level: std.log.Level = .debug;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const callbacks = alka.Callbacks{
        .update = null,
        .fixed = null,
        .draw = null,
        .resize = null,
        .close = null,
    };

    try alka.init(callbacks, 1024, 768, "hello", 0, true, &gpa.allocator);

    try alka.open();
    try alka.update();
    try alka.close();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
