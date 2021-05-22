//Copyright © 2020-2021 Mehmet Kaan Uluç <kaanuluc@protonmail.com>
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
const pr = @import("private.zig");

/// opengl library
pub const gl = @import("core/gl.zig");
/// file system library
pub const fs = @import("core/fs.zig");
/// utf8 library
pub const utf8 = @import("core/utf8.zig");
/// utils library
pub const utils = @import("core/utils.zig");
/// ecs library
pub const ecs = @import("core/ecs.zig");
/// math library
pub const math = @import("core/math/math.zig");
/// glfw library
pub const glfw = @import("core/glfw.zig");
/// input library
pub const input = @import("core/input.zig");
/// std.log implementation
pub const log = @import("core/log.zig");
/// primitive renderer library
pub const renderer = @import("core/renderer.zig");
/// single window management library
pub const window = @import("core/window.zig");
/// GUI library
pub const gui = @import("gui.zig");

const m = math;

const alog = std.log.scoped(.alka);

/// Error set
pub const Error = pr.Error;

pub const max_quad = pr.max_quad;
pub const Vertex2D = pr.Vertex2D;
pub const Batch2DQuad = pr.Batch2DQuad;
pub const Colour = pr.Colour;

// error: inferring error set of return type valid only for function definitions
// var pupdateproc: ?fn (deltatime: f32) !void = null;
//                                       ^
pub const Callbacks = pr.Callbacks;
pub const Batch = pr.Batch;
pub const AssetManager = pr.AssetManager;

var pengineready: bool = false;
var p: *pr.Private = undefined;

/// Initializes the engine
pub fn init(alloc: *std.mem.Allocator, callbacks: Callbacks, width: i32, height: i32, title: []const u8, fpslimit: u32, resizable: bool) Error!void {
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
            if (p.batchs[i].state != pr.PrivateBatchState.unknown) {
                pr.destroyPrivateBatch(i);
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

    pengineready = false;
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
/// can return `anyerror`
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
                try pr.renderPrivateBatch(i);
            }
        }

        try glfw.swapBuffers(p.win.handle);
        try glfw.pollEvents();

        // Clean all the batches
        {
            var i: usize = 0;
            while (i < p.batch_counter) : (i += 1) {
                try pr.cleanPrivateBatch(i);
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

    buffer = try std.fmt.bufPrintZ(buffer, "update: {d:.4}\tdraw: {d:.4}\tdelta: {d:.4}\tfps: {}", .{ p.frametime.update, p.frametime.draw, p.frametime.delta, p.fps.fps });
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
pub fn getBatch(mode: gl.DrawMode, sh_id: u64, texture_id: u64) Error!Batch {
    const sh = try p.assetmanager.getShader(sh_id);
    const texture = try p.assetmanager.getTexture(texture_id);

    var i: usize = 0;
    while (i < p.batch_counter) : (i += 1) {
        if (p.batchs[i].state == pr.PrivateBatchState.active and p.batchs[i].mode == mode and p.batchs[i].shader == sh and p.batchs[i].texture.id == texture.id) return Batch{
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

/// Returns the requested batch with given attribs
/// Note: updating every frame is the way to go
/// usefull when using non-assetmanager loaded shaders and textures
pub fn getBatchNoID(mode: gl.DrawMode, sh: u32, texture: renderer.Texture) Error!Batch {
    var i: usize = 0;
    while (i < p.batch_counter) : (i += 1) {
        if (p.batchs[i].state == pr.PrivateBatchState.active and p.batchs[i].mode == mode and p.batchs[i].shader == sh and p.batchs[i].texture.id == texture.id) return Batch{
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

/// Creates a batch with given attribs
/// Note: updating every frame is the way to go
pub fn createBatch(mode: gl.DrawMode, sh_id: u64, texture_id: u64) Error!Batch {
    const i = pr.findPrivateBatch() catch |err| {
        if (err == Error.FailedToFindPrivateBatch) {
            try pr.createPrivateBatch();
            return createBatch(mode, sh_id, texture_id);
        } else return err;
    };

    var b = &p.batchs[i];
    b.state = pr.PrivateBatchState.active;
    b.mode = mode;
    b.shader = try p.assetmanager.getShader(sh_id);
    b.texture = try p.assetmanager.getTexture(texture_id);
    b.cam2d = p.defaults.cam2d;

    return Batch{
        .id = @intCast(i32, i),
        .mode = mode,
        .shader = b.shader,
        .texture = b.texture,
        .cam2d = &b.cam2d,
        .subcounter = &b.data.submission_counter,
    };
}

/// Creates a batch with given attribs
/// Note: updating every frame is the way to go
/// usefull when using non-assetmanager loaded shaders and textures
pub fn createBatchNoID(mode: gl.DrawMode, sh: u32, texture: renderer.Texture) Error!Batch {
    const i = pr.findPrivateBatch() catch |err| {
        if (err == Error.FailedToFindPrivateBatch) {
            try pr.createPrivateBatch();
            return createBatchNoID(mode, sh, texture);
        } else return err;
    };

    var b = &p.batchs[i];
    b.state = pr.PrivateBatchState.active;
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

/// Sets the batch drawfun
/// use this after `batch.drawfun = fun`
pub fn setBatchFun(batch: Batch) void {
    var b = &p.batchs[@intCast(usize, batch.id)];
    b.drawfun = batch.drawfun;
}

/// Sets the callbacks
pub fn setCallbacks(calls: Callbacks) void {
    p.callbacks = calls;
}

/// Sets the background colour
pub fn setBackgroundColour(r: f32, g: f32, b: f32) void {
    gl.clearColour(r, g, b, 1);
}

/// Automatically resizes/strecthes the view/camera
/// Recommended to use after initializing the engine and `resize` callback
pub fn autoResize(virtualwidth: i32, virtualheight: i32, screenwidth: i32, screenheight: i32) void {
    var cam = getCamera2D();

    const aspect: f32 = @intToFloat(f32, virtualwidth) / @intToFloat(f32, virtualheight);
    var width = screenwidth;
    var height = @floatToInt(i32, @intToFloat(f32, screenheight) / aspect + 0.5);

    if (height > screenheight) {
        height = screenheight;

        width = @floatToInt(i32, @intToFloat(f32, screenheight) * aspect + 0.5);
    }

    const vx = @divTrunc(screenwidth, 2) - @divTrunc(width, 2);
    const vy = @divTrunc(screenheight, 2) - @divTrunc(height, 2);

    const scalex = @intToFloat(f32, screenwidth) / @intToFloat(f32, virtualwidth);
    const scaley = @intToFloat(f32, screenheight) / @intToFloat(f32, virtualheight);

    gl.viewport(vx, vy, width, height);
    gl.ortho(0, @intToFloat(f32, screenwidth), @intToFloat(f32, screenheight), 0, -1, 1);

    cam.ortho = m.Mat4x4f.ortho(0, @intToFloat(f32, screenwidth), @intToFloat(f32, screenheight), 0, -1, 1);
    cam.zoom.x = scalex;
    cam.zoom.y = scaley;
}

/// Renders the given batch 
pub fn renderBatch(batch: Batch) Error!void {
    const i = @intCast(usize, batch.id);
    return pr.drawPrivateBatch(i);
}

/// Cleans the batch
pub fn cleanPrivateBatch(batch: Batch) Error!void {
    const i = @intCast(usize, batch.id);
    return pr.cleanPrivateBatch(i);
}

/// Forces to use the given batch
/// in draw calls
pub fn pushBatch(batch: Batch) void {
    p.force_batch = @intCast(usize, batch.id);
}

/// Pops the force use batch 
pub fn popBatch() void {
    p.force_batch = null;
}

/// Draws a pixel
/// Draw mode: points
pub fn drawPixel(pos: m.Vec2f, colour: Colour) Error!void {
    var i: usize = 0;
    if (p.force_batch) |id| {
        i = id;
    } else {
        const batch = getBatch(gl.DrawMode.points, pr.embed.default_shader.id, pr.embed.white_texture_id) catch |err| {
            if (err == Error.InvalidBatch) {
                _ = try createBatch(gl.DrawMode.points, pr.embed.default_shader.id, pr.embed.white_texture_id);
                return drawPixel(pos, colour);
            } else return err;
        };

        i = @intCast(usize, batch.id);
    }

    const vx = [Batch2DQuad.max_vertex_count]Vertex2D{
        .{ .position = pos, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        .{ .position = pos, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        .{ .position = pos, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        .{ .position = pos, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
    };

    p.batchs[i].data.submitDrawable(vx) catch |err| {
        if (err == Error.ObjectOverflow) {
            try pr.drawPrivateBatch(i);
            try pr.cleanPrivateBatch(i);
            //alog.notice("batch(id: {}) flushed!", .{i});

            return p.batchs[i].data.submitDrawable(vx);
        } else return err;
    };
}

/// Draws a line
/// Draw mode: lines
pub fn drawLine(start: m.Vec2f, end: m.Vec2f, thickness: f32, colour: Colour) Error!void {
    var i: usize = 0;
    if (p.force_batch) |id| {
        i = id;
    } else {
        const batch = getBatch(gl.DrawMode.lines, pr.embed.default_shader.id, pr.embed.white_texture_id) catch |err| {
            if (err == Error.InvalidBatch) {
                _ = try createBatch(gl.DrawMode.lines, pr.embed.default_shader.id, pr.embed.white_texture_id);
                return drawLine(start, end, thickness, colour);
            } else return err;
        };

        i = @intCast(usize, batch.id);
    }

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
            try pr.drawPrivateBatch(i);
            try pr.cleanPrivateBatch(i);
            //alog.notice("batch(id: {}) flushed!", .{i});

            return p.batchs[i].data.submitDrawable(vx);
        } else return err;
    };
}

/// Draws a circle lines, 16 segments by default
/// Draw mode: lineloop
pub fn drawCircleLines(position: m.Vec2f, radius: f32, colour: Colour) Error!void {
    return drawCircleLinesV(position, radius, 16, colour);
}

/// Draws a circle lines
/// Draw mode: lineloop
pub fn drawCircleLinesV(position: m.Vec2f, radius: f32, segment_count: u32, colour: Colour) Error!void {
    const segments: f32 = @intToFloat(f32, segment_count);

    var i: usize = 0;
    if (p.force_batch) |id| {
        i = id;
    } else {
        const batch = getBatch(gl.DrawMode.lineloop, pr.embed.default_shader.id, pr.embed.white_texture_id) catch |err| {
            if (err == Error.InvalidBatch) {
                _ = try createBatch(gl.DrawMode.lineloop, pr.embed.default_shader.id, pr.embed.white_texture_id);
                return drawCircleLinesV(position, radius, segment_count, colour);
            } else return err;
        };

        i = @intCast(usize, batch.id);
    }

    var j: f32 = 0;
    while (j < segments) : (j += 1) {
        const theta = 2 * m.PI * j / segments;

        const x = radius * @cos(theta) + position.x;
        const y = radius * @sin(theta) + position.y;

        const pos0 = m.Vec2f{ .x = x, .y = y };
        const pos1 = m.Vec2f{ .x = x, .y = y };
        const pos2 = m.Vec2f{ .x = x, .y = y };
        const pos3 = m.Vec2f{ .x = x, .y = y };

        const vx = [Batch2DQuad.max_vertex_count]Vertex2D{
            .{ .position = pos0, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
            .{ .position = pos1, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
            .{ .position = pos2, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
            .{ .position = pos3, .texcoord = m.Vec2f{ .x = 0, .y = 0 }, .colour = colour },
        };

        p.batchs[i].data.submitDrawable(vx) catch |err| {
            if (err == Error.ObjectOverflow) {
                try pr.drawPrivateBatch(i);
                try pr.cleanPrivateBatch(i);
                //alog.notice("batch(id: {}) flushed!", .{i});

                return p.batchs[i].data.submitDrawable(vx);
            } else return err;
        };
    }
}

/// Draws a basic rectangle
/// Draw mode: triangles
pub fn drawRectangle(rect: m.Rectangle, colour: Colour) Error!void {
    var i: usize = 0;
    if (p.force_batch) |id| {
        i = id;
    } else {
        const batch = getBatch(gl.DrawMode.triangles, pr.embed.default_shader.id, pr.embed.white_texture_id) catch |err| {
            if (err == Error.InvalidBatch) {
                _ = try createBatch(gl.DrawMode.triangles, pr.embed.default_shader.id, pr.embed.white_texture_id);
                return drawRectangle(rect, colour);
            } else return err;
        };

        i = @intCast(usize, batch.id);
    }

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
            try pr.drawPrivateBatch(i);
            try pr.cleanPrivateBatch(i);
            //alog.notice("batch(id: {}) flushed!", .{i});

            return p.batchs[i].data.submitDrawable(vx);
        } else return err;
    };
}

/// Draws a basic rectangle lines
/// Draw mode: lineloop
pub fn drawRectangleLines(rect: m.Rectangle, colour: Colour) Error!void {
    var i: usize = 0;
    if (p.force_batch) |id| {
        i = id;
    } else {
        const batch = getBatch(gl.DrawMode.lineloop, pr.embed.default_shader, pr.embed.white_texture_id) catch |err| {
            if (err == Error.InvalidBatch) {
                _ = try createBatch(gl.DrawMode.lineloop, pr.embed.default_shader, pr.embed.white_texture_id);
                return drawRectangleLines(rect, colour);
            } else return err;
        };

        i = @intCast(usize, batch.id);
    }

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
            try pr.drawPrivateBatch(i);
            try pr.cleanPrivateBatch(i);
            //alog.notice("batch(id: {}) flushed!", .{i});

            return p.batchs[i].data.submitDrawable(vx);
        } else return err;
    };
}

/// Draws a rectangle, angle should be in radians
/// Draw mode: triangles
pub fn drawRectangleAdv(rect: m.Rectangle, origin: m.Vec2f, angle: f32, colour: Colour) Error!void {
    var i: usize = 0;
    if (p.force_batch) |id| {
        i = id;
    } else {
        const batch = getBatch(gl.DrawMode.triangles, pr.embed.default_shader.id, pr.embed.white_texture_id) catch |err| {
            if (err == Error.InvalidBatch) {
                _ = try createBatch(gl.DrawMode.triangles, pr.embed.default_shader.id, pr.embed.white_texture_id);
                return drawRectangleAdv(rect, origin, angle, colour);
            } else return err;
        };

        i = @intCast(usize, batch.id);
    }

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
            try pr.drawPrivateBatch(i);
            try pr.cleanPrivateBatch(i);
            //alog.notice("batch(id: {}) flushed!", .{i});

            return p.batchs[i].data.submitDrawable(vx);
        } else return err;
    };
}

/// Draws a rectangle line, angle should be in radians
/// Draw mode: lineloop
pub fn drawRectangleLinesAdv(rect: m.Rectangle, origin: m.Vec2f, angle: f32, colour: Colour) Error!void {
    var i: usize = 0;
    if (p.force_batch) |id| {
        i = id;
    } else {
        const batch = getBatch(gl.DrawMode.lineloop, pr.embed.default_shader.id, pr.embed.white_texture_id) catch |err| {
            if (err == Error.InvalidBatch) {
                _ = try createBatch(gl.DrawMode.lineloop, pr.embed.default_shader.id, pr.embed.white_texture_id);
                return drawRectangleLinesAdv(rect, origin, angle, colour);
            } else return err;
        };

        i = @intCast(usize, batch.id);
    }

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
            try pr.drawPrivateBatch(i);
            try pr.cleanPrivateBatch(i);
            //alog.notice("batch(id: {}) flushed!", .{i});

            return p.batchs[i].data.submitDrawable(vx);
        } else return err;
    };
}

/// Draws a texture
/// Draw mode: triangles
pub fn drawTexture(texture_id: u64, rect: m.Rectangle, srect: m.Rectangle, colour: Colour) Error!void {
    var i: usize = 0;
    if (p.force_batch) |id| {
        i = id;
    } else {
        const batch = getBatch(gl.DrawMode.triangles, pr.embed.default_shader.id, texture_id) catch |err| {
            if (err == Error.InvalidBatch) {
                _ = try createBatch(gl.DrawMode.triangles, pr.embed.default_shader.id, texture_id);
                return drawTexture(texture_id, rect, srect, colour);
            } else return err;
        };

        i = @intCast(usize, batch.id);
    }

    const pos0 = m.Vec2f{ .x = rect.position.x, .y = rect.position.y };
    const pos1 = m.Vec2f{ .x = rect.position.x + rect.size.x, .y = rect.position.y };
    const pos2 = m.Vec2f{ .x = rect.position.x + rect.size.x, .y = rect.position.y + rect.size.y };
    const pos3 = m.Vec2f{ .x = rect.position.x, .y = rect.position.y + rect.size.y };

    return pr.submitTextureQuad(i, pos0, pos1, pos2, pos3, srect, colour);
}

/// Draws a texture, angle should be in radians
/// Draw mode: triangles
pub fn drawTextureAdv(texture_id: u64, rect: m.Rectangle, srect: m.Rectangle, origin: m.Vec2f, angle: f32, colour: Colour) Error!void {
    var i: usize = 0;
    if (p.force_batch) |id| {
        i = id;
    } else {
        const batch = getBatch(gl.DrawMode.triangles, pr.embed.default_shader.id, texture_id) catch |err| {
            if (err == Error.InvalidBatch) {
                _ = try createBatch(gl.DrawMode.triangles, pr.embed.default_shader.id, texture_id);
                return drawTextureAdv(texture_id, rect, srect, origin, angle, colour);
            } else return err;
        };

        i = @intCast(usize, batch.id);
    }

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
    var i: usize = 0;
    if (p.force_batch) |id| {
        i = id;
    } else {
        const shader = try p.assetmanager.getShader(pr.embed.default_shader.id);
        const font = try p.assetmanager.getFont(font_id);

        const batch = getBatchNoID(gl.DrawMode.triangles, shader, font.texture) catch |err| {
            if (err == Error.InvalidBatch) {
                _ = try createBatchNoID(gl.DrawMode.triangles, shader, font.texture);
                return drawTextPoint(font_id, codepoint, position, psize, colour);
            } else return err;
        };

        i = @intCast(usize, batch.id);
    }
    return pr.submitFontPointQuad(i, font_id, codepoint, position, psize, colour);
}

/// Draws the given string from the font
/// Draw mode: triangles
pub fn drawText(font_id: u64, string: []const u8, position: m.Vec2f, psize: f32, colour: Colour) Error!void {
    const spacing: f32 = 1;
    const font = try p.assetmanager.getFont(font_id);

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
