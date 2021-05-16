const std = @import("std");
const alka = @import("alka");
const m = alka.math;

usingnamespace alka.log;
pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .debug;

const RectangleStore = alka.ecs.StoreComponent("Rectangle", m.Rectangle);
const ColourStore = alka.ecs.StoreComponent("Colour", alka.Colour);
const World = alka.ecs.World(struct { r: RectangleStore, col: ColourStore });

var world: World = undefined;
var group: World.Group = undefined;

fn update(dt: f32) !void {
    //mlog.debug("fps: {}", .{alka.getFps()});
}

fn draw() !void {
    const comps = [_][]const u8{ "Rectangle", "Colour" };

    // bad performance
    if (1 == 0) {
        const vlist = try world.view(comps.len, comps);
        defer vlist.deinit();

        var it = vlist.iterator();
        while (it.next()) |entity| {
            if (it.index > 1024 * 5) break;
            try world.pushEntityID(entity.id);

            const rect = try world.getComponent("Rectangle", m.Rectangle);
            const col = try world.getComponent("Colour", alka.Colour);

            try alka.drawRectangle(rect, col);
        }
    }

    // same as iterator
    if (1 == 0) {
        const vlist = try world.viewFixed(1024 * 5, comps.len, comps);
        var i: usize = 0;
        while (i < vlist.len) : (i += 1) {
            if (vlist[i]) |id| {
                try world.pushEntityID(id);

                const rect = try world.getComponent("Rectangle", m.Rectangle);
                const col = try world.getComponent("Colour", alka.Colour);

                try alka.drawRectangle(rect, col);
            }
        }
    }

    // bad, just not bad as view()
    if (1 == 0) {
        var it = World.Group.iterator(comps.len, comps){ .group = group };
        while (it.next()) |entity| {
            if (it.index > 1024 * 5) break;
            if (entity.value) |id| {
                try world.pushEntityID(id);

                const rect = try world.getComponent("Rectangle", m.Rectangle);
                const col = try world.getComponent("Colour", alka.Colour);

                try alka.drawRectangle(rect, col);
            }
        }
    }

    // better than iterator
    if (1 == 1) {
        var it = world.entity.registers.iterator();
        while (it.next()) |entry| {
            if (it.index > 1024 * 5) break;
            if (entry.data != null) {
                const component_names = comptime std.meta.fieldNames(World.T);

                const id = entry.id;

                var hasAll = true;
                var rect: m.Rectangle = undefined;
                var col: alka.Colour = undefined;

                inline for (component_names) |name| {
                    const typ = @TypeOf(@field(group.registers, name));
                    if (typ == RectangleStore) {
                        rect = try @field(group.registers, name).get(id);
                    } else if (typ == ColourStore) {
                        col = try @field(group.registers, name).get(id);
                    } else hasAll = false;
                }

                if (hasAll) {
                    try alka.drawRectangle(rect, col);
                }
            }
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
    group = try World.Group.create(&world);
    world.pushGroup(&group);
    {
        var i: u64 = 1;
        while (i < 1024 * 20) : (i += 1) {
            try world.entity.createID(i);
            try world.addComponentID(i, "Rectangle", m.Rectangle{
                .position = m.Vec2f{ .x = 200, .y = 300 },
                .size = m.Vec2f{ .x = 20, .y = 30 },
            });

            try world.addComponentID(i, "Colour", alka.Colour.rgba(255, 255, 255, 255));
            mlog.info("created {}", .{i});
        }
    }

    try alka.open();
    try alka.update();
    try alka.close();

    world.popGroup();
    group.destroy();
    world.deinit();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
