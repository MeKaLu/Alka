const std = @import("std");
const alka = @import("alka");
const core = @import("alka_core");

usingnamespace core.log;

pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const callbacks = alka.Callbacks{
        .update = null,
        .fixed = null,
        .draw = null,
        .resize = null,
        .close = null,
    };

    try alka.init(callbacks, 1024, 768, "Basic Setup", 0, false, &gpa.allocator);

    try alka.open();
    try alka.update();
    try alka.close();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
