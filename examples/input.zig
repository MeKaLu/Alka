const std = @import("std");
const alka = @import("alka");
const core = @import("alka_core");

usingnamespace core.log;

pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

var keyAPtr: *const core.input.State = undefined;
var mouseleftPtr: *const core.input.State = undefined;

fn update(dt: f32) !void {
    var input = alka.getInput();

    const keyA = try input.keyState(core.input.Key.A);
    const mouseleft = try input.mouseState(core.input.Mouse.ButtonLeft);

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

    try alka.init(callbacks, 1024, 768, "Input", 0, false, &gpa.allocator);

    var input = alka.getInput();
    try input.bindKey(core.input.Key.A);
    try input.bindMouse(core.input.Mouse.ButtonLeft);

    keyAPtr = try input.keyStatePtr(core.input.Key.A);
    mouseleftPtr = try input.mouseStatePtr(core.input.Mouse.ButtonLeft);

    // to unbind
    //try input.unbindKey(core.input.Mouse.ButtonLeft);
    //try input.unbindMouse(core.input.Mouse.ButtonLeft);

    try alka.open();
    try alka.update();
    try alka.close();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
