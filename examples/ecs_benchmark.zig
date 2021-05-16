const std = @import("std");
const alka = @import("alka");
const m = alka.math;

usingnamespace alka.log;
pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .debug;

const RectangleStore = alka.ecs.StoreComponent("Rectangle", m.Rectangle);
const ColourStore = alka.ecs.StoreComponent("Colour", alka.Colour);
const World = alka.ecs.World(struct { r: RectangleStore, col: ColourStore });

const maxent: u64 = 1024 * 100;

var world: World = undefined;

fn update(dt: f32) !void {
    const comps = [_][]const u8{"Rectangle"};
    var it = World.iterator(comps.len, comps){ .world = &world };

    while (it.next()) |entry| {
        if (entry.value) |entity| {
            var rect = try entity.getPtr("Rectangle", m.Rectangle);
            rect.position.x += 50 * dt;
        }
    }
}

fn draw() !void {
    const comps = [_][]const u8{ "Rectangle", "Colour" };

    var it = World.iterator(comps.len, comps){ .world = &world };

    while (it.next()) |entry| {
        if (entry.value) |entity| {
            const rect = try entity.get("Rectangle", m.Rectangle);
            const colour = try entity.get("Colour", alka.Colour);

            try alka.drawRectangle(rect, colour);
        }
    }

    const asset = alka.getAssetManager();
    const font = try asset.getFont(0);

    const col = alka.Colour{ .r = 1, .g = 1, .b = 1, .a = 1 };

    const debug = try alka.getDebug();
    defer alka.getAllocator().free(debug);
    try alka.drawText(0, debug, m.Vec2f{ .x = 20, .y = 20 }, 24, col);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .enable_memory_limit = false,
    }){};
    //gpa.setRequestedMemoryLimit(1048 * 1000 * 5);

    const callbacks = alka.Callbacks{
        .update = update,
        .fixed = null,
        .draw = draw,
        .resize = null,
        .close = null,
    };

    try alka.init(&gpa.allocator, callbacks, 1024, 768, "ECS Benchmark", 1000, false);

    try alka.getAssetManager().loadFont(0, "assets/arial.ttf", 128);
    const font = try alka.getAssetManager().getFont(0);
    font.texture.setFilter(alka.gl.TextureParamater.filter_mipmap_nearest, alka.gl.TextureParamater.filter_linear);

    world = try World.init(&gpa.allocator);
    {
        var i: u64 = 0;
        while (i < maxent) : (i += 1) {
            var reg = try world.createRegister(i);
            try reg.create();

            try reg.attach("Rectangle", m.Rectangle{
                .position = m.Vec2f{ .x = @intToFloat(f32, i) / 2, .y = @intToFloat(f32, i) / 2 },
                .size = m.Vec2f{ .x = 20, .y = 30 },
            });

            try reg.attach("Colour", alka.Colour.rgba(255, 255, 255, 255));
            mlog.info("created {}", .{i});
        }
    }

    try alka.open();
    try alka.update();
    try alka.close();

    {
        var i: u64 = 0;
        while (i < maxent) : (i += 1) {
            const reg = try world.getRegister(i);
            reg.destroy();
        }
    }

    world.deinit();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
