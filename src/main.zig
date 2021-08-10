const std = @import("std");
const alka = @import("alka.zig");
const m = alka.math;

usingnamespace alka.log;
pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .debug;

const RectangleStore = alka.ecs.StoreComponent("Rectangle", m.Rectangle, maxent);
const SpeedStore = alka.ecs.StoreComponent("Speed", f32, maxent);
const VelocityStore = alka.ecs.StoreComponent("Velocity", m.Vec2f, maxent);
const ColourStore = alka.ecs.StoreComponent("Colour", alka.Colour, maxent);
const World = alka.ecs.World(struct { r: RectangleStore, col: ColourStore, sp: SpeedStore, vl: VelocityStore });

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

    const speed: f32 = 200 * @intToFloat(f32, random.intRangeAtMost(i32, -1, 1));
    try reg.attach("Speed", speed);

    try reg.attach("Velocity", m.Vec2f{});

    try reg.attach("Colour", alka.Colour.rgba(random.intRangeAtMost(u8, 0, 200), random.intRangeAtMost(u8, 0, 200), random.intRangeAtMost(u8, 0, 200), 255));
    //mlog.info("created {}", .{i});
}

fn update(dt: f32) !void {
    if (mouseleftPtr.* == alka.input.State.down) {
        if (index < maxent) {
            var i: u64 = index;
            while (i < index + 1) : (i += 1) {
                try createEntity(i);
            }
            index = i;
        }
    }

    const comps = [_][]const u8{ "Velocity", "Speed", "Rectangle" };

    var it = World.iterator(comps.len, comps){ .world = &world };
    while (it.next()) |entry| {
        if (entry.value) |entity| {
            var vel = try entity.getPtr("Velocity", m.Vec2f);
            var speed = try entity.getPtr("Speed", f32);
            const rect = try entity.get("Rectangle", m.Rectangle);

            if (rect.position.x > 1024 - rect.size.x) {
                speed.* = -speed.*;
            } else if (rect.position.x < 0) {
                speed.* = m.abs(speed.*);
            }

            vel.x += speed.* * dt;
        }
    }
}

fn fupdate(dt: f32) !void {
    const comps = [_][]const u8{ "Velocity", "Rectangle" };

    var it = World.iterator(comps.len, comps){ .world = &world };
    while (it.next()) |entry| {
        if (entry.value) |entity| {
            var rect = try entity.getPtr("Rectangle", m.Rectangle);
            var vel = try entity.getPtr("Velocity", m.Vec2f);

            rect.position.x += vel.x;
            vel.* = m.Vec2f{};
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
    mlog.info("{s}", .{debug});

    debug = try std.fmt.bufPrint(debug, "total: {}", .{index});
    try alka.drawText(0, debug, m.Vec2f{ .x = 20, .y = 45 }, 24, col);
    mlog.info("{s}", .{debug});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .enable_memory_limit = false,
    }){};
    //gpa.setRequestedMemoryLimit(1048 * 1000 * 5);

    const callbacks = alka.Callbacks{
        .update = update,
        .fixed = fupdate,
        .draw = draw,
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
