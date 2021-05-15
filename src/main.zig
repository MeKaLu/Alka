const std = @import("std");
const alka = @import("alka.zig");

usingnamespace alka.math;
usingnamespace alka.log;
pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

const vertex_shader =
    \\#version 330 core
    \\layout (location = 0) in vec2 aPos;
    \\layout (location = 1) in vec2 aTexCoord;
    \\layout (location = 2) in vec4 aColour;
    \\
    \\out vec2 ourTexCoord;
    \\out vec4 ourColour;
    \\uniform mat4 MVP;
    \\
    \\void main() {
    \\  gl_Position = MVP * vec4(aPos.xy, 0.0, 1.0);
    \\  ourTexCoord = aTexCoord;
    \\  ourColour = aColour;
    \\}
;

const fragment_shader =
    \\#version 330 core
    \\out vec4 final;
    \\in vec2 ourTexCoord;
    \\in vec4 ourColour;
    \\uniform sampler2D uTexture;
    \\
    \\void main() {
    \\  vec4 texelColour = texture(uTexture, ourTexCoord);
    \\  final = vec4(1, 0, 0, 1) * texelColour; // everything is red
    \\}
;

fn update(dt: f32) !void {
    const debug = try alka.getDebug();
    defer alka.getAllocator().free(debug);
    mlog.debug("{s}", .{debug});
}

fn draw() !void {
    var asset = alka.getAssetManager();
    const staticfont = try asset.getTexture(2);
    const font = try asset.getFont(0);
    const col = alka.Colour{ .r = 1, .g = 1, .b = 1, .a = 1 };

    var batch = try alka.createBatch(alka.gl.DrawMode.triangles, 1, 0);

    alka.pushBatch(batch);
    const r = Rectangle{ .position = Vec2f{ .x = 100.0, .y = 200.0 }, .size = Vec2f{ .x = 50.0, .y = 50.0 } };
    //try alka.drawRectangleAdv(r, Vec2f{ .x = 25, .y = 25 }, deg2radf(45), col);
    try alka.drawRectangleLinesAdv(r, Vec2f{ .x = 25, .y = 25 }, deg2radf(45), col);
    //try alka.drawRectangleLines(r, col);
    alka.popBatch();

    // start, end, thickness, colour
    try alka.drawLine(Vec2f{ .x = 300, .y = 300 }, Vec2f{ .x = 400, .y = 350 }, 1, col);

    const r2 = Rectangle{ .position = Vec2f{ .x = 200.0, .y = 200.0 }, .size = Vec2f{ .x = 500.0, .y = 500.0 } };
    const rs2 = Rectangle{ .position = Vec2f{ .x = 0.0, .y = 0.0 }, .size = Vec2f{ .x = @intToFloat(f32, staticfont.width), .y = @intToFloat(f32, staticfont.height) } };
    //try alka.drawTexture(1, r2, rs2, col);

    var i: f32 = 0;
    while (i < 10) : (i += 2) {
        try alka.drawPixel(Vec2f{ .x = 300 + i, .y = 200 }, col);
    }

    try alka.drawTexture(2, r2, rs2, col);

    try alka.drawTextPoint(0, 'A', Vec2f{ .x = 200, .y = 300 }, 24, col);
    try alka.drawTextPoint(0, 'L', Vec2f{ .x = 200 + 15, .y = 300 }, 24, col);
    try alka.drawTextPoint(0, 'K', Vec2f{ .x = 200 + 15 * 2, .y = 300 }, 24, col);
    try alka.drawTextPoint(0, 'A', Vec2f{ .x = 200 + 15 * 3, .y = 300 }, 24, col);

    try alka.drawText(0, "Hello World!", Vec2f{ .x = 100, .y = 500 }, 48, col);
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

    try alka.init(&gpa.allocator, callbacks, 1024, 768, "title go brrr", 0, false);

    try alka.getAssetManager().loadShader(1, vertex_shader, fragment_shader);
    try alka.getAssetManager().loadTexture(1, "assets/test.png");

    const texture = try alka.renderer.Texture.createFromTTF(&gpa.allocator, "assets/arial.ttf", "Hello", 500, 500, 24);
    texture.setFilter(alka.gl.TextureParamater.filter_mipmap_nearest, alka.gl.TextureParamater.filter_linear);

    try alka.getAssetManager().loadTexturePro(2, texture);

    try alka.getAssetManager().loadFont(0, "assets/arial.ttf", 128);

    const font = try alka.getAssetManager().getFont(0);
    font.texture.setFilter(alka.gl.TextureParamater.filter_mipmap_nearest, alka.gl.TextureParamater.filter_linear);

    try alka.open();
    try alka.update();
    try alka.close();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
