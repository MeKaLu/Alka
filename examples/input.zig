const std = @import("std");
const alka = @import("alka");

usingnamespace alka.log;

pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

var keyAPtr: *const alka.input.State = undefined;
var mouseleftPtr: *const alka.input.State = undefined;

fn update(dt: f32) !void {
    const input = alka.getInput();

    const keyA = try input.keyState(alka.input.Key.A);
    const mouseleft = try input.mouseState(alka.input.Mouse.ButtonLeft);

    mlog.notice("keyA: {}, mouse left: {}", .{ keyA, mouseleft });

    mlog.info("ptr keyA: {}, ptr mouse left: {}", .{ keyAPtr, mouseleftPtr });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const callbacks = alka.Callbacks{
        .update = update,
        .fixed = null,
        .draw = null,
        .resize = null,
        .close = null,
    };

    try alka.init(&gpa.allocator, callbacks, 1024, 768, "Input", 0, false);

    var input = alka.getInput();
    try input.bindKey(alka.input.Key.A);
    try input.bindMouse(alka.input.Mouse.ButtonLeft);

    keyAPtr = try input.keyStatePtr(alka.input.Key.A);
    mouseleftPtr = try input.mouseStatePtr(alka.input.Mouse.ButtonLeft);

    // to unbind
    //try input.unbindKey(alka.input.Mouse.ButtonLeft);
    //try input.unbindMouse(alka.input.Mouse.ButtonLeft);

    try alka.open();
    try alka.update();
    try alka.close();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
