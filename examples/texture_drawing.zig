const std = @import("std");
const alka = @import("alka");
const core = @import("alka_core");

const m = core.math;
usingnamespace core.log;

pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

fn draw() !void {
    const asset = alka.getAssetManager();
    const testpng = try asset.getTexture(1);

    const srect = m.Rectangle{ .position = m.Vec2f{ .x = 0.0, .y = 0.0 }, .size = m.Vec2f{ .x = @intToFloat(f32, testpng.width), .y = @intToFloat(f32, testpng.height) } };

    const r = m.Rectangle{ .position = m.Vec2f{ .x = 100.0, .y = 200.0 }, .size = m.Vec2f{ .x = 50.0, .y = 50.0 } };
    const col = alka.Colour{ .r = 1, .g = 1, .b = 1, .a = 1 };
    // id, rect, source rect, origin, angle in radians, colour
    try alka.drawTextureAdv(1, r, srect, m.Vec2f{ .x = 25, .y = 25 }, m.deg2radf(45), col);

    const r2 = m.Rectangle{ .position = m.Vec2f{ .x = 300.0, .y = 200.0 }, .size = m.Vec2f{ .x = 50.0, .y = 50.0 } };
    const col2 = alka.Colour.rgba(30, 80, 200, 255);
    // id, rect, source rect, colour
    try alka.drawTexture(1, r2, srect, col2);
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

    try alka.init(callbacks, 1024, 768, "Texture Drawing", 0, false, &gpa.allocator);

    // id, path
    try alka.getAssetManager().loadTexture(1, "assets/test.png");
    {
        const texture = try alka.getAssetManager().getTexture(1);
        // min, mag
        texture.setFilter(core.gl.TextureParamater.filter_nearest, core.gl.TextureParamater.filter_nearest);
    }

    // or
    {
        const texture = try core.renderer.Texture.createFromPNG(&gpa.allocator, "assets/test.png");
        try alka.getAssetManager().loadTexturePro(2, texture);
    }

    // or
    {
        const mem = @embedFile("../assets/test.png");
        const texture = try core.renderer.Texture.createFromPNGMemory(mem);
        try alka.getAssetManager().loadTexturePro(3, texture);
        // or
        try alka.getAssetManager().loadTextureFromMemory(4, mem);
    }

    try alka.open();
    try alka.update();
    try alka.close();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
