// -----------------------------------------
// |           Alka 1.0.0                  |
// -----------------------------------------
//
//Copyright © 2020-2020 Mehmet Kaan Uluç <kaanuluc@protonmail.com>
//
//This software is provided 'as-is', without any express or implied
//warranty. In no event will the authors be held liable for any damages
//arising from the use of this software.
//
//Permission is granted to anyone to use this software for any purpose,
//including commercial applications, and to alter it and redistribute it
//freely, subject to the following restrictions:
//
//1. The origin of this software must not be misrepresented; you must not
//   claim that you wrote the original software. If you use this software
//   in a product, an acknowledgment in the product documentation would
//   be appreciated but is not required.
//
//2. Altered source versions must be plainly marked as such, and must not
//   be misrepresented as being the original software.
//
//3. This notice may not be removed or altered from any source
//   distribution.

const std = @import("std");
const glfw = @import("core/glfw.zig");
const renderer = @import("core/renderer.zig");
const gl = @import("core/gl.zig");
const input = @import("core/input.zig");
const window = @import("core/window.zig");
const m = @import("core/math/math.zig");

usingnamespace @import("core/log.zig");
const alog = std.log.scoped(.alka);

const perror = error{ EngineIsInitialized, EngineIsNotInitialized };
/// Error set
pub const Error = perror || glfw.GLFWError || renderer.Error || gl.Error || input.Error;

pub const max_quad = 1024 * 8;
pub const Vertex2D = comptime renderer.VertexGeneric(true, m.Vec2f);
pub const Batch2DQuad = comptime renderer.BatchGeneric(max_quad, 6, 4, Vertex2D);
pub const Colour = renderer.Colour;

// error: inferring error set of return type valid only for function definitions
// var pupdateproc: ?fn (deltatime: f32) !void = null;
//                                       ^
pub const Callbacks = struct {
    update: ?fn (deltatime: f32) anyerror!void = null,
    fixed: ?fn (fixedtime: f32) anyerror!void = null,
    draw: ?fn () anyerror!void = null,
    resize: ?fn (w: i32, h: i32) void = null,
    close: ?fn () void = null,
};

const private = struct {
    callbacks: Callbacks = Callbacks{},
    alloc: *std.mem.Allocator = undefined,

    winrun: bool = false,
    targetfps: f64 = 0.0,

    win: window.Info = window.Info{},
    input: input.Info = input.Info{},
    frametime: window.FrameTime = window.FrameTime{},
    fps: window.FpsCalculator = window.FpsCalculator{},

    mousep: m.Vec2f = m.Vec2f{},
    camera2d: m.Camera2D = m.Camera2D{},
};

var pengineready: bool = false;
var p: *private = undefined;

/// Initializes the engine
pub fn init(callbacks: Callbacks, width: i32, height: i32, title: []const u8, fpslimit: u32, resizable: bool, alloc: *std.mem.Allocator) Error!void {
    if (pengineready) return Error.EngineIsInitialized;

    p = try alloc.create(private);
    p.* = private{};

    p.alloc = alloc;

    try glfw.init();
    try glfw.windowHint(glfw.WindowHint.Resizable, if (resizable) 1 else 0);
    gl.setProfile();

    p.win.size.width = width;
    p.win.size.height = height;
    p.win.minsize = p.win.size;
    p.win.maxsize = p.win.size;
    p.win.title = title;
    p.win.callbacks.close = pcloseCallback;
    p.win.callbacks.resize = presizeCallback;
    p.win.callbacks.keyinp = pkeyboardCallback;
    p.win.callbacks.mouseinp = pmousebuttonCallback;
    p.win.callbacks.mousepos = pmousePosCallback;

    if (fpslimit != 0) p.targetfps = 1.0 / @intToFloat(f32, fpslimit);

    p.input.clearBindings();
    p.camera2d.ortho = m.Mat4x4f.ortho(0, @intToFloat(f32, p.win.size.width), @intToFloat(f32, p.win.size.height), 0, -1, 1);

    try p.win.create(false, true);
    try glfw.makeContextCurrent(p.win.handle);
    gl.init();
    gl.setBlending(true);

    if (fpslimit == 0) {
        try glfw.swapInterval(1);
    } else {
        try glfw.swapInterval(0);
    }

    setCallbacks(callbacks);
    pengineready = true;

    alog.info("fully initialized!", .{});
}

/// Deinitializes the engine
pub fn deinit() Error!void {
    if (!pengineready) return Error.EngineIsNotInitialized;

    try p.win.destroy();
    gl.deinit();

    try glfw.terminate();

    p.alloc.destroy(p);
    alog.info("fully deinitialized!", .{});
}

/// Opens the window
pub fn open() Error!void {
    if (!pengineready) return Error.EngineIsNotInitialized;
    p.winrun = true;
}

/// Closes the window
pub fn close() Error!void {
    if (!pengineready) return Error.EngineIsNotInitialized;
    p.winrun = false;
}

/// Updates the engine
pub fn update() !void {
    if (!pengineready) return Error.EngineIsNotInitialized;

    // Source: https://gafferongames.com/post/fix_your_timestep/
    var last: f64 = try glfw.getTime();
    var accumulator: f64 = 0;
    var dt: f64 = 0.01;

    while (p.winrun) {
        try p.frametime.start();
        var ftime: f64 = p.frametime.current - last;
        if (ftime > 0.25) {
            ftime = 0.25;
        }
        last = p.frametime.current;
        accumulator += ftime;

        if (p.callbacks.update) |fun| {
            try fun(@floatCast(f32, p.frametime.delta));
        }

        if (p.callbacks.fixed) |fun| {
            while (accumulator >= dt) : (accumulator -= dt) {
                try fun(@floatCast(f32, dt));
            }
        }
        p.input.handle();

        gl.clearBuffers(gl.BufferBit.colour);
        if (p.callbacks.draw) |fun| {
            try fun();
        }

        try glfw.swapBuffers(p.win.handle);
        try glfw.pollEvents();

        try p.frametime.stop();
        try p.frametime.sleep(p.targetfps);

        p.fps = p.fps.calculate(p.frametime);
    }
}

/// Returns the p.alloc
pub fn getAllocator() *std.mem.Allocator {
    return p.alloc;
}

/// Returns the fps
pub fn getFps() u32 {
    return p.fps.fps;
}

/// Returns the window
pub fn getWindow() *window.Info {
    return &p.win;
}

/// Returns the input
pub fn getInput() *input.Info {
    return &p.input;
}

/// Returns the mouse pos
pub fn getMouse() m.Vec2f {
    return p.mousep;
}

/// Returns the ptr to camera2d
pub fn getCamera2D() *m.Camera2D {
    return &p.camera2d;
}

/// Sets the callbacks
pub fn setCallbacks(calls: Callbacks) void {
    p.callbacks = calls;
}

/// Sets the background colour
pub fn setBackgroundColour(r: f32, g: f32, b: f32) void {
    gl.clearColour(r, g, b, 1);
}

fn pcloseCallback(handle: ?*glfw.Window) void {
    p.winrun = false;
    if (p.callbacks.close) |fun| {
        fun();
    }
}

fn presizeCallback(handle: ?*glfw.Window, w: i32, h: i32) void {
    gl.viewport(0, 0, w, h);
    if (p.callbacks.resize) |fun| {
        fun(w, h);
    }
}

fn pkeyboardCallback(handle: ?*glfw.Window, key: i32, sc: i32, ac: i32, mods: i32) void {
    p.input.handleKeyboard(key, ac);
}

fn pmousebuttonCallback(handle: ?*glfw.Window, key: i32, ac: i32, mods: i32) void {
    p.input.handleMouse(key, ac);
}

fn pmousePosCallback(handle: ?*glfw.Window, x: f64, y: f64) void {
    p.mousep.x = @floatCast(f32, x);
    p.mousep.y = @floatCast(f32, y);
}
