const std = @import("std");
const alka = @import("alka.zig");

const m = alka.math;
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

fn draw() !void {
    const r = m.Rectangle{ .position = m.Vec2f{ .x = 100.0, .y = 200.0 }, .size = m.Vec2f{ .x = 50.0, .y = 50.0 } };
    const col = alka.Colour{ .r = 1, .g = 1, .b = 1, .a = 1 };
    //try alka.drawRectangleAdv(r, m.Vec2f{ .x = 25, .y = 25 }, m.deg2radf(45), col);
    try alka.drawRectangleLinesAdv(r, m.Vec2f{ .x = 25, .y = 25 }, m.deg2radf(125), col);

    const r2 = m.Rectangle{ .position = m.Vec2f{ .x = 200.0, .y = 200.0 }, .size = m.Vec2f{ .x = 30.0, .y = 30.0 } };
    const col2 = alka.Colour.rgba(30, 80, 200, 255);
    //try alka.drawRectangle(r2, col2);
    try alka.drawRectangleLines(r2, col2);

    // position, radius, colour
    // segment count is 16 by default
    //try alka.drawCircleLines(m.Vec2f{ .x = 350, .y = 260 }, 24, col);
    //try alka.drawCircle(m.Vec2f{ .x = 450, .y = 260 }, 24, col);
    // position, radius, segment count, startangle, endangle, colour
    try alka.drawCircleLinesV(m.Vec2f{ .x = 350, .y = 260 }, 24, 8, 0, 360, col);

    try alka.drawCircleLinesV(m.Vec2f{ .x = 350, .y = 360 }, 24, 32, 0, 360, col);

    try alka.drawCircleV(m.Vec2f{ .x = 450, .y = 260 }, 24, 32, 0, 360, col);
    try alka.drawCircleV(m.Vec2f{ .x = 450, .y = 360 }, 24, 8, 0, 360, col);

    // start, end, thickness, colour
    try alka.drawLine(m.Vec2f{ .x = 300, .y = 300 }, m.Vec2f{ .x = 400, .y = 350 }, 1, col);

    var i: f32 = 0;
    while (i < 10) : (i += 2) {
        try alka.drawPixel(m.Vec2f{ .x = 300 + i, .y = 400 }, col);
    }
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

    try alka.init(&gpa.allocator, callbacks, 1024, 768, "Forced Shader", 0, false);

    try alka.getAssetManager().loadShader(1, vertex_shader, fragment_shader);

    try alka.open();
    try alka.update();
    try alka.close();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
