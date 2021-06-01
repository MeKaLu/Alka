const std = @import("std");
const alka = @import("alka");

const gui = @import("gui.zig");
const game = @import("game.zig");

usingnamespace alka.log;

pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .debug;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const callbacks = alka.Callbacks{
        .update = game.update,
        .fixed = game.fupdate,
        .draw = game.draw,
        .close = game.close,
    };

    try alka.init(&gpa.allocator, callbacks, 1024, 768, "App", 0, false);
    alka.setBackgroundColour(0.18, 0.18, 0.18);

    {
        try alka.getAssetManager().loadTexture(1, "assets/kenney_simplespace/ship_F.png");
        const texture = try alka.getAssetManager().getTexture(1);
        texture.setFilter(.filter_nearest, .filter_nearest);
    }

    {
        try alka.getAssetManager().loadTexture(2, "assets/kenney_simplespace/enemy_A.png");
        const texture = try alka.getAssetManager().getTexture(2);
        texture.setFilter(.filter_nearest, .filter_nearest);
    }

    {
        try alka.getAssetManager().loadTexture(3, "assets/kenney_simplespace/station_B.png");
        const texture = try alka.getAssetManager().getTexture(3);
        texture.setFilter(.filter_nearest, .filter_nearest);
    }

    {
        try alka.getAssetManager().loadTexture(10, "assets/station_heart.png");
        const texture = try alka.getAssetManager().getTexture(10);
        texture.setFilter(.filter_nearest, .filter_nearest);
    }

    try alka.getAssetManager().loadFont(0, "assets/VCR_OSD_MONO.ttf", 128);
    const font = try alka.getAssetManager().getFont(0);
    font.texture.setFilter(.filter_nearest, .filter_nearest);

    var input = alka.getInput();
    try input.bindMouse(.ButtonLeft);

    try input.bindKey(.A);
    try input.bindKey(.D);
    try input.bindKey(.W);
    try input.bindKey(.S);

    try input.bindKey(.LeftShift);

    try gui.init();

    try game.open();
    try game.run();

    try gui.deinit();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
