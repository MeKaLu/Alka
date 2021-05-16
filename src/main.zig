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

    //    try alka.init(&gpa.allocator, callbacks, 1024, 768, "title go brrr", 0, false);

    const PositionStore = alka.ecs.StoreComponent("Position", m.Vec2f);
    const SizeStore = alka.ecs.StoreComponent("Size", m.Vec3f);
    const TitleStore = alka.ecs.StoreComponent("Title", []const u8);
    const World = alka.ecs.World(struct { pos: PositionStore, size: SizeStore, title: TitleStore });

    var world = try World.init(&gpa.allocator);

    const ent1 = try world.entity.create("entity 1");
    const ent2 = try world.entity.create("entity 2");
    const ent4 = try world.entity.create("entity 4");
    mlog.warn("ent1 has pos: {}, ent2: {}", .{ ent1, ent2 });

    {
        var group = try World.Group.create(&world);
        defer group.destroy();

        world.pushGroup(&group);
        defer world.popGroup();
        {
            //try world.addComponent("entity 1", "Position", m.Vec2f{ .x = 20 });
            try world.addComponentName("entity 2", "Position", m.Vec2f{ .x = 20 });
            try world.addComponentName("entity 4", "Position", m.Vec2f{ .x = 20 });
            // try world.removeComponent("entity 1", "Position");

        }

        const comps = [_][]const u8{"Position"};
        //const vlist = try world.view(comps.len, comps);
        //defer vlist.deinit();

        var it = World.Group.iterator(comps.len, comps){ .group = group };
        while (it.next()) |entity| {
            if (entity.value) |id|
                mlog.info("view id: {}", .{id});
        }
    }
    world.deinit();

    //try alka.open();
    //try alka.update();
    //try alka.close();

    //try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
