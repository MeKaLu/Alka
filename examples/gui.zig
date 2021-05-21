const std = @import("std");
const alka = @import("alka");

const gui = alka.gui;
const m = alka.math;

usingnamespace alka.log;

pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

var vel: f32 = 0;
var dir: f32 = 1;

fn update(dt: f32) !void {
    const canvas = try gui.getCanvas(0);
    const pos = canvas.transform.getOriginated();
    if (pos.x > 1024 - canvas.transform.size.x) {
        dir = -1;
    } else if (pos.x < 0) {
        dir = 1;
    }
    vel += 100 * dt * dir;
    try gui.update(dt);
}

fn fupdate(dt: f32) !void {
    var canvas = try gui.getCanvasPtr(0);
    canvas.transform.position.x += vel;
    vel = 0;
    try gui.fixed(dt);
}

fn draw() !void {
    const canvas = try gui.getCanvas(0);
    try gui.draw();

    try canvas.drawLines(alka.Colour.rgba(255, 0, 0, 255));
}

fn updateButton(self: *gui.Element, dt: f32) !void {
    mlog.info("update: {}", .{self.id.?});
}

fn fixedButton(self: *gui.Element, dt: f32) !void {
    mlog.info("fixed update: {}", .{self.id.?});
}

fn drawButton(self: *gui.Element) !void {
    try alka.drawRectangleAdv(
        self.transform.getRectangleNoOrigin(),
        self.transform.origin,
        m.deg2radf(self.transform.rotation),
        self.colour,
    );
}

fn onCreateButton(self: *gui.Element) !void {
    mlog.info("onCreate: {}", .{self.id.?});
}

fn onDestroyButton(self: *gui.Element) !void {
    mlog.info("onDestroy: {}", .{self.id.?});
}

fn onEnterButton(self: *gui.Element, position: m.Vec2f, relativepos: m.Vec2f) !void {
    mlog.notice("onEnter: {d}||{d}  {d}||{d}", .{ position.x, position.y, relativepos.x, relativepos.y });
}

fn onHoverButton(self: *gui.Element, position: m.Vec2f, relativepos: m.Vec2f) !void {
    mlog.notice("onHover: {d}||{d}  {d}||{d}", .{ position.x, position.y, relativepos.x, relativepos.y });
}

fn onClickButton(self: *gui.Element, position: m.Vec2f, relativepos: m.Vec2f, button: alka.input.Mouse) !void {
    mlog.notice("onClick[{}]: {d}||{d}  {d}||{d}", .{ button, position.x, position.y, relativepos.x, relativepos.y });
}

fn onPressedButton(self: *gui.Element, position: m.Vec2f, relativepos: m.Vec2f, button: alka.input.Mouse) !void {
    mlog.notice("onPressed[{}]: {d}||{d}  {d}||{d}", .{ button, position.x, position.y, relativepos.x, relativepos.y });
}

fn onDownButton(self: *gui.Element, position: m.Vec2f, relativepos: m.Vec2f, button: alka.input.Mouse) !void {
    mlog.notice("onDown[{}]: {d}||{d}  {d}||{d}", .{ button, position.x, position.y, relativepos.x, relativepos.y });
}

fn onReleasedButton(self: *gui.Element, position: m.Vec2f, relativepos: m.Vec2f, button: alka.input.Mouse) !void {
    mlog.notice("onReleased[{}]: {d}||{d}  {d}||{d}", .{ button, position.x, position.y, relativepos.x, relativepos.y });
}

fn onExitButton(self: *gui.Element, position: m.Vec2f, relativepos: m.Vec2f) !void {
    mlog.notice("onExit: {d}||{d}  {d}||{d}", .{ position.x, position.y, relativepos.x, relativepos.y });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const callbacks = alka.Callbacks{
        .update = update,
        .fixed = fupdate,
        .draw = draw,
        .resize = null,
        .close = null,
    };

    try alka.init(&gpa.allocator, callbacks, 1024, 768, "main", 0, false);

    var inp = alka.getInput();
    try inp.bindMouse(.ButtonLeft);
    try inp.bindMouse(.ButtonRight);

    // init the GUI
    try gui.init(alka.getAllocator());

    // id, transform, colour
    var canvas = try gui.createCanvas(0, m.Transform2D{
        .position = m.Vec2f{ .x = 300, .y = 300 },
        .origin = m.Vec2f{ .x = 250, .y = 150 },
        .size = m.Vec2f{ .x = 500, .y = 300 },
        .rotation = 0,
    }, alka.Colour.rgba(255, 0, 0, 100));

    // id, transform, colour, events
    var element = try canvas.createElement(
        0,
        m.Transform2D{
            .position = m.Vec2f{ .x = 100, .y = 200 },
            .origin = m.Vec2f{ .x = 25, .y = 25 },
            .size = m.Vec2f{ .x = 50, .y = 50 },
            .rotation = 0,
        },
        alka.Colour.rgba(30, 80, 200, 255),
        gui.Events{
            .onCreate = onCreateButton,
            .onDestroy = onDestroyButton,
            //.onEnter = onEnterButton,
            //.onHover = onHoverButton,
            .onClick = onClickButton,
            //.onPressed = onPressedButton,
            //.onDown = onDownButton,
            //.onReleased = onReleasedButton,
            //.onExit = onExitButton,
            //.update = updateButton,
            //.fixed = fixedButton,
            .draw = drawButton,
        },
    );

    // id, transform, colour, events
    var element2 = try canvas.createElement(
        1,
        m.Transform2D{
            .position = m.Vec2f{ .x = 400, .y = 200 },
            .origin = m.Vec2f{ .x = 25, .y = 25 },
            .size = m.Vec2f{ .x = 50, .y = 50 },
            .rotation = 0,
        },
        alka.Colour.rgba(255, 255, 255, 255),
        gui.Events{
            .onCreate = onCreateButton,
            .onDestroy = onDestroyButton,
            //.onEnter = onEnterButton,
            //.onHover = onHoverButton,
            //.onClick = onClickButton,
            //.onPressed = onPressedButton,
            //.onDown = onDownButton,
            .onReleased = onReleasedButton,
            //.onExit = onExitButton,
            //.update = updateButton,
            //.fixed = fixedButton,
            .draw = drawButton,
        },
    );

    // id
    //try canvas.destroyElement(1);

    try alka.open();
    try alka.update();
    try alka.close();

    // deinit the GUI
    try gui.deinit();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
