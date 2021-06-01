const std = @import("std");
const alka = @import("alka");

const game = @import("game.zig");

usingnamespace alka.math;
usingnamespace alka.log;

const mlog = std.log.scoped(.app);

const gui = alka.gui;
const ecs = @import("ecs.zig");

const ButtonTextTag = enum {
    score,
    dash_counter,
    menu,
    play,
    exit,
};

const normalButtonColour = alka.Colour.rgba(40, 100, 200, 255);
const hoverButtonColour = alka.Colour.rgba(40, 120, 240, 255);
var scoreButtonTransform: Transform2D = undefined;
var dashButtonTransform: Transform2D = undefined;

var buttonText: std.AutoHashMap(ButtonTextTag, []const u8) = undefined;

pub fn init() !void {
    try gui.init(alka.getAllocator());

    buttonText = std.AutoHashMap(ButtonTextTag, []const u8).init(alka.getAllocator());

    try buttonText.put(.score, "Score:");
    try buttonText.put(.dash_counter, "Dash:");
    try buttonText.put(.menu, "Menu");
    try buttonText.put(.play, "Play");
    try buttonText.put(.exit, "Exit");

    var w = alka.getWindow();

    var canvas = try gui.createCanvas(
        0,
        Transform2D{
            .position = Vec2f{
                .x = @intToFloat(f32, w.size.width) / 2,
                .y = @intToFloat(f32, w.size.height) / 2,
            },
            .origin = Vec2f{ .x = 1000 / 2, .y = 700 / 2 },
            .size = Vec2f{ .x = 1000, .y = 700 },
        },
        alka.Colour.rgba(200, 0, 0, 0),
    );

    const sx: f32 = 225;
    const sxinc: f32 = 90;

    _ = try canvas.createElement(
        @enumToInt(ButtonTextTag.score),
        Transform2D{
            .position = Vec2f{
                .x = canvas.transform.size.x / 2,
                .y = sx - sxinc * 1,
            },
            .origin = Vec2f{ .x = 250 / 2, .y = 50 / 2 },
            .size = Vec2f{ .x = 250, .y = 50 },
        },
        alka.Colour.rgba(60, 200, 120, 255),
        gui.Events{
            .draw = drawButtonScore,
            .update = updateButtonScore,
        },
    );

    _ = try canvas.createElement(
        @enumToInt(ButtonTextTag.dash_counter),
        Transform2D{
            .position = Vec2f{
                .x = canvas.transform.size.x / 2,
                .y = sx,
            },
            .origin = Vec2f{ .x = 200 / 2, .y = 25 / 2 },
            .size = Vec2f{ .x = 200, .y = 25 },
        },
        alka.Colour.rgba(60, 200, 120, 255),
        gui.Events{
            .draw = drawButtonDash,
            .update = updateButtonDash,
        },
    );

    _ = try canvas.createElement(
        @enumToInt(ButtonTextTag.menu),
        Transform2D{
            .position = Vec2f{
                .x = canvas.transform.size.x - 75 * 1.5,
                .y = canvas.transform.size.y - 30 * 1.5,
            },
            .origin = Vec2f{ .x = 75 / 2, .y = 30 / 2 },
            .size = Vec2f{ .x = 75, .y = 30 },
        },
        normalButtonColour,
        gui.Events{
            .draw = drawButton,

            .onEnter = onEnterButton,
            .onExit = onExitButton,
            .onHover = onHoverButton,
            .onPressed = onPressedButton,
        },
    );

    _ = try canvas.createElement(
        @enumToInt(ButtonTextTag.play),
        Transform2D{
            .position = Vec2f{
                .x = canvas.transform.size.x / 2,
                .y = sx + sxinc * 1,
            },
            .origin = Vec2f{ .x = 75 / 2, .y = 30 / 2 },
            .size = Vec2f{ .x = 75, .y = 30 },
        },
        normalButtonColour,
        gui.Events{
            .draw = drawButton,

            .onEnter = onEnterButton,
            .onExit = onExitButton,
            .onHover = onHoverButton,
            .onPressed = onPressedButton,
        },
    );

    _ = try canvas.createElement(
        @enumToInt(ButtonTextTag.exit),
        Transform2D{
            .position = Vec2f{
                .x = canvas.transform.size.x / 2,
                .y = sx + sxinc * 2,
            },
            .origin = Vec2f{ .x = 75 / 2, .y = 30 / 2 },
            .size = Vec2f{ .x = 75, .y = 30 },
        },
        normalButtonColour,
        gui.Events{
            .draw = drawButton,

            .onEnter = onEnterButton,
            .onExit = onExitButton,
            .onHover = onHoverButton,
            .onPressed = onPressedButton,
        },
    );

    scoreButtonTransform = try canvas.getTransform(@enumToInt(ButtonTextTag.score));
    dashButtonTransform = try canvas.getTransform(@enumToInt(ButtonTextTag.dash_counter));
}

pub fn deinit() !void {
    buttonText.deinit();

    try gui.deinit();
}

fn updateButtonScore(self: *gui.Element, dt: f32) !void {
    if (game.state == .play) {
        var canvas = try gui.getCanvasPtr(0);
        var tr = try canvas.getTransformPtr(@enumToInt(ButtonTextTag.score));

        tr.size = scoreButtonTransform.size.divValues(1.2, 1);
        tr.origin = scoreButtonTransform.origin.divValues(1.2, 1);

        tr.position.x = tr.origin.x + tr.size.x / 4;
        tr.position.y = tr.origin.y;
    } else if (game.state == .menu) {
        var canvas = try gui.getCanvasPtr(0);
        var tr = try canvas.getTransformPtr(@enumToInt(ButtonTextTag.score));

        tr.* = scoreButtonTransform;
    }
}

fn updateButtonDash(self: *gui.Element, dt: f32) !void {
    if (game.state == .play) {
        var canvas = try gui.getCanvasPtr(0);
        var tr = try canvas.getTransformPtr(@enumToInt(ButtonTextTag.dash_counter));

        tr.position.x = canvas.transform.size.x - tr.origin.x * 1.5;
        tr.position.y = tr.origin.y;
    } else if (game.state == .menu) {
        var canvas = try gui.getCanvasPtr(0);
        var tr = try canvas.getTransformPtr(@enumToInt(ButtonTextTag.dash_counter));

        tr.* = dashButtonTransform;
    }
}

fn drawButtonScore(self: *gui.Element) !void {
    var alloc = alka.getAllocator();
    const text = buttonText.get(@intToEnum(ButtonTextTag, @intCast(u2, self.id.?))).?;

    var buffer = blk: {
        if (game.score >= 0) {
            break :blk try std.fmt.allocPrint(alloc, "{s}{d:0.2}\nHigh{s}{d:0.2}", .{ text, game.score, text, game.highscore });
        } else {
            break :blk try std.fmt.allocPrint(alloc, "You died.\nHigh{s}{d:0.2}", .{ text, game.highscore });
        }
    };
    defer alloc.free(buffer);

    const f = try alka.getAssetManager().getFont(0);

    const size: f32 = 18;
    const opos = self.transform.getOriginated();

    const position = Vec2f{
        .x = opos.x + (self.transform.origin.x / (size / @intToFloat(f32, buffer.len))),
        .y = opos.y + (self.transform.size.y / size),
    };
    const colour = alka.Colour.rgba(0, 0, 0, 255);

    try alka.drawRectangleAdv(
        self.transform.getRectangleNoOrigin(),
        self.transform.origin,
        deg2radf(self.transform.rotation),
        self.colour,
    );

    try alka.drawText(0, buffer, position, size, colour);
}

fn drawButtonDash(self: *gui.Element) !void {
    var alloc = alka.getAllocator();
    const text = buttonText.get(@intToEnum(ButtonTextTag, @intCast(u3, self.id.?))).?;

    const dash: f32 = blk: {
        const pl = ecs.world.getRegister(@enumToInt(ecs.SpecialEntities.player)) catch {
            break :blk 0.0;
        };
        const c = try pl.get("Player Controller", ecs.PlayerController);
        break :blk abs(c.dash_counter);
    };

    var buffer = try std.fmt.allocPrint(alloc, "{s}{d:0.2}", .{ text, dash });
    defer alloc.free(buffer);

    const f = try alka.getAssetManager().getFont(0);

    const size = 18;
    const opos = self.transform.getOriginated();

    const position = Vec2f{
        .x = opos.x + (self.transform.origin.x / (size / @intToFloat(f32, buffer.len))),
        .y = opos.y + (self.transform.size.y / size),
    };
    const colour = alka.Colour.rgba(0, 0, 0, 255);

    try alka.drawRectangleAdv(
        self.transform.getRectangleNoOrigin(),
        self.transform.origin,
        deg2radf(self.transform.rotation),
        self.colour,
    );

    try alka.drawText(0, buffer, position, size, colour);
}

fn drawButton(self: *gui.Element) !void {
    if (self.id.? == @enumToInt(ButtonTextTag.menu) and game.state == .menu) {
        return;
    } else if (self.id.? != @enumToInt(ButtonTextTag.menu) and game.state == .play) return;

    const text = buttonText.get(@intToEnum(ButtonTextTag, @intCast(u3, self.id.?))).?;

    const f = try alka.getAssetManager().getFont(0);

    const size = 18;

    const opos = self.transform.getOriginated();

    const position = Vec2f{
        .x = opos.x + (self.transform.origin.x / (size / @intToFloat(f32, text.len))),
        .y = opos.y + (self.transform.size.y / size),
    };
    const colour = alka.Colour.rgba(0, 0, 0, 255);

    try alka.drawRectangleAdv(
        self.transform.getRectangleNoOrigin(),
        self.transform.origin,
        deg2radf(self.transform.rotation),
        self.colour,
    );

    try alka.drawText(0, text, position, size, colour);
}

fn onEnterButton(self: *gui.Element, position: Vec2f, relativepos: Vec2f) !void {
    self.colour = hoverButtonColour;
}

fn onExitButton(self: *gui.Element, position: Vec2f, relativepos: Vec2f) !void {
    self.colour = normalButtonColour;
}

fn onHoverButton(self: *gui.Element, position: Vec2f, relativepos: Vec2f) !void {
    self.colour = hoverButtonColour;
}

fn onPressedButton(self: *gui.Element, position: Vec2f, relativepos: Vec2f, button: alka.input.Mouse) !void {
    if (game.state == .play and self.id.? != @enumToInt(ButtonTextTag.menu)) return;

    const state = @intToEnum(ButtonTextTag, @intCast(u3, self.id.?));

    switch (state) {
        .score => {},
        .dash_counter => {},
        .menu => {
            game.state = .menu;
            try game.eclose();
        },
        .play => {
            game.state = .play;
            try game.estart();
        },
        .exit => {
            try alka.close();
        },
    }
}
