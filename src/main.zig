const std = @import("std");
const alka = @import("alka.zig");
const m = alka.math;

usingnamespace alka.log;
pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .debug;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .enable_memory_limit = true,
    }){};
    gpa.setRequestedMemoryLimit(1048 * 100 * 100 * 2);

    const PositionStore = alka.ecs.StoreComponent("Position", m.Vec2f);
    const SizeStore = alka.ecs.StoreComponent("Size", m.Vec3f);
    const TitleStore = alka.ecs.StoreComponent("Title", []const u8);
    const World = alka.ecs.World(struct { p: PositionStore, s: SizeStore, t: TitleStore });
    {
        var world = try World.init(&gpa.allocator);
        defer world.deinit();

        var reg = try world.createRegister(0);

        try reg.create();
        defer reg.destroy();

        try reg.attach("Position", m.Vec2f{ .x = 20 });
        try reg.attach("Size", m.Vec3f{ .x = 20 });

        var pos = try reg.getPtr("Position", m.Vec2f);
        pos.y = 26;

        //try reg.detach("Position");
        //try reg.attach("Position", m.Vec2f{ .x = 20 });

        mlog.notice("pos: {s}", .{try reg.get("Position", m.Vec2f)});

        const comps = [_][]const u8{ "Position", "Size" };
        mlog.err("{}", .{reg.hasThese(comps.len, comps)});

        var it = World.iterator(comps.len, comps){ .world = &world };

        while (it.next()) |entry| {
            if (entry.value) |entity|
                mlog.notice("entity: {}", .{entity});
        }
    }

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
