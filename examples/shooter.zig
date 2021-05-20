const std = @import("std");
const alka = @import("alka");

const m = alka.math;
usingnamespace alka.log;

pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const Transform = struct {
    r: m.Rectangle = m.Rectangle{},
    colour: alka.Colour = alka.Colour.rgba(255, 255, 255, 255),
};

const PlayerController = struct {
    left: *const alka.input.State = undefined,
    right: *const alka.input.State = undefined,
    up: *const alka.input.State = undefined,
    down: *const alka.input.State = undefined,

    speed: f32 = 300,
    score: f32 = 20,

    score_multiplier: f32 = 1.0, // NOTE: MAKE USE OF IT
    score_increase: f32 = 2,
    score_decrease: f32 = 5,
};

const MobController = struct {
    speed: m.Vec2f = undefined,
    directionx: f32 = 0,
};

const GeneralFabric = struct {
    maxtime: f32 = 1,
    ctime: f32 = maxtime,
    counter: u32 = 0,

    spawn: fn (self: *GeneralFabric) anyerror!void = undefined,
};

const Texture = struct {
    t: alka.renderer.Texture = undefined,
    id: u64 = undefined,
};

const max_ent = 250;

const World = alka.ecs.World(struct {
    texture: alka.ecs.StoreComponent("TextureDraw", Texture, 2),
    shape: alka.ecs.StoreComponent("RectangleDraw", bool, max_ent),

    tr: alka.ecs.StoreComponent("Transform", Transform, max_ent),
    vel: alka.ecs.StoreComponent("Velocity", m.Vec2f, max_ent),

    fab: alka.ecs.StoreComponent("Fabric", GeneralFabric, 2),
    plcontroller: alka.ecs.StoreComponent("PlayerController", PlayerController, 1), // player

    econtroller: alka.ecs.StoreComponent("MobController", MobController, max_ent),

    al: alka.ecs.StoreComponent("Alive", bool, max_ent),
    collmask: alka.ecs.StoreComponent("CollisionMask", []const u8, max_ent),
});

const player_id: u64 = 0;
const wall_left_id: u64 = 1;
const wall_right_id: u64 = 2;
const wall_top_id: u64 = 3;
const wall_bottom_id: u64 = 4;
const enemyfabric_id: u64 = 5;

var world: World = undefined;
var s_ent: std.AutoHashMap(u64, *World.Register) = undefined;
var random: *std.rand.Random = undefined;
var abortfunc = false;
var resetgame = false;
var score: *const f32 = undefined;

fn firststart() !void {
    try startup();
    try alka.update();
    try shutdown();
}

fn startup() !void {
    const callbacks = alka.Callbacks{
        .update = update,
        .fixed = fupdate,
        .draw = draw,
        .resize = resize,
        .close = close,
    };

    try alka.init(&gpa.allocator, callbacks, 1024, 768, "Shooter", 0, true);

    try alka.getInput().bindKey(.A);
    try alka.getInput().bindKey(.D);
    try alka.getInput().bindKey(.W);
    try alka.getInput().bindKey(.S);

    const t = try alka.renderer.Texture.createFromPNGMemory(@embedFile("../assets/test.png"));
    t.setFilter(.filter_nearest, .filter_nearest);
    try alka.getAssetManager().loadTexturePro(1, t);

    try alka.getAssetManager().loadFontFromMemory(0, @embedFile("../assets/arial.ttf"), 128);

    const font = try alka.getAssetManager().getFont(0);
    font.texture.setFilter(.filter_mipmap_nearest, .filter_linear);

    try open();

    try alka.open();
}

fn shutdown() !void {
    try alka.close();
    try alka.deinit();
}

fn resetGame() !void {
    close();
    try alka.close();

    abortfunc = false;
    resetgame = false;

    try open();
    try alka.open();
}

fn scoreIncrease(factor: f32) !void {
    var parent = try world.getRegisterPtr(player_id);
    var c = try parent.getPtr("PlayerController", PlayerController);

    c.score += c.score_increase * c.score_multiplier * factor;
}

fn scoreDecrease(factor: f32) !void {
    var parent = try world.getRegisterPtr(player_id);
    var c = try parent.getPtr("PlayerController", PlayerController);

    c.score -= c.score_decrease * c.score_multiplier * factor;

    if (c.score < 0) {
        // restart game
        mlog.warn("Player score is below zero, restarting the game!", .{});
        abortfunc = true;
        resetgame = true;
    }
}

fn moveAndCollide(reg: *World.Register) !void {
    const r = blk: {
        const tmp = try reg.get("Transform", Transform);
        break :blk tmp.r;
    };
    var vel = try reg.getPtr("Velocity", m.Vec2f);
    const mask = try reg.get("CollisionMask", []const u8);

    const off: f32 = 5;
    const push: f32 = 0;

    {
        comptime const comps = [_][]const u8{
            "Alive",
            "Transform",
            "CollisionMask",
        };
        var it = World.iterator(comps.len, comps){ .world = &world };

        while (it.next()) |entry| {
            if (entry.value) |oreg| {
                const a = try oreg.get("Alive", bool);
                if (!a or reg.id == oreg.id) continue;

                const ore = blk: {
                    const tmp = try oreg.get("Transform", Transform);
                    break :blk tmp.r;
                };
                const omask = try oreg.get("CollisionMask", []const u8);

                var collided = r.aabb(ore);

                if (vel.x < -0.1 and r.aabbMeeting(ore, m.Vec2f{ .x = -off })) {
                    vel.x = -push;
                    collided = true;
                } else if (vel.x > 0.1 and r.aabbMeeting(ore, m.Vec2f{ .x = off })) {
                    vel.x = push;
                    collided = true;
                }

                if (vel.y < -0.1 and r.aabbMeeting(ore, m.Vec2f{ .y = -off })) {
                    vel.y = push;
                    collided = true;
                } else if (vel.y > 0.1 and r.aabbMeeting(ore, m.Vec2f{ .y = off })) {
                    vel.y = -push;
                    collided = true;
                }

                if (collided) {
                    var destroy = false;
                    var destroyother = false;
                    var decfactor: ?f32 = null;
                    var incfactor: ?f32 = null;

                    if (reg.id != player_id) {
                        var c = reg.getPtr("MobController", MobController) catch null;

                        if (c) |ec| {
                            if (oreg.id == wall_right_id) {
                                ec.directionx = -ec.directionx;
                            } else if (oreg.id == wall_left_id) {
                                ec.directionx = m.abs(ec.directionx);
                            }
                        }

                        if (oreg.id == wall_top_id) {
                            destroy = true;
                        } else if (oreg.id == wall_bottom_id) {
                            destroy = true;
                            decfactor = 1.1;
                        } else if (oreg.id == player_id) {
                            destroy = true;
                            decfactor = 1.2;
                        } else if (std.mem.eql(u8, mask, "PlayerBullet")) {
                            if (std.mem.eql(u8, omask, "EnemyRectangle")) {
                                incfactor = 1.3;
                                destroy = true;
                                destroyother = true;
                            }
                        }
                    }

                    if (destroyother) {
                        oreg.destroy();
                        try world.removeRegister(oreg.id);
                        abortfunc = true;
                    }

                    if (destroy) {
                        if (decfactor) |factor|
                            try scoreDecrease(factor);

                        if (resetgame) return;

                        if (incfactor) |factor|
                            try scoreIncrease(factor);

                        reg.destroy();
                        try world.removeRegister(reg.id);
                        abortfunc = true;
                    }
                }
            }
        }
    }
}

fn playerbulletFabricSpawn(self: *GeneralFabric) !void {
    var reg = try world.createRegister(world.findID());

    const col = alka.Colour.rgba(230, 79, 46, 255);

    try reg.create();

    try reg.attach("RectangleDraw", true);
    try reg.attach("Alive", true);
    try reg.attach("CollisionMask", @as([]const u8, "PlayerBullet"));

    const parent = try world.getRegister(player_id);

    const plrect = blk: {
        var result = m.Rectangle{};

        const t = try parent.get("Transform", Transform);
        result = t.r;

        break :blk result;
    };

    try reg.attach("MobController", MobController{
        .speed = m.Vec2f{
            .x = 0,
            .y = -350,
        },
        .directionx = 0,
    });

    try reg.attach("Transform", Transform{
        .r = m.Rectangle{
            .position = m.Vec2f{
                .x = plrect.position.x + plrect.size.x / 2 - 2.5,
                .y = plrect.position.y - plrect.size.y / 2 - 10,
            },
            .size = m.Vec2f{
                .x = 5,
                .y = 20,
            },
        },
        .colour = col,
    });

    try reg.attach("Velocity", m.Vec2f{});
}

fn enemyFabricSpawn(self: *GeneralFabric) !void {
    var reg = try world.createRegister(world.findID());
    const w = alka.getWindow();

    try reg.create();

    try reg.attach("RectangleDraw", true);
    try reg.attach("Alive", true);
    try reg.attach("CollisionMask", @as([]const u8, "EnemyRectangle"));

    try reg.attach("MobController", MobController{
        .speed = m.Vec2f{
            .x = @intToFloat(f32, random.intRangeAtMost(i32, 100, 250)),
            .y = @intToFloat(f32, random.intRangeAtMost(i32, 100, 250)),
        },
        .directionx = @intToFloat(f32, random.intRangeAtMost(i32, -1, 1)),
    });

    try reg.attach("Transform", Transform{
        .r = m.Rectangle{
            .position = m.Vec2f{
                .x = @intToFloat(f32, random.intRangeAtMost(i32, 30, w.size.width - 50)),
                .y = -100,
            },
            .size = m.Vec2f{
                .x = 20,
                .y = 25,
            },
        },
    });

    try reg.attach("Velocity", m.Vec2f{});
}

fn open() !void {
    world = try World.init(alka.getAllocator());
    s_ent = std.AutoHashMap(u64, *World.Register).init(alka.getAllocator());

    const w = alka.getWindow();
    // create player
    {
        var reg = try world.createRegister(player_id);
        try s_ent.put(player_id, reg);

        try reg.create();

        try reg.attach("TextureDraw", Texture{
            .id = 1,
            .t = try alka.getAssetManager().getTexture(1),
        });
        try reg.attach("Alive", true);
        try reg.attach("CollisionMask", @as([]const u8, "Player"));

        const input = alka.getInput();

        try reg.attach("PlayerController", PlayerController{
            .left = try input.keyStatePtr(.A),
            .right = try input.keyStatePtr(.D),
            .up = try input.keyStatePtr(.W),
            .down = try input.keyStatePtr(.S),
        });

        try reg.attach("Fabric", GeneralFabric{
            .maxtime = 0.3,
            .ctime = 0.3,
            .counter = 0,
            .spawn = playerbulletFabricSpawn,
        });

        const pc = try reg.getPtr("PlayerController", PlayerController);
        score = &pc.score;

        const texture = try alka.getAssetManager().getTexture(1);

        try reg.attach("Transform", Transform{
            .r = m.Rectangle{
                .position = m.Vec2f{
                    .x = @intToFloat(f32, @divTrunc(w.size.width, 2) - texture.width * 2),
                    .y = @intToFloat(f32, w.size.height - texture.height * 2) - 50,
                },
                .size = m.Vec2f{
                    .x = @intToFloat(f32, texture.width) * 2,
                    .y = @intToFloat(f32, texture.height) * 2,
                },
            },
        });

        try reg.attach("Velocity", m.Vec2f{});
    }

    // create walls
    {
        const wallcol = alka.Colour.rgba(45, 99, 150, 255);
        {
            var reg = try world.createRegister(wall_left_id);
            try s_ent.put(wall_left_id, reg);

            try reg.create();

            try reg.attach("RectangleDraw", true);
            try reg.attach("Alive", true);
            try reg.attach("CollisionMask", @as([]const u8, "Wall"));

            try reg.attach("Transform", Transform{
                .r = m.Rectangle{
                    .position = m.Vec2f{
                        .x = 0,
                        .y = 0,
                    },
                    .size = m.Vec2f{
                        .x = 10,
                        .y = @intToFloat(f32, w.size.height),
                    },
                },
                .colour = wallcol,
            });
        }

        {
            var reg = try world.createRegister(wall_right_id);
            try s_ent.put(wall_right_id, reg);

            try reg.create();

            try reg.attach("RectangleDraw", true);
            try reg.attach("Alive", true);
            try reg.attach("CollisionMask", @as([]const u8, "Wall"));

            try reg.attach("Transform", Transform{
                .r = m.Rectangle{
                    .position = m.Vec2f{
                        .x = @intToFloat(f32, w.size.width) - 10,
                        .y = 0,
                    },
                    .size = m.Vec2f{
                        .x = 10,
                        .y = @intToFloat(f32, w.size.height),
                    },
                },
                .colour = wallcol,
            });
        }

        {
            var reg = try world.createRegister(wall_top_id);
            try s_ent.put(wall_top_id, reg);

            try reg.create();

            try reg.attach("RectangleDraw", true);
            try reg.attach("Alive", true);
            try reg.attach("CollisionMask", @as([]const u8, "Wall"));

            try reg.attach("Transform", Transform{
                .r = m.Rectangle{
                    .position = m.Vec2f{
                        .x = 0,
                        .y = -400,
                    },
                    .size = m.Vec2f{
                        .x = @intToFloat(f32, w.size.width),
                        .y = 10,
                    },
                },
                .colour = wallcol,
            });
        }

        {
            var reg = try world.createRegister(wall_bottom_id);
            try s_ent.put(wall_bottom_id, reg);

            try reg.create();

            try reg.attach("RectangleDraw", true);
            try reg.attach("Alive", true);
            try reg.attach("CollisionMask", @as([]const u8, "Wall"));

            try reg.attach("Transform", Transform{
                .r = m.Rectangle{
                    .position = m.Vec2f{
                        .x = 0,
                        .y = @intToFloat(f32, w.size.height) - 10,
                    },
                    .size = m.Vec2f{
                        .x = @intToFloat(f32, w.size.width),
                        .y = 10,
                    },
                },
                .colour = wallcol,
            });
        }
    }

    // create enemy fabric
    {
        var reg = try world.createRegister(enemyfabric_id);
        try s_ent.put(enemyfabric_id, reg);

        try reg.create();

        try reg.attach("Alive", true);
        try reg.attach("Fabric", GeneralFabric{
            .maxtime = 1,
            .ctime = 1,
            .counter = 0,
            .spawn = enemyFabricSpawn,
        });
    }
}

fn update(dt: f32) !void {
    if (resetgame) {
        try resetGame();
        return;
    }
    defer abortfunc = false;
    {
        comptime const comps = [_][]const u8{
            "Alive",
            "Transform",
            "Velocity",
            "MobController",
        };
        var it = World.iterator(comps.len, comps){ .world = &world };

        while (it.next()) |entry| {
            if (abortfunc) break;
            if (entry.value) |reg| {
                const a = try reg.get("Alive", bool);
                if (!a) continue;

                const tr = try reg.get("Transform", Transform);
                const c = try reg.getPtr("MobController", MobController);
                var vel = try reg.getPtr("Velocity", m.Vec2f);

                vel.* = c.speed.mulValues(dt * c.directionx, dt);
            }
        }
    }

    {
        comptime const comps = [_][]const u8{
            "Alive",
            "Transform",
            "Velocity",
            "PlayerController",
        };
        var it = World.iterator(comps.len, comps){ .world = &world };

        while (it.next()) |entry| {
            if (abortfunc) break;
            if (entry.value) |reg| {
                if (try reg.get("Alive", bool)) {
                    const tr = try reg.get("Transform", Transform);
                    const c = try reg.get("PlayerController", PlayerController);
                    var vel = try reg.getPtr("Velocity", m.Vec2f);

                    if (c.left.* == .down) {
                        vel.x = -c.speed * dt;
                    } else if (c.right.* == .down) {
                        vel.x = c.speed * dt;
                    } else vel.x = 0;

                    if (c.up.* == .down) {
                        vel.y = -c.speed * dt;
                    } else if (c.down.* == .down) {
                        vel.y = c.speed * dt;
                    } else vel.y = 0;
                }
            }
        }
    }

    {
        comptime const comps = [_][]const u8{
            "Alive",
            "Fabric",
        };
        var it = World.iterator(comps.len, comps){ .world = &world };

        while (it.next()) |entry| {
            if (abortfunc) break;
            if (entry.value) |reg| {
                const a = try reg.get("Alive", bool);
                if (!a) continue;

                var fab = try reg.getPtr("Fabric", GeneralFabric);
                if (fab.ctime <= 0) {
                    try fab.spawn(fab);
                    fab.ctime = fab.maxtime;
                } else fab.ctime -= 1 * dt;
            }
        }
    }
}

fn fupdate(dt: f32) !void {
    if (resetgame) {
        try resetGame();
        return;
    }
    defer abortfunc = false;
    {
        comptime const comps = [_][]const u8{
            "Alive",
            "Transform",
            "Velocity",
        };
        var it = World.iterator(comps.len, comps){ .world = &world };

        while (it.next()) |entry| {
            if (abortfunc) break;
            if (entry.value) |reg| {
                const a = try reg.get("Alive", bool);
                if (!a) continue;

                var tr = try reg.getPtr("Transform", Transform);
                var vel = try reg.getPtr("Velocity", m.Vec2f);

                try moveAndCollide(reg);
                tr.r.position = tr.r.position.add(vel.*);
                vel.* = m.Vec2f{};
            }
        }
    }
}

fn draw() !void {
    if (resetgame) {
        try resetGame();
        return;
    }
    defer abortfunc = false;
    {
        comptime const comps = [_][]const u8{
            "Alive",
            "Transform",
            "RectangleDraw",
        };
        var it = World.iterator(comps.len, comps){ .world = &world };

        while (it.next()) |entry| {
            if (abortfunc) break;
            if (entry.value) |reg| {
                const a = try reg.get("Alive", bool);
                if (!a) continue;

                const tr = try reg.get("Transform", Transform);
                try alka.drawRectangle(tr.r, tr.colour);
            }
        }
    }

    {
        comptime const comps = [_][]const u8{
            "Alive",
            "Transform",
            "TextureDraw",
        };
        var it = World.iterator(comps.len, comps){ .world = &world };

        while (it.next()) |entry| {
            if (abortfunc) break;
            if (entry.value) |reg| {
                if (try reg.get("Alive", bool)) {
                    const tr = try reg.get("Transform", Transform);
                    const texture = try reg.get("TextureDraw", Texture);

                    try alka.drawTexture(texture.id, tr.r, m.Rectangle{
                        .size = m.Vec2f{ .x = @intToFloat(f32, texture.t.width), .y = @intToFloat(f32, texture.t.height) },
                    }, tr.colour);
                }
            }
        }
    }

    const alloc = alka.getAllocator();
    var scoretxt: []u8 = try alloc.alloc(u8, 255);
    defer alloc.free(scoretxt);
    scoretxt = try std.fmt.bufPrintZ(scoretxt, "Score: {d:.2}", .{score.*});

    try alka.drawText(0, scoretxt, m.Vec2f{ .x = 20, .y = 20 }, 24, alka.Colour.rgba(255, 255, 255, 255));
}

fn resize(w: i32, h: i32) void {
    alka.gl.viewport(0, 0, w, h);
}

fn close() void {
    var i: u64 = 0;
    while (i < max_ent) : (i += 1) {
        const reg = world.getRegister(i) catch continue;
        reg.destroy();
        world.removeRegister(i) catch continue;
        mlog.debug("entity destroyed id: {}", .{reg.id});
    }

    s_ent.deinit();
    world.deinit();
}

pub fn main() !void {
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    random = &prng.random;

    try firststart();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
