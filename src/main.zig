const std = @import("std");
const alka = @import("alka.zig");

const gui = alka.gui;
const m = alka.math;

usingnamespace alka.log;

pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

fn update(dt: f32) !void {
    try gui.update(dt);
}

fn fupdate(dt: f32) !void {
    try gui.fixed(dt);
}

fn draw() !void {
    const canvas = try gui.getCanvas(0);
    try gui.draw();

    try canvas.drawLines(alka.Colour.rgba(255, 0, 0, 255));
}

fn resize(w: i32, h: i32) void {
    alka.gl.viewport(0, 0, w, h);
}

fn close() void {}

fn drawButton(self: *gui.Element) !void {
    try alka.drawRectangleAdv(
        self.transform.getRectangle(),
        self.transform.origin,
        m.deg2radf(self.transform.rotation),
        self.colour,
    );
}

fn onEnterButton(self: *gui.Element, position: m.Vec2f) !void {
    mlog.notice("enter: {d}||{d}", .{ position.x, position.y });
}

fn onHoverButton(self: *gui.Element, position: m.Vec2f) !void {
    mlog.notice("hover: {d}||{d}", .{ position.x, position.y });
}

fn onExitButton(self: *gui.Element, position: m.Vec2f) !void {
    mlog.notice("exit: {d}||{d}", .{ position.x, position.y });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const callbacks = alka.Callbacks{
        .update = update,
        .fixed = fupdate,
        .draw = draw,
        .resize = resize,
        .close = close,
    };

    try alka.init(&gpa.allocator, callbacks, 1024, 768, "main", 0, false);

    try gui.init(alka.getAllocator());

    var canvas = try gui.createCanvas(0, m.Transform2D{
        .position = m.Vec2f{ .x = 300, .y = 300 },
        .origin = m.Vec2f{ .x = 150, .y = 150 },
        .size = m.Vec2f{ .x = 300, .y = 300 },
        .rotation = 0,
    }, alka.Colour.rgba(255, 0, 0, 100));

    var element = try canvas.createElement(0, m.Transform2D{
        .position = m.Vec2f{ .x = 200, .y = 50 },
        .origin = m.Vec2f{ .x = 32 / 2, .y = 32 / 2 },
        .size = m.Vec2f{ .x = 32, .y = 32 },
        .rotation = 0,
    }, alka.Colour.rgba(30, 80, 200, 255));
    element.events.onEnter = onEnterButton;
    element.events.onHover = onHoverButton;
    element.events.onExit = onExitButton;

    element.events.draw = drawButton;

    try alka.open();
    try alka.update();
    try alka.close();

    try gui.deinit();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
