const std = @import("std");
const alka = @import("alka");
const m = alka.math;

usingnamespace alka.log;
pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .debug;

const RectangleStore = alka.ecs.StoreComponent("Rectangle", m.Rectangle, maxent);
const ColourStore = alka.ecs.StoreComponent("Colour", alka.Colour, maxent);
const World = alka.ecs.World(struct { r: RectangleStore, col: ColourStore });

const maxent: u64 = 1024 * 100;
var random: *std.rand.Random = undefined;

var world: World = undefined;

var mouseleftPtr: *const alka.input.State = undefined;
var index: u64 = 0;

fn createEntity(i: u64) !void {
    var reg = try world.createRegister(i);
    try reg.create();

    try reg.attach("Rectangle", m.Rectangle{
        .position = alka.getMousePosition(),
        .size = m.Vec2f{
            .x = @intToFloat(f32, random.intRangeAtMost(i32, 10, 50)),
            .y = @intToFloat(f32, random.intRangeAtMost(i32, 10, 50)),
        },
    });

    try reg.attach("Colour", alka.Colour.rgba(255, 255, 255, 255));
    mlog.info("created {}", .{i});
}

fn update(dt: f32) !void {
    if (mouseleftPtr.* == alka.input.State.down) {
        if (index < maxent) {
            var i: u64 = index;
            while (i < index + 10) : (i += 1) {
                try createEntity(i);
            }
            index = i;
        }
    }

    const comps = [_][]const u8{"Rectangle"};

    var it = World.iterator(comps.len, comps){ .world = &world };
    while (it.next()) |entry| {
        if (entry.value) |entity| {
            var rect = try entity.getPtr("Rectangle", m.Rectangle);
            const speed: f32 = 200 * @intToFloat(f32, random.intRangeAtMost(i32, -1, 1));

            if (rect.position.x < 1024) {
                rect.position.x += speed * dt;
            } else rect.position.x -= speed * dt;

            if (rect.position.y < 1024) {
                rect.position.y -= speed * dt;
            } else rect.position.y += speed * dt;
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

    const col = alka.Colour.rgba(200, 30, 70, 255);

    var debug = try alka.getDebug();
    defer alka.getAllocator().free(debug);

    try alka.drawText(0, debug, m.Vec2f{ .x = 20, .y = 20 }, 24, col);

    debug = try std.fmt.bufPrint(debug, "total: {}", .{index});
    try alka.drawText(0, debug, m.Vec2f{ .x = 20, .y = 45 }, 24, col);
}

fn close() void {
    var i: u64 = 0;
    while (i < maxent) : (i += 1) {
        const reg = world.getRegister(i) catch continue;
        reg.destroy();
        world.removeRegister(i) catch continue;
        mlog.info("destroyed {}", .{i});
    }
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
        .close = close,
    };

    try alka.init(&gpa.allocator, callbacks, 1024, 768, "ECS Benchmark", 1000, false);

    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    random = &prng.random;

    var input = alka.getInput();
    try input.bindMouse(alka.input.Mouse.ButtonLeft);
    mouseleftPtr = try input.mouseStatePtr(alka.input.Mouse.ButtonLeft);

    try alka.getAssetManager().loadFont(0, "assets/arial.ttf", 128);
    const font = try alka.getAssetManager().getFont(0);
    font.texture.setFilter(alka.gl.TextureParamater.filter_mipmap_nearest, alka.gl.TextureParamater.filter_linear);

    world = try World.init(&gpa.allocator);

    try alka.open();
    try alka.update();
    try alka.close();

    world.deinit();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
