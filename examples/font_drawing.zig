const std = @import("std");
const alka = @import("alka");
const core = @import("alka_core");

const m = core.math;
usingnamespace core.log;

pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

fn draw() !void {
    const asset = alka.getAssetManager();
    const staticfont = try asset.getTexture(1);
    const font = try asset.getFont(0);

    const r = m.Rectangle{ .position = m.Vec2f{ .x = 200.0, .y = 200.0 }, .size = m.Vec2f{ .x = 500.0, .y = 500.0 } };
    const srect = m.Rectangle{ .position = m.Vec2f{ .x = 0.0, .y = 0.0 }, .size = m.Vec2f{ .x = @intToFloat(f32, staticfont.width), .y = @intToFloat(f32, staticfont.height) } };
    const col = alka.Colour{ .r = 1, .g = 1, .b = 1, .a = 1 };

    try alka.drawTexture(1, r, srect, col);

    // id, position, size, colour
    try alka.drawTextPoint(0, 'A', m.Vec2f{ .x = 200, .y = 300 }, 24, col);
    try alka.drawTextPoint(0, 'L', m.Vec2f{ .x = 200 + 15, .y = 300 }, 24, col);
    try alka.drawTextPoint(0, 'K', m.Vec2f{ .x = 200 + 15 * 2, .y = 300 }, 24, col);
    try alka.drawTextPoint(0, 'A', m.Vec2f{ .x = 200 + 15 * 3, .y = 300 }, 24, col);

    try alka.drawText(0, "This is rendered on the fly!", m.Vec2f{ .x = 100, .y = 500 }, 32, col);

    const alloc = alka.getAllocator();
    var debug: []u8 = try alloc.alloc(u8, 255);
    defer alloc.free(debug);
    debug = try std.fmt.bufPrintZ(debug, "fps: {}", .{alka.getFps()});

    try alka.drawText(0, debug, m.Vec2f{ .x = 20, .y = 20 }, 24, col);
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

    try alka.init(callbacks, 1024, 768, "Font Drawing", 0, false, &gpa.allocator);

    // .. bitmap width & height, pixel size
    const texture = try core.renderer.Texture.createFromTTF(&gpa.allocator, "assets/arial.ttf", "Hello", 500, 500, 24);
    // min, mag
    texture.setFilter(core.gl.TextureParamater.filter_mipmap_nearest, core.gl.TextureParamater.filter_linear);
    // id, texture
    try alka.getAssetManager().loadTexturePro(1, texture); // texture 0 & shader 0 is reserved for defaults

    // id, path, pixel size
    try alka.getAssetManager().loadFont(0, "assets/arial.ttf", 128);
    const font = try alka.getAssetManager().getFont(0);
    // min, mag
    font.texture.setFilter(core.gl.TextureParamater.filter_mipmap_nearest, core.gl.TextureParamater.filter_linear);

    try alka.open();
    try alka.update();
    try alka.close();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
