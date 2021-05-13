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
const utf8 = @import("core/utf8.zig");
const pr = @import("private.zig");

usingnamespace @import("core/log.zig");
const alog = std.log.scoped(.alka);

const perror = error{InvalidBatch};

/// Error set
pub const Error = perror || pr.Error;

pub const max_quad = pr.max_quad;
pub const Vertex2D = pr.Vertex2D;
pub const Batch2DQuad = pr.Batch2DQuad;
pub const Colour = pr.Colour;

// error: inferring error set of return type valid only for function definitions
// var pupdateproc: ?fn (deltatime: f32) !void = null;
//                                       ^
pub const Callbacks = pr.Callbacks;
pub const AssetManager = pr.AssetManager;
pub const Batch = struct {
    id: i32 = -1,
    mode: gl.DrawMode = undefined,
    shader: u32 = undefined,
    texture: renderer.Texture = undefined,
    cam2d: *m.Camera2D = undefined,
    subcounter: *const u32 = 0,
};

var pengineready: bool = false;
var p: *pr.Private = undefined;

/// Initializes the engine
pub fn init(callbacks: Callbacks, width: i32, height: i32, title: []const u8, fpslimit: u32, resizable: bool, alloc: *std.mem.Allocator) Error!void {
    if (pengineready) return Error.EngineIsInitialized;

    p = try alloc.create(pr.Private);
    p.* = pr.Private{};
    pr.setstruct(p);

    p.alloc = alloc;

    try glfw.init();
    try glfw.windowHint(glfw.WindowHint.Resizable, if (resizable) 1 else 0);
    gl.setProfile();

    p.input.clearBindings();

    p.win.size.width = width;
    p.win.size.height = height;
    p.win.minsize = if (resizable) .{ .width = 100, .height = 100 } else p.win.size;
    p.win.maxsize = if (resizable) .{ .width = 10000, .height = 10000 } else p.win.size;
    p.win.title = title;
    p.win.callbacks.close = pr.closeCallback;
    p.win.callbacks.resize = pr.resizeCallback;
    p.win.callbacks.keyinp = pr.keyboardCallback;
    p.win.callbacks.mouseinp = pr.mousebuttonCallback;
    p.win.callbacks.mousepos = pr.mousePosCallback;
    setCallbacks(callbacks);

    if (fpslimit != 0) p.targetfps = 1.0 / @intToFloat(f32, fpslimit);

    try p.win.create(false, true);
    try glfw.makeContextCurrent(p.win.handle);
    gl.init();
    gl.setBlending(true);

    if (fpslimit == 0) {
        try glfw.swapInterval(1);
    } else {
        try glfw.swapInterval(0);
    }

    p.defaults.cam2d = m.Camera2D{};
    p.defaults.cam2d.ortho = m.Mat4x4f.ortho(0, @intToFloat(f32, p.win.size.width), @intToFloat(f32, p.win.size.height), 0, -1, 1);

    p.assetmanager.alloc = p.alloc;
    try p.assetmanager.init();

    try p.assetmanager.loadShader(pr.embed.default_shader.id, pr.embed.default_shader.vertex_shader, pr.embed.default_shader.fragment_shader);

    {
        var c = [_]renderer.UColour{
            .{ .r = 255, .g = 255, .b = 255, .a = 255 },
        };
        const wtexture = renderer.Texture.createFromColour(&c, 1, 1);
        try p.assetmanager.loadTexturePro(pr.embed.white_texture_id, wtexture);
    }

    pengineready = true;
    alog.info("fully initialized!", .{});
}

/// Deinitializes the engine
pub fn deinit() Error!void {
    if (!pengineready) return Error.EngineIsNotInitialized;
    // Destroy all the batchs
    if (p.batch_counter > 0) {
        var i: usize = 0;
        while (i < p.batch_counter) : (i += 1) {
            if (p.batchs[i].state != pr.BatchState.unknown) {
                pr.destroyBatch(i);
                alog.notice("batch(id: {}) destroyed!", .{i});
            }
        }
        p.alloc.free(p.batchs);
    }

    p.assetmanager.deinit();

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
        if (p.callbacks.update) |fun| {
            try fun(@floatCast(f32, p.frametime.delta));
        }

        try p.frametime.start();
        var ftime: f64 = p.frametime.current - last;
        if (ftime > 0.25) {
            ftime = 0.25;
        }
        last = p.frametime.current;
        accumulator += ftime;

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

        // Render all the batches
        {
            var i: usize = 0;
            while (i < p.batch_counter) : (i += 1) {
                try pr.renderBatch(i);
            }
        }

        try glfw.swapBuffers(p.win.handle);
        try glfw.pollEvents();

        // Clean all the batches
        {
            var i: usize = 0;
            while (i < p.batch_counter) : (i += 1) {
                try pr.cleanBatch(i);
            }
        }

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

/// Returns the debug information
/// Warning: you have to manually free the buffer
pub fn getDebug() ![]u8 {
    if (!pengineready) return Error.EngineIsNotInitialized;
    var buffer: []u8 = try p.alloc.alloc(u8, 255);

    buffer = try std.fmt.bufPrintZ(buffer, "update: {d}\tdraw: {d}\tdelta: {d}\tfps: {}", .{ p.frametime.update, p.frametime.draw, p.frametime.delta, p.fps.fps });
    return buffer;
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
pub fn getMousePosition() m.Vec2f {
    return p.mousep;
}

/// Returns the ptr to assetmanager
pub fn getAssetManager() *AssetManager {
    return &p.assetmanager;
}

/// Returns the ptr to default camera2d
pub fn getCamera2D() *m.Camera2D {
    return &p.defaults.cam2d;
}

/// Returns the requested batch with given attribs
/// Note: updating every frame is the way to go
pub fn getBatch(mode: gl.DrawMode, sh: u32, texture: renderer.Texture) Error!Batch {
    var i: usize = 0;
    while (i < p.batch_counter) : (i += 1) {
        if (p.batchs[i].state == pr.BatchState.active and p.batchs[i].mode == mode and p.batchs[i].shader == sh and p.batchs[i].texture.id == texture.id) return Batch{
            .id = @intCast(i32, i),
            .mode = p.batchs[i].mode,
            .shader = p.batchs[i].shader,
            .texture = p.batchs[i].texture,
            .cam2d = &p.batchs[i].cam2d,
            .subcounter = &p.batchs[i].data.submission_counter,
        };
    }
    return Error.InvalidBatch;
}

/// Returns the ptr to core batch
pub fn getBatchCore(id: usize) Error!*Batch2DQuad {
    if (p.batchs[id].state == pr.BatchState.active) {
        return &p.batchs[id].data;
    }
    return Error.InvalidBatch;
}

/// Creates a batch with given attribs
/// Note: updating every frame is the way to go
pub fn createBatch(mode: gl.DrawMode, sh: u32, texture: renderer.Texture) Error!Batch {
    var i = pr.findBatch() catch |err| {
        if (err == Error.FailedToFind) {
            try pr.createBatch();
            return createBatch(mode, sh, texture);
        } else return err;
    };

    var b = &p.batchs[i];
    b.state = pr.BatchState.active;
    b.mode = mode;
    b.shader = sh;
    b.texture = texture;
    b.cam2d = p.defaults.cam2d;

    return Batch{
        .id = @intCast(i32, i),
        .mode = mode,
        .shader = sh,
        .texture = texture,
        .cam2d = &b.cam2d,
        .subcounter = &b.data.submission_counter,
    };
}

/// Sets the callbacks
pub fn setCallbacks(calls: Callbacks) void {
    p.callbacks = calls;
}

/// Sets the background colour
pub fn setBackgroundColour(r: f32, g: f32, b: f32) void {
    gl.clearColour(r, g, b, 1);
}

/// Renders the given batch attribs
pub fn renderBatch(mode: gl.DrawMode, sh: u32, texture: renderer.Texture) Error!void {
    const batch = try getBatch(mode, sh, texture);
    const i = @intCast(usize, batch.id);
    try pr.drawBatch(i);
}

/// Draws a pixel
/// Draw mode: points
pub fn drawPixel(pos: m.Vec2f, colour: Colour) Error!void {
    const shader = try p.assetmanager.getShader(pr.embed.default_shader.id);
    const white_texture = try p.assetmanager.getTexture(pr.embed.white_texture_id);

    const batch = getBatch(gl.DrawMode.points, shader, white_texture) catch |err| {
        if (err == Error.InvalidBatch) {
            _ = try createBatch(gl.DrawMode.points, shader, white_texture);
            return try drawPixel(pos, colour);
        } else return err;
    };

    const i = @intCast(usize, batch.id);

    const vx = [Batch2DQuad.max_vertex_count]Vertex2D{
        .{ .position = pos, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        .{ .position = pos, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        .{ .position = pos, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        .{ .position = pos, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
    };

    p.batchs[i].data.submitDrawable(vx) catch |err| {
        if (err == Error.ObjectOverflow) {
            try pr.drawBatch(i);
            try pr.cleanBatch(i);
            alog.notice("batch(id: {}) flushed!", .{i});

            return p.batchs[i].data.submitDrawable(vx);
        } else return err;
    };
}

/// Draws a line
/// Draw mode: lines
pub fn drawLine(start: m.Vec2f, end: m.Vec2f, thickness: f32, colour: Colour) Error!void {
    const shader = try p.assetmanager.getShader(pr.embed.default_shader.id);
    const white_texture = try p.assetmanager.getTexture(pr.embed.white_texture_id);

    const batch = getBatch(gl.DrawMode.lines, shader, white_texture) catch |err| {
        if (err == Error.InvalidBatch) {
            _ = try createBatch(gl.DrawMode.lines, shader, white_texture);
            return try drawLine(start, end, thickness, colour);
        } else return err;
    };

    const i = @intCast(usize, batch.id);

    const pos0 = m.Vec2f{ .x = start.x, .y = start.y };
    const pos1 = m.Vec2f{ .x = end.x, .y = end.y };
    const pos2 = m.Vec2f{ .x = start.x + thickness, .y = start.y + thickness };
    const pos3 = m.Vec2f{ .x = end.x + thickness, .y = end.y + thickness };

    const vx = [Batch2DQuad.max_vertex_count]Vertex2D{
        .{ .position = pos0, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        .{ .position = pos1, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        .{ .position = pos2, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        .{ .position = pos3, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
    };

    p.batchs[i].data.submitDrawable(vx) catch |err| {
        if (err == Error.ObjectOverflow) {
            try pr.drawBatch(i);
            try pr.cleanBatch(i);
            alog.notice("batch(id: {}) flushed!", .{i});

            return p.batchs[i].data.submitDrawable(vx);
        } else return err;
    };
}

/// Draws a basic rectangle
/// Draw mode: triangles
pub fn drawRectangle(rect: m.Rectangle, colour: Colour) Error!void {
    const shader = try p.assetmanager.getShader(pr.embed.default_shader.id);
    const white_texture = try p.assetmanager.getTexture(pr.embed.white_texture_id);

    const batch = getBatch(gl.DrawMode.triangles, shader, white_texture) catch |err| {
        if (err == Error.InvalidBatch) {
            _ = try createBatch(gl.DrawMode.triangles, shader, white_texture);
            return try drawRectangle(rect, colour);
        } else return err;
    };

    const i = @intCast(usize, batch.id);

    const pos0 = m.Vec2f{ .x = rect.position.x, .y = rect.position.y };
    const pos1 = m.Vec2f{ .x = rect.position.x + rect.size.x, .y = rect.position.y };
    const pos2 = m.Vec2f{ .x = rect.position.x + rect.size.x, .y = rect.position.y + rect.size.y };
    const pos3 = m.Vec2f{ .x = rect.position.x, .y = rect.position.y + rect.size.y };

    const vx = [Batch2DQuad.max_vertex_count]Vertex2D{
        .{ .position = pos0, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        .{ .position = pos1, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        .{ .position = pos2, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        .{ .position = pos3, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
    };

    p.batchs[i].data.submitDrawable(vx) catch |err| {
        if (err == Error.ObjectOverflow) {
            try pr.drawBatch(i);
            try pr.cleanBatch(i);
            alog.notice("batch(id: {}) flushed!", .{i});

            return p.batchs[i].data.submitDrawable(vx);
        } else return err;
    };
}

/// Draws a basic rectangle lines
/// Draw mode: lineloop
pub fn drawRectangleLines(rect: m.Rectangle, colour: Colour) Error!void {
    const shader = try p.assetmanager.getShader(pr.embed.default_shader.id);
    const white_texture = try p.assetmanager.getTexture(pr.embed.white_texture_id);

    const batch = getBatch(gl.DrawMode.lineloop, shader, white_texture) catch |err| {
        if (err == Error.InvalidBatch) {
            _ = try createBatch(gl.DrawMode.lineloop, shader, white_texture);
            return try drawRectangleLines(rect, colour);
        } else return err;
    };

    const i = @intCast(usize, batch.id);

    const pos0 = m.Vec2f{ .x = rect.position.x, .y = rect.position.y };
    const pos1 = m.Vec2f{ .x = rect.position.x + rect.size.x, .y = rect.position.y };
    const pos2 = m.Vec2f{ .x = rect.position.x + rect.size.x, .y = rect.position.y + rect.size.y };
    const pos3 = m.Vec2f{ .x = rect.position.x, .y = rect.position.y + rect.size.y };

    const vx = [Batch2DQuad.max_vertex_count]Vertex2D{
        .{ .position = pos0, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        .{ .position = pos1, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        .{ .position = pos2, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        .{ .position = pos3, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
    };

    p.batchs[i].data.submitDrawable(vx) catch |err| {
        if (err == Error.ObjectOverflow) {
            try pr.drawBatch(i);
            try pr.cleanBatch(i);
            alog.notice("batch(id: {}) flushed!", .{i});

            return p.batchs[i].data.submitDrawable(vx);
        } else return err;
    };
}

/// Draws a rectangle, angle should be in radians
/// Draw mode: triangles
pub fn drawRectangleAdv(rect: m.Rectangle, origin: m.Vec2f, angle: f32, colour: Colour) Error!void {
    const shader = try p.assetmanager.getShader(pr.embed.default_shader.id);
    const white_texture = try p.assetmanager.getTexture(pr.embed.white_texture_id);

    const batch = getBatch(gl.DrawMode.triangles, shader, white_texture) catch |err| {
        if (err == Error.InvalidBatch) {
            _ = try createBatch(gl.DrawMode.triangles, shader, white_texture);
            return try drawRectangleAdv(rect, origin, angle, colour);
        } else return err;
    };

    const i = @intCast(usize, batch.id);

    var model = m.ModelMatrix{};
    model.translate(rect.position.x, rect.position.y, 0);
    model.translate(origin.x, origin.y, 0);
    model.rotate(0, 0, 1, angle);
    model.translate(-origin.x, -origin.y, 0);
    const mvp = model.model;

    const r0 = m.Vec3f.transform(.{ .x = 0, .y = 0 }, mvp);
    const r1 = m.Vec3f.transform(.{ .x = rect.size.x, .y = 0 }, mvp);
    const r2 = m.Vec3f.transform(.{ .x = rect.size.x, .y = rect.size.y }, mvp);
    const r3 = m.Vec3f.transform(.{ .x = 0, .y = rect.size.y }, mvp);

    const pos0 = m.Vec2f{ .x = rect.position.x + r0.x, .y = rect.position.y + r0.y };
    const pos1 = m.Vec2f{ .x = rect.position.x + r1.x, .y = rect.position.y + r1.y };
    const pos2 = m.Vec2f{ .x = rect.position.x + r2.x, .y = rect.position.y + r2.y };
    const pos3 = m.Vec2f{ .x = rect.position.x + r3.x, .y = rect.position.y + r3.y };

    const vx = [Batch2DQuad.max_vertex_count]Vertex2D{
        .{ .position = pos0, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        .{ .position = pos1, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        .{ .position = pos2, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        .{ .position = pos3, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
    };

    p.batchs[i].data.submitDrawable(vx) catch |err| {
        if (err == Error.ObjectOverflow) {
            try pr.drawBatch(i);
            try pr.cleanBatch(i);
            alog.notice("batch(id: {}) flushed!", .{i});

            return p.batchs[i].data.submitDrawable(vx);
        } else return err;
    };
}

/// Draws a rectangle line, angle should be in radians
/// Draw mode: lineloop
pub fn drawRectangleLinesAdv(rect: m.Rectangle, origin: m.Vec2f, angle: f32, colour: Colour) Error!void {
    const shader = try p.assetmanager.getShader(pr.embed.default_shader.id);
    const white_texture = try p.assetmanager.getTexture(pr.embed.white_texture_id);

    const batch = getBatch(gl.DrawMode.lineloop, shader, white_texture) catch |err| {
        if (err == Error.InvalidBatch) {
            _ = try createBatch(gl.DrawMode.lineloop, shader, white_texture);
            return try drawRectangleLinesAdv(rect, origin, angle, colour);
        } else return err;
    };

    const i = @intCast(usize, batch.id);

    var model = m.ModelMatrix{};
    model.translate(rect.position.x, rect.position.y, 0);
    model.translate(origin.x, origin.y, 0);
    model.rotate(0, 0, 1, angle);
    model.translate(-origin.x, -origin.y, 0);
    const mvp = model.model;

    const r0 = m.Vec3f.transform(.{ .x = 0, .y = 0 }, mvp);
    const r1 = m.Vec3f.transform(.{ .x = rect.size.x, .y = 0 }, mvp);
    const r2 = m.Vec3f.transform(.{ .x = rect.size.x, .y = rect.size.y }, mvp);
    const r3 = m.Vec3f.transform(.{ .x = 0, .y = rect.size.y }, mvp);

    const pos0 = m.Vec2f{ .x = rect.position.x + r0.x, .y = rect.position.y + r0.y };
    const pos1 = m.Vec2f{ .x = rect.position.x + r1.x, .y = rect.position.y + r1.y };
    const pos2 = m.Vec2f{ .x = rect.position.x + r2.x, .y = rect.position.y + r2.y };
    const pos3 = m.Vec2f{ .x = rect.position.x + r3.x, .y = rect.position.y + r3.y };

    const vx = [Batch2DQuad.max_vertex_count]Vertex2D{
        .{ .position = pos0, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        .{ .position = pos1, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        .{ .position = pos2, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        .{ .position = pos3, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
    };

    p.batchs[i].data.submitDrawable(vx) catch |err| {
        if (err == Error.ObjectOverflow) {
            try pr.drawBatch(i);
            try pr.cleanBatch(i);
            alog.notice("batch(id: {}) flushed!", .{i});

            return p.batchs[i].data.submitDrawable(vx);
        } else return err;
    };
}

/// Draws a texture
/// Draw mode: triangles
pub fn drawTexture(texture_id: u64, rect: m.Rectangle, srect: m.Rectangle, colour: Colour) Error!void {
    const shader = try p.assetmanager.getShader(pr.embed.default_shader.id);
    const texture = try p.assetmanager.getTexture(texture_id);

    const batch = getBatch(gl.DrawMode.triangles, shader, texture) catch |err| {
        if (err == Error.InvalidBatch) {
            _ = try createBatch(gl.DrawMode.triangles, shader, texture);
            return try drawTexture(texture_id, rect, srect, colour);
        } else return err;
    };

    const i = @intCast(usize, batch.id);

    const pos0 = m.Vec2f{ .x = rect.position.x, .y = rect.position.y };
    const pos1 = m.Vec2f{ .x = rect.position.x + rect.size.x, .y = rect.position.y };
    const pos2 = m.Vec2f{ .x = rect.position.x + rect.size.x, .y = rect.position.y + rect.size.y };
    const pos3 = m.Vec2f{ .x = rect.position.x, .y = rect.position.y + rect.size.y };

    return pr.submitTextureQuad(i, pos0, pos1, pos2, pos3, srect, colour);
}

/// Draws a texture, angle should be in radians
/// Draw mode: triangles
pub fn drawTextureAdv(texture_id: u64, rect: m.Rectangle, srect: m.Rectangle, origin: m.Vec2f, angle: f32, colour: Colour) Error!void {
    const shader = try p.assetmanager.getShader(pr.embed.default_shader.id);
    const texture = try p.assetmanager.getTexture(texture_id);

    const batch = getBatch(gl.DrawMode.triangles, shader, texture) catch |err| {
        if (err == Error.InvalidBatch) {
            _ = try createBatch(gl.DrawMode.triangles, shader, texture);
            return try drawTextureAdv(texture_id, rect, srect, origin, angle, colour);
        } else return err;
    };

    const i = @intCast(usize, batch.id);

    var model = m.ModelMatrix{};
    model.translate(rect.position.x, rect.position.y, 0);
    model.translate(origin.x, origin.y, 0);
    model.rotate(0, 0, 1, angle);
    model.translate(-origin.x, -origin.y, 0);
    const mvp = model.model;

    const r0 = m.Vec3f.transform(.{ .x = 0, .y = 0 }, mvp);
    const r1 = m.Vec3f.transform(.{ .x = rect.size.x, .y = 0 }, mvp);
    const r2 = m.Vec3f.transform(.{ .x = rect.size.x, .y = rect.size.y }, mvp);
    const r3 = m.Vec3f.transform(.{ .x = 0, .y = rect.size.y }, mvp);

    const pos0 = m.Vec2f{ .x = rect.position.x + r0.x, .y = rect.position.y + r0.y };
    const pos1 = m.Vec2f{ .x = rect.position.x + r1.x, .y = rect.position.y + r1.y };
    const pos2 = m.Vec2f{ .x = rect.position.x + r2.x, .y = rect.position.y + r2.y };
    const pos3 = m.Vec2f{ .x = rect.position.x + r3.x, .y = rect.position.y + r3.y };

    return pr.submitTextureQuad(i, pos0, pos1, pos2, pos3, srect, colour);
}

/// Draws a given codepoint from the font
/// Draw mode: triangles
pub fn drawTextPoint(font_id: u64, codepoint: i32, position: m.Vec2f, psize: f32, colour: Colour) Error!void {
    const shader = try p.assetmanager.getShader(pr.embed.default_shader.id);
    const font = try p.assetmanager.getFont(font_id);

    const batch = getBatch(gl.DrawMode.triangles, shader, font.texture) catch |err| {
        if (err == Error.InvalidBatch) {
            _ = try createBatch(gl.DrawMode.triangles, shader, font.texture);
            return try drawTextPoint(font_id, codepoint, position, psize, colour);
        } else return err;
    };

    const i = @intCast(usize, batch.id);
    return pr.submitFontPointQuad(i, font_id, codepoint, position, psize, colour);
}

/// Draws the given string from the font
/// Draw mode: triangles
pub fn drawText(font_id: u64, string: []const u8, position: m.Vec2f, psize: f32, colour: Colour) Error!void {
    const spacing: f32 = 1;
    const shader = try p.assetmanager.getShader(pr.embed.default_shader.id);
    const font = try p.assetmanager.getFont(font_id);

    const batch = getBatch(gl.DrawMode.triangles, shader, font.texture) catch |err| {
        if (err == Error.InvalidBatch) {
            _ = try createBatch(gl.DrawMode.triangles, shader, font.texture);
            return try drawText(font_id, string, position, psize, colour);
        } else return err;
    };

    var offx: f32 = 0;
    var offy: f32 = 0;
    const scale_factor: f32 = psize / @intToFloat(f32, font.base_size);

    var i: usize = 0;
    while (i < string.len) {
        var codepointbytec: i32 = 0;
        var codepoint: i32 = utf8.nextCodepoint(string[i..], &codepointbytec);
        const index: usize = @intCast(usize, font.glyphIndex(codepoint));

        if (codepoint == 0x3f) codepointbytec = 1;

        if (codepoint == '\n') {
            offy += @intToFloat(f32, (font.base_size + @divTrunc(font.base_size, 2))) * scale_factor;
            offx = 0;
        } else {
            if ((codepoint != ' ') and (codepoint != '\t')) {
                try drawTextPoint(font_id, codepoint, m.Vec2f{ .x = position.x + offx, .y = position.y + offy }, psize, colour);
            }

            if (font.glyphs[index].advance == 0) {
                offx += font.rects[index].size.x * scale_factor + spacing;
            } else offx += @intToFloat(f32, font.glyphs[index].advance) * scale_factor + spacing;
        }

        i += @intCast(usize, codepointbytec);
    }
}
