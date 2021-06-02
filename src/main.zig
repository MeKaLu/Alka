const std = @import("std");
const alka = @import("alka.zig");

const audio = alka.audio;
usingnamespace alka.log;

pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

fn runMain() !void {}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    try runMain();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
