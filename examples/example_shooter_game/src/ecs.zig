const std = @import("std");
const alka = @import("alka");

usingnamespace alka.math;
usingnamespace alka.log;

const mlog = std.log.scoped(.app);

const ecs = alka.ecs;

const game = @import("game.zig");

const maxent = 1024;

pub const PlayerController = struct {
    left: *const alka.input.State = undefined,
    right: *const alka.input.State = undefined,
    up: *const alka.input.State = undefined,
    down: *const alka.input.State = undefined,

    dash: *const alka.input.State = undefined,

    dash_max: f32 = 0,
    dash_counter: f32 = 0,
    dash_timer_max: f32 = 0.5,
    dash_timer: f32 = 0,
    dash_start: bool = false,
};

pub const Motion = struct {
    velocity: Vec2f = Vec2f{},
    motion: Vec2f = Vec2f{},
    constant: Vec2f = Vec2f{},

    maxspeed: Vec2f = Vec2f{},

    acc: f32 = 0,
    friction: f32 = 0,
};

pub const Fabric = struct {
    maxtime: f32 = 1,
    ctime: f32 = 0,
    counter: u32 = 0,

    reloadtime: f32 = 0,
    deloadtime: f32 = 0,
    reloadc: f32 = 0,
    reloadcc: f32 = 0,

    state: u8 = 0, // 0: reload, 1: unload

    spawn: fn (self: u64) anyerror!void = undefined,
};

pub const EnemyFabricController = struct {
    torque: f32 = 0,
    torquec: f32 = 0,
    speedup: f32 = 0,

    hearts: u32 = 3,
};

pub const World = ecs.World(struct {
    plcontroller: ecs.StoreComponent("Player Controller", PlayerController, 1),

    motion: ecs.StoreComponent("Motion", Motion, maxent),
    ro: ecs.StoreComponent("Enemy Fabric Controller", EnemyFabricController, maxent),

    tr: ecs.StoreComponent("Transform", Transform2D, maxent),
    col: ecs.StoreComponent("Colour", alka.Colour, maxent),
    mask: ecs.StoreComponent("Collision Mask", []const u8, maxent),

    texturedraw: ecs.StoreComponent("Texture Draw", u64, maxent),
    rectdraw: ecs.StoreComponent("Rectangle Draw", i1, maxent),

    fab: alka.ecs.StoreComponent("Fabric", Fabric, maxent),
});

pub const SpecialEntities = enum {
    player,
    wall_left,
    wall_right,
    wall_top,
    wall_bottom,
};

pub var world = World{};
pub var is_init = false;

pub var abortfunc = false;

pub fn init() !void {
    defer is_init = true;

    world = try World.init(alka.getAllocator());
}

pub fn deinit() void {
    defer is_init = false;
    world.deinit();
}

pub fn update(dt: f32) !void {
    defer abortfunc = false;
    {
        comptime const comps = [_][]const u8{
            "Motion",
            "Transform",
            "Player Controller",
        };

        const mpos = alka.getMousePosition();

        var it = World.iterator(comps.len, comps){ .world = &world };
        while (it.next()) |entry| {
            if (abortfunc) break;
            if (entry.value) |entity| {
                var c = try entity.getPtr("Player Controller", PlayerController);
                var tr = try entity.getPtr("Transform", Transform2D);
                var mot = try entity.getPtr("Motion", Motion);

                tr.rotation = tr.getOriginated().angle(mpos) + 90;

                if (c.left.* == .down) {
                    mot.motion.x = -mot.acc;
                } else if (c.right.* == .down) {
                    mot.motion.x = mot.acc;
                } else mot.motion.x = 0;

                if (c.up.* == .down) {
                    mot.motion.y = -mot.acc;
                } else if (c.down.* == .down) {
                    mot.motion.y = mot.acc;
                } else mot.motion.y = 0;

                if (c.dash.* == .down and c.dash_counter <= 0) {
                    const pos0 = tr.getOriginated();
                    const pos1 = alka.getMousePosition();
                    const angle = pos1.angleRad(pos0);
                    const toward = Vec2f{
                        .x = @cos(angle),
                        .y = @sin(angle),
                    };

                    mot.motion = toward.mulValues(-1000, -1000);
                    c.dash_counter = c.dash_max;
                    c.dash_timer = c.dash_timer_max;
                    c.dash_start = true;
                }

                if (c.dash_counter > 0) {
                    c.dash_counter -= 1 * dt;
                } else {
                    c.dash_counter = 0;
                }

                if (c.dash_start and c.dash_timer > 0) {
                    c.dash_timer -= 1 * dt;
                } else c.dash_start = false;
            }
        }
    }

    {
        comptime const comps = [_][]const u8{
            "Motion",
        };

        var it = World.iterator(comps.len, comps){ .world = &world };
        while (it.next()) |entry| {
            if (abortfunc) break;
            if (entry.value) |entity| {
                var mot = try entity.getPtr("Motion", Motion);

                mot.velocity.x += blk: {
                    var res = mot.motion.x + mot.constant.x;
                    if (mot.velocity.x < -0.1) res += mot.friction;
                    if (mot.velocity.x > 0.1) res -= mot.friction;
                    break :blk res * dt;
                };
                if (mot.velocity.x > mot.maxspeed.x) {
                    mot.velocity.x = mot.maxspeed.x;
                } else if (mot.velocity.x < -mot.maxspeed.x) mot.velocity.x = -mot.maxspeed.x;

                mot.velocity.y += blk: {
                    var res = mot.motion.y + mot.constant.y;
                    if (mot.velocity.y < -0.1) res += mot.friction;
                    if (mot.velocity.y > 0.1) res -= mot.friction;
                    break :blk res * dt;
                };
                if (mot.velocity.y > mot.maxspeed.y) {
                    mot.velocity.y = mot.maxspeed.y;
                } else if (mot.velocity.y < -mot.maxspeed.y) mot.velocity.y = -mot.maxspeed.y;

                if (!(mot.constant.x > 0 or mot.constant.x < 0)) {
                    if (mot.velocity.x >= -0.1 and mot.velocity.x <= 0.1) mot.velocity.x = 0;
                }
                if (!(mot.constant.y > 0 or mot.constant.y < 0)) {
                    if (mot.velocity.y >= -0.1 and mot.velocity.y <= 0.1) mot.velocity.y = 0;
                }

                mot.motion = Vec2f{};
            }
        }
    }

    {
        comptime const comps = [_][]const u8{
            "Fabric",
        };
        var it = World.iterator(comps.len, comps){ .world = &world };

        while (it.next()) |entry| {
            if (abortfunc) break;
            if (entry.value) |entity| {
                var fab = try entity.getPtr("Fabric", Fabric);

                if (fab.reloadc >= 0 and fab.reloadc < fab.deloadtime and fab.reloadcc >= fab.reloadtime) {
                    if (fab.ctime <= 0) {
                        try fab.spawn(entity.id);
                        fab.ctime = fab.maxtime;
                    } else fab.ctime -= 1 * dt;
                    fab.state = 1;
                    fab.reloadc += 1 * dt;
                } else {
                    if (fab.reloadcc < fab.reloadtime) {
                        fab.reloadcc += 1 * dt;
                        fab.state = 0;
                    }
                    if (fab.reloadc >= fab.deloadtime) {
                        fab.reloadc = 0;
                        fab.reloadcc = 0;
                    }
                }
            }
        }
    }

    {
        comptime const comps = [_][]const u8{
            "Enemy Fabric Controller",
            "Fabric",
        };
        var it = World.iterator(comps.len, comps){ .world = &world };

        while (it.next()) |entry| {
            if (abortfunc) break;
            if (entry.value) |entity| {
                const fab = try entity.get("Fabric", Fabric);
                var fcontrol = try entity.getPtr("Enemy Fabric Controller", EnemyFabricController);

                if (fab.state == 0)
                    fcontrol.torquec += fcontrol.torque * dt;
                if (fab.state == 1)
                    fcontrol.torquec += fcontrol.speedup * dt;
            }
        }
    }
}

pub fn fixed(dt: f32) !void {
    defer abortfunc = false;

    {
        comptime const comps = [_][]const u8{
            "Enemy Fabric Controller",
            "Transform",
        };
        var it = World.iterator(comps.len, comps){ .world = &world };

        while (it.next()) |entry| {
            if (abortfunc) break;
            if (entry.value) |entity| {
                var tr = try entity.getPtr("Transform", Transform2D);
                var fcontrol = try entity.getPtr("Enemy Fabric Controller", EnemyFabricController);

                tr.rotation += fcontrol.torquec;
                fcontrol.torquec = 0;
            }
        }
    }

    {
        comptime const comps = [_][]const u8{
            "Transform",
            "Motion",
        };
        var it = World.iterator(comps.len, comps){ .world = &world };

        while (it.next()) |entry| {
            if (abortfunc) break;
            if (entry.value) |entity| {
                var tr = try entity.getPtr("Transform", Transform2D);
                const mot = try entity.get("Motion", Motion);

                try moveAndCollide(entity);
                tr.position = tr.position.add(mot.velocity);
            }
        }
    }
}

pub fn draw() !void {
    const asset = alka.getAssetManager();

    {
        comptime const comps = [_][]const u8{ "Transform", "Colour", "Rectangle Draw" };

        var it = World.iterator(comps.len, comps){ .world = &world };
        while (it.next()) |entry| {
            if (entry.value) |entity| {
                const tr = try entity.get("Transform", Transform2D);
                const colour = try entity.get("Colour", alka.Colour);

                // collision box
                try alka.drawRectangleAdv(tr.getRectangleNoOrigin(), tr.origin, deg2radf(tr.rotation), colour);
            }
        }
    }

    {
        comptime const comps = [_][]const u8{ "Enemy Fabric Controller", "Transform", "Colour", "Texture Draw" };

        var it = World.iterator(comps.len, comps){ .world = &world };
        while (it.next()) |entry| {
            if (entry.value) |entity| {
                var tr = try entity.get("Transform", Transform2D);
                const colour = try entity.get("Colour", alka.Colour);
                const fcontrol = try entity.get("Enemy Fabric Controller", EnemyFabricController);

                const texture = try asset.getTexture(10);

                var i: u32 = 0;
                tr.position.y -= tr.size.y;
                tr.size =
                    Vec2f{
                    .x = @intToFloat(f32, texture.width) * 3.5,
                    .y = @intToFloat(f32, texture.height) * 3.5,
                };
                tr.origin = tr.size.divValues(2, 2);
                const x: f32 = tr.size.x;
                while (i < fcontrol.hearts) : (i += 1) {
                    var rect = tr.getRectangleNoOrigin();
                    rect.position.x += x * @intToFloat(f32, i) - tr.size.x;
                    try alka.drawTextureAdv(10, rect, Rectangle{
                        .size = Vec2f{
                            .x = @intToFloat(f32, texture.width),
                            .y = @intToFloat(f32, texture.height),
                        },
                    }, tr.origin, 0, colour);
                }
            }
        }
    }

    {
        comptime const comps = [_][]const u8{ "Transform", "Colour", "Texture Draw" };

        var it = World.iterator(comps.len, comps){ .world = &world };
        while (it.next()) |entry| {
            if (entry.value) |entity| {
                const tr = try entity.get("Transform", Transform2D);
                const colour = try entity.get("Colour", alka.Colour);
                const texture_id = try entity.get("Texture Draw", u64);

                const texture = try asset.getTexture(texture_id);

                // collision box
                try alka.drawRectangleLines(tr.getRectangle(), colour);

                try alka.drawTextureAdv(texture_id, tr.getRectangleNoOrigin(), Rectangle{
                    .size = Vec2f{
                        .x = @intToFloat(f32, texture.width),
                        .y = @intToFloat(f32, texture.height),
                    },
                }, tr.origin, deg2radf(tr.rotation), colour);
            }
        }
    }
}

fn moveAndCollide(entity: *World.Register) !void {
    const tr = try entity.get("Transform", Transform2D);
    const mask = try entity.get("Collision Mask", []const u8);
    var motion = try entity.getPtr("Motion", Motion);

    const off: f32 = 6.5;
    const push: f32 = 2;

    var tmot = Motion{};

    {
        comptime const comps = [_][]const u8{
            "Transform",
            "Collision Mask",
        };
        var it = World.iterator(comps.len, comps){ .world = &world };
        while (it.next()) |entry| {
            if (entry.value) |oentity| {
                if (entity.id == oentity.id) continue;

                const omask = try oentity.get("Collision Mask", []const u8);
                const otr = try oentity.get("Transform", Transform2D);
                const omot = oentity.getPtr("Motion", Motion) catch &tmot;

                var collided = false;
                var destroy = false;
                var odestroy = false;

                if (std.mem.eql(u8, mask, "Enemy Fabric Controller")) {
                    if (std.mem.eql(u8, omask, "Enemy Kamikaze")) {
                        continue;
                    }
                } else if (std.mem.eql(u8, mask, "Enemy Kamikaze")) {
                    if (std.mem.eql(u8, omask, "Enemy Fabric Controller")) {
                        continue;
                    }
                }
                if (std.mem.eql(u8, mask, omask)) {
                    continue;
                }

                if (tr.aabb(otr)) collided = true;

                if (motion.velocity.x <= -0.1 and tr.aabbMeeting(otr, Vec2f{ .x = -off })) {
                    motion.velocity.x = -(motion.velocity.x - push - omot.velocity.x);
                    omot.velocity.x = -(motion.velocity.x - push - omot.velocity.x);

                    collided = true;
                } else if (motion.velocity.x >= 0.1 and tr.aabbMeeting(otr, Vec2f{ .x = off })) {
                    motion.velocity.x = -(motion.velocity.x + push + omot.velocity.x);
                    omot.velocity.x = -(motion.velocity.x + push + omot.velocity.x);

                    collided = true;
                }

                if (motion.velocity.y <= -0.1 and tr.aabbMeeting(otr, Vec2f{ .y = -off })) {
                    motion.velocity.y = -(motion.velocity.y - push - omot.velocity.y);
                    omot.velocity.y = -(motion.velocity.y - push - omot.velocity.y);

                    collided = true;
                } else if (motion.velocity.y >= 0.1 and tr.aabbMeeting(otr, Vec2f{ .y = off })) {
                    motion.velocity.y = -(motion.velocity.y + push + omot.velocity.y);
                    omot.velocity.y = -(motion.velocity.y + push + omot.velocity.y);

                    collided = true;
                }

                if (collided) {
                    const factor: f32 = @intToFloat(f32, game.rand.intRangeAtMost(i32, 1, 2)) * game.rand.float(f32);
                    if (entity.id != @enumToInt(SpecialEntities.player)) {
                        if (std.mem.eql(u8, omask, "Wall")) {
                            destroy = true;
                        } else if (std.mem.eql(u8, omask, "Player")) {
                            game.scoreDecrease(game.score_decreasec_kamikaze, factor);
                            destroy = true;
                        }
                    } else {
                        if (std.mem.eql(u8, omask, "Enemy Kamikaze")) {
                            game.scoreDecrease(game.score_decreasec_kamikaze, factor);
                            odestroy = true;
                        } else if (std.mem.eql(u8, omask, "Enemy Fabric Controller")) {
                            var cnt = try entity.getPtr("Player Controller", PlayerController);

                            if (cnt.dash_start) {
                                game.scoreIncrease(game.score_increasec_kamikaze, factor);

                                odestroy = try heartDecreaseEnemyFabricController(oentity);
                                if (odestroy) game.scoreIncrease(game.score_increasec_station, factor);
                                cnt.dash_start = false;
                            }
                        }
                    }
                }

                if (odestroy) {
                    oentity.destroy();
                    try world.removeRegister(oentity.id);
                    abortfunc = true;
                }

                if (destroy) {
                    entity.destroy();
                    try world.removeRegister(entity.id);
                    abortfunc = true;
                }

                if (abortfunc) return;
            }
        }
    }
}

fn heartDecreaseEnemyFabricController(en: *World.Register) !bool {
    var fcontrol = try en.getPtr("Enemy Fabric Controller", EnemyFabricController);
    fcontrol.hearts -= 1;
    if (fcontrol.hearts == 0) return true;
    return false;
}
