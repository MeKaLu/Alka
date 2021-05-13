const std = @import("std");
const alka = @import("alka.zig");
const core = @import("core/core.zig");

usingnamespace core.math;
usingnamespace core.log;
pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

fn update(dt: f32) !void {
    const debug = try alka.getDebug();
    defer alka.getAllocator().free(debug);
    mlog.debug("{s}", .{debug});
}

fn draw() !void {
    var asset = alka.getAssetManager();
    const defshader = try asset.getShader(0);
    const deftexture = try asset.getTexture(0);
    const testpng = try asset.getTexture(1);
    const staticfont = try asset.getTexture(2);
    const font = try asset.getFont(0);

    //var batch = try alka.createBatch(core.gl.DrawMode.triangles, defshader, deftexture);

    const r = Rectangle{ .position = Vec2f{ .x = 100.0, .y = 200.0 }, .size = Vec2f{ .x = 50.0, .y = 50.0 } };
    const col = alka.Colour{ .r = 1, .g = 1, .b = 1, .a = 1 };
    //try alka.drawRectangle(r, col);

    try alka.drawRectangleAdv(r, Vec2f{ .x = 25, .y = 25 }, deg2radf(45), col);

    const r2 = Rectangle{ .position = Vec2f{ .x = 200.0, .y = 200.0 }, .size = Vec2f{ .x = 500.0, .y = 500.0 } };
    const rs2 = Rectangle{ .position = Vec2f{ .x = 0.0, .y = 0.0 }, .size = Vec2f{ .x = @intToFloat(f32, staticfont.width), .y = @intToFloat(f32, staticfont.height) } };
    //try alka.drawTexture(1, r2, rs2, col);

    try alka.drawTexture(2, r2, rs2, col);

    try alka.drawTextPoint(0, 'A', Vec2f{ .x = 200, .y = 300 }, 24, col);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const callbacks = alka.Callbacks{
        .update = update,
        .fixed = null,
        .draw = draw,
        .resize = null,
        .close = null,
    };

    try alka.init(callbacks, 1024, 768, "title go brrr", 0, false, &gpa.allocator);

    try alka.getAssetManager().loadTexture(1, "assets/test.png");

    const texture = try core.renderer.Texture.createFromTTF(&gpa.allocator, "assets/arial.ttf", "Hello", 500, 500, 24);
    try alka.getAssetManager().loadTexturePro(2, texture);

    try alka.getAssetManager().loadFont(0, "assets/arial.ttf", 50);

    try alka.open();
    try alka.update();
    try alka.close();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
