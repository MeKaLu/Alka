const std = @import("std");
const alka = @import("alka");

const gui = alka.gui;

const ecs = @import("ecs.zig");

usingnamespace alka.math;
usingnamespace alka.log;
const mlog = std.log.scoped(.app);

pub const State = enum {
    reset,
    menu,
    play,
};

pub var state = State.menu;
pub var score: f32 = 0;
pub var highscore: f32 = 0;

pub const score_increasec_station: f32 = 7.5;
pub const score_increasec_kamikaze: f32 = 2.0;
pub const score_decreasec_kamikaze: f32 = 2.5;
pub var rand: *std.rand.Random = undefined;

pub var score_increase_rate: f32 = 0.0008;
pub var score_increase: f32 = 1;
pub var enemy_station_shoot_rate: f32 = 0.0012;
pub var enemy_station_shoot: f32 = 1;

pub fn open() !void {
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    rand = &prng.random;

    try ecs.init();
    try alka.open();
}

pub fn run() !void {
    try alka.update();
}

pub fn update(dt: f32) !void {
    if (state == .play) {
        score_increase += score_increase_rate * dt;
        enemy_station_shoot += enemy_station_shoot_rate * dt;
        mlog.notice("score_increase: {d:.5}", .{score_increase});
        mlog.notice("enemy station shoot: {d:.5}", .{enemy_station_shoot});
        try ecs.update(dt);
    } else if (state == .reset) {
        state = .menu;
        try eclose();
    }
    try gui.update(dt);
}

pub fn fupdate(dt: f32) !void {
    if (state == .play) {
        try ecs.fixed(dt);
    } else if (state == .reset) {
        state = .menu;
        try eclose();
    }
    try gui.fixed(dt);
}

pub fn draw() !void {
    try gui.draw();
    if (state == .play) {
        try ecs.draw();
    } else if (state == .reset) {
        state = .menu;
        try eclose();
    }
}

pub fn close() void {
    ecs.deinit();
}

pub fn estart() !void {
    score_increase = 1;
    enemy_station_shoot = 1;
    scoreIncrease(10, 1);

    const w = alka.getWindow();
    const input = alka.getInput();

    var player = try ecs.world.createRegister(@enumToInt(ecs.SpecialEntities.player));
    try player.create();

    try player.attach("Player Controller", ecs.PlayerController{
        .left = try input.keyStatePtr(.A),
        .right = try input.keyStatePtr(.D),
        .up = try input.keyStatePtr(.W),
        .down = try input.keyStatePtr(.S),
        .dash = try input.keyStatePtr(.LeftShift),
        .dash_counter = 0,
        .dash_max = 0.5,
        .dash_timer_max = 0.5,
    });
    try player.attach("Motion", ecs.Motion{
        .acc = 10,
        .friction = 5,
        .maxspeed = Vec2f{ .x = 5, .y = 5 },
    });

    try player.attach("Transform", Transform2D{
        .position = Vec2f{
            .x = @intToFloat(f32, w.size.width) / 2,
            .y = @intToFloat(f32, w.size.height) / 2,
        },
        .origin = Vec2f{ .x = 32 / 2, .y = 32 / 2 },
        .size = Vec2f{ .x = 32, .y = 32 },
    });
    try player.attach("Colour", alka.Colour.rgba(40, 200, 100, 255));
    try player.attach("Collision Mask", @as([]const u8, "Player"));
    try player.attach("Texture Draw", @as(u64, 1));

    try createWalls();

    // create enemy kamikaze fabric, fabric
    {
        var fabric = try ecs.world.createRegister(ecs.world.findID());

        try fabric.create();

        try fabric.attach("Fabric", ecs.Fabric{
            .maxtime = 3.1,
            .reloadtime = 3.5,
            .deloadtime = 6,
            .spawn = enemyKamikazeFabricSpawn,
        });

        try fabric.attach("Transform", Transform2D{
            .position = Vec2f{
                .x = 200,
                .y = 300,
            },
            .origin = Vec2f{ .x = 64 / 2, .y = 64 / 2 },
            .size = Vec2f{ .x = 64, .y = 64 },
        });
    }
}

pub fn eclose() !void {
    var it = ecs.world.registers.iterator();
    while (it.next()) |entry| {
        if (entry.data) |entity| {
            entity.destroy();
            try ecs.world.removeRegister(entity.id);
        }
    }
    score = 0;
}

pub fn scoreIncrease(constant: f32, factor: f32) void {
    score += constant * factor * score_increase;
    if (score > highscore) highscore = score;
}

pub fn scoreDecrease(constant: f32, factor: f32) void {
    score -= constant * factor;
    if (score < 0) {
        state = .reset;
        ecs.abortfunc = true;
    }
}

fn createWalls() !void {
    const w = alka.getWindow();

    const colour = alka.Colour.rgba(0, 0, 0, 255);

    // wall left
    {
        var wall = try ecs.world.createRegister(@enumToInt(ecs.SpecialEntities.wall_left));
        try wall.create();

        try wall.attach("Transform", Transform2D{
            .position = Vec2f{
                .x = 0,
                .y = @intToFloat(f32, w.size.height) / 2,
            },
            .size = Vec2f{ .x = 32, .y = @intToFloat(f32, w.size.height) },
        });
        var tr = try wall.getPtr("Transform", Transform2D);
        tr.origin = tr.size.divValues(2, 2);
        try wall.attach("Colour", colour);
        try wall.attach("Collision Mask", @as([]const u8, "Wall"));
        try wall.attach("Rectangle Draw", @as(i1, 0));
    }

    // wall right
    {
        var wall = try ecs.world.createRegister(@enumToInt(ecs.SpecialEntities.wall_right));
        try wall.create();

        try wall.attach("Transform", Transform2D{
            .position = Vec2f{
                .x = @intToFloat(f32, w.size.width),
                .y = @intToFloat(f32, w.size.height) / 2,
            },
            .size = Vec2f{ .x = 32, .y = @intToFloat(f32, w.size.height) },
        });
        var tr = try wall.getPtr("Transform", Transform2D);
        tr.origin = tr.size.divValues(2, 2);
        try wall.attach("Colour", colour);
        try wall.attach("Collision Mask", @as([]const u8, "Wall"));
        try wall.attach("Rectangle Draw", @as(i1, 0));
    }

    // wall top
    {
        var wall = try ecs.world.createRegister(@enumToInt(ecs.SpecialEntities.wall_top));
        try wall.create();

        try wall.attach("Transform", Transform2D{
            .position = Vec2f{
                .x = @intToFloat(f32, w.size.width) / 2,
                .y = 0,
            },
            .size = Vec2f{ .x = @intToFloat(f32, w.size.width), .y = 32 },
        });
        var tr = try wall.getPtr("Transform", Transform2D);
        tr.origin = tr.size.divValues(2, 2);
        try wall.attach("Colour", colour);
        try wall.attach("Collision Mask", @as([]const u8, "Wall"));
        try wall.attach("Rectangle Draw", @as(i1, 0));
    }

    // wall bottom
    {
        var wall = try ecs.world.createRegister(@enumToInt(ecs.SpecialEntities.wall_bottom));
        try wall.create();

        try wall.attach("Transform", Transform2D{
            .position = Vec2f{
                .x = @intToFloat(f32, w.size.width) / 2,
                .y = @intToFloat(f32, w.size.height),
            },
            .size = Vec2f{ .x = @intToFloat(f32, w.size.width), .y = 32 },
        });
        var tr = try wall.getPtr("Transform", Transform2D);
        tr.origin = tr.size.divValues(2, 2);
        try wall.attach("Colour", colour);
        try wall.attach("Collision Mask", @as([]const u8, "Wall"));
        try wall.attach("Rectangle Draw", @as(i1, 0));
    }
}

fn enemyKamikazeSpawn(self_id: u64) !void {
    var entity = try ecs.world.createRegister(ecs.world.findID());

    const col = alka.Colour.rgba(220, 70, 80, 255);

    try entity.create();

    try entity.attach("Collision Mask", @as([]const u8, "Enemy Kamikaze"));
    try entity.attach("Texture Draw", @as(u64, 2));
    try entity.attach("Colour", col);

    const pl = try ecs.world.getRegister(@enumToInt(ecs.SpecialEntities.player));
    const plt = try pl.get("Transform", Transform2D);

    const self = try ecs.world.getRegister(self_id);
    const str = try self.get("Transform", Transform2D);
    const opos = str.getOriginated();

    try entity.attach("Transform", Transform2D{
        .position = Vec2f{
            .x = opos.x + 32,
            .y = opos.y + 32,
        },
        .size = Vec2f{
            .x = 32,
            .y = 32,
        },
    });
    var tr = try entity.getPtr("Transform", Transform2D);
    tr.origin = tr.size.divValues(2, 2);

    const w = alka.getWindow().size;

    const pos0 = plt.getOriginated();
    const pos1 = tr.getOriginated();

    const angle = pos1.angleRad(pos0);
    const toward = Vec2f{
        .x = @cos(angle),
        .y = @sin(angle),
    };

    tr.rotation = rad2degf(angle) + 90;

    try entity.attach("Motion", ecs.Motion{
        .maxspeed = Vec2f{ .x = 10, .y = 10 },
        .constant = toward.mulValues(20, 20),
    });
}

fn enemyKamikazeFabricSpawn(self_id: u64) !void {
    var fabric = try ecs.world.createRegister(ecs.world.findID());
    try fabric.create();

    const w = alka.getWindow().size;

    try fabric.attach("Fabric", ecs.Fabric{
        .maxtime = 0.2,
        .reloadtime = 3,
        .reloadcc = 3,
        .ctime = 1,
        .deloadtime = 1.5 * enemy_station_shoot,
        .spawn = enemyKamikazeSpawn,
    });

    try fabric.attach("Transform", Transform2D{
        .position = Vec2f{
            .x = @intToFloat(f32, rand.intRangeAtMost(i32, 100, w.width - 100)),
            .y = @intToFloat(f32, rand.intRangeAtMost(i32, 100, w.height - 100)),
        },
        .origin = Vec2f{ .x = 64 / 2, .y = 64 / 2 },
        .size = Vec2f{ .x = 64, .y = 64 },
    });

    try fabric.attach("Enemy Fabric Controller", ecs.EnemyFabricController{
        .speedup = 500,
        .torque = 200,
    });

    try fabric.attach("Colour", alka.Colour.rgba(255, 255, 255, 255));
    try fabric.attach("Texture Draw", @as(u64, 3));
    try fabric.attach("Collision Mask", @as([]const u8, "Enemy Fabric Controller"));
}
