const std = @import("std");
const alka = @import("alka.zig");
const m = alka.math;

usingnamespace alka.log;
pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .enable_memory_limit = false,
    }){};
    //gpa.setRequestedMemoryLimit(1048 * 1000 * 5);

    const PositionStore = alka.ecs.StoreComponent("Position", m.Vec2f);
    const SizeStore = alka.ecs.StoreComponent("Size", m.Vec3f);
    const TitleStore = alka.ecs.StoreComponent("Title", []const u8);
    const World = alka.ecs.World(struct { pos: PositionStore, size: SizeStore, title: TitleStore });

    var world = try World.init(&gpa.allocator);

    const ent1 = try world.entity.create("entity 1");
    const ent2 = try world.entity.create("entity 2");
    const ent4 = try world.entity.create("entity 4");
    {
        var group = try World.Group.create(&world);
        defer group.destroy();

        world.pushGroup(&group);
        defer world.popGroup();
        {
            try world.addComponentID(ent1, "Size", m.Vec3f{ .x = 20 });
            try world.addComponentID(ent1, "Position", m.Vec2f{ .x = 20 });
            try world.addComponentName("entity 2", "Position", m.Vec2f{ .x = 20 });
            try world.addComponentName("entity 4", "Position", m.Vec2f{ .x = 20 });

            try world.pushEntityID(ent1);
            //try world.pushEntityName("entity 1");
            try world.removeComponent("Position");
        }

        const comps = [_][]const u8{ "Position", "Size" };
        //const vlist = try world.view(comps.len, comps);
        //defer vlist.deinit();

        var it = World.Group.iterator(comps.len, comps){ .group = group };
        while (it.next()) |entity| {
            if (entity.value) |id|
                mlog.info("view id: {}", .{id});
        }
    }
    world.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
