const std = @import("std");
const alka = @import("alka.zig");
const m = alka.math;

usingnamespace alka.log;
pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

fn update(dt: f32) !void {
    const debug = try alka.getDebug();
    defer alka.getAllocator().free(debug);
    mlog.debug("{s}", .{debug});
}

fn draw() !void {}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const callbacks = alka.Callbacks{
        .update = update,
        .fixed = null,
        .draw = draw,
        .resize = null,
        .close = null,
    };

    //    try alka.init(&gpa.allocator, callbacks, 1024, 768, "title go brrr", 0, false);

    const PositionStore = alka.ecs.StoreComponent("Position", m.Vec2f);
    const SizeStore = alka.ecs.StoreComponent("Size", m.Vec2f);
    const World = alka.ecs.World(struct { pos: PositionStore, size: SizeStore });

    var world = try World.init(&gpa.allocator);

    const ent2 = try world.createEntity("entity 2");
    //try world.destroyEntity("entity 1");
    const ent1 = try world.createEntity("entity 1");
    mlog.warn("ent1 has pos: {}, ent2: {}", .{ ent1, ent2 });

    {
        var group = try World.Group.init(&gpa.allocator, &world);
        try group.add(ent1, PositionStore, m.Vec2f{ .x = 10, .y = 20 });
        try group.add(ent2, SizeStore, m.Vec2f{ .x = 0, .y = 0 });

        const vlist = try World.View(struct { pos: PositionStore }).collect(&gpa.allocator, &group);
        var it = vlist.iterator();
        while (it.next()) |entity| {
            if (entity.data) |id|
                mlog.info("view id: {}", .{id});
        }

        defer vlist.deinit();

        group.deinit();
    }
    world.deinit();

    //try alka.open();
    //try alka.update();
    //try alka.close();

    //try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
