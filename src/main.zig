const std = @import("std");
const alka = @import("alka.zig");

const m = alka.math;
usingnamespace alka.log;

pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

fn draw() !void {
    const asset = alka.getAssetManager();
    const font = try asset.getFont(0);

    const r = m.Rectangle{ .position = m.Vec2f{ .x = 200.0, .y = 200.0 }, .size = m.Vec2f{ .x = 500.0, .y = 500.0 } };
    const col = alka.Colour{ .r = 1, .g = 1, .b = 1, .a = 1 };

    try alka.drawCircleLines(m.Vec2f{ .x = 200, .y = 300 }, 24, col);

    var debug = try alka.getDebug();
    defer alka.getAllocator().free(debug);

    try alka.drawText(0, debug, m.Vec2f{ .x = 20, .y = 20 }, 24, col);

    try alka.drawText(0, "This is rendered on the\n fly!", m.Vec2f{ .x = 0, .y = 600 }, 32, col);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const callbacks = alka.Callbacks{
        .update = null,
        .fixed = null,
        .draw = draw,
        .resize = null,
        .close = null,
    };

    try alka.init(&gpa.allocator, callbacks, 1024, 768, "main", 0, false);

    // id, path, pixel size
    try alka.getAssetManager().loadFont(0, "assets/arial.ttf", 128);
    const font = try alka.getAssetManager().getFont(0);
    // min, mag
    font.texture.setFilter(alka.gl.TextureParamater.filter_mipmap_nearest, alka.gl.TextureParamater.filter_linear);

    try alka.open();
    try alka.update();
    try alka.close();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
