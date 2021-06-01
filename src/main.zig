const std = @import("std");
const alka = @import("alka.zig");

const m = alka.math;
usingnamespace alka.log;

pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

fn draw() !void {
    alka.setBatchLayer(1);
    {
        var tr_button = m.Transform2D{
            .position = m.Vec2f{ .x = 200, .y = 200 },
            .size = m.Vec2f{ .x = 150, .y = 30 },
        };
        tr_button.origin = tr_button.size.divValues(2, 2);

        const button_colour = alka.Colour.rgba(40, 100, 200, 255);

        try alka.drawRectangle(tr_button.getRectangle(), button_colour);

        try alka.drawText(0, "Hello World!", tr_button.getOriginated(), 24, alka.Colour.rgba(0, 0, 0, 255));
    }

    alka.setBatchLayer(0);
    {
        var tr_rect = m.Transform2D{
            .position = m.Vec2f{ .x = 200, .y = 200 },
            .size = m.Vec2f{ .x = 150, .y = 30 },
        };
        tr_rect.origin = tr_rect.size.divValues(2, 2);

        const rect_colour = alka.Colour.rgba(200, 70, 120, 255);

        try alka.drawRectangleAdv(tr_rect.getRectangleNoOrigin(), tr_rect.origin, m.deg2radf(45), rect_colour);
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

    try alka.init(&gpa.allocator, callbacks, 1024, 768, "Batch Layers", 0, false);

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
