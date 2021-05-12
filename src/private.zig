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
const c = @import("core/c.zig");
const m = @import("core/math/math.zig");

usingnamespace @import("core/log.zig");
const alog = std.log.scoped(.alka);

pub const embed = struct {
    pub const default_shader = struct {
        pub const id = 0;
        pub const vertex_shader = @embedFile("../assets/embed/texture.vert");
        pub const fragment_shader = @embedFile("../assets/embed/texture.frag");
    };
    pub const white_texture_id = 0;
};

const perror = error{ EngineIsInitialized, EngineIsNotInitialized, FailedToFind };
const asseterror = error{ AlreadyExists, FailedToResize, InvalidId };
/// Error set
pub const Error = perror || asseterror || glfw.GLFWError || renderer.Error || gl.Error || input.Error;

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

pub const BatchState = enum { unknown, empty, active, deactive };
pub const Batch = struct {
    state: BatchState = BatchState.unknown,
    mode: gl.DrawMode = undefined,
    shader: u32 = undefined,
    texture: renderer.Texture = undefined,
    cam2d: m.Camera2D = undefined,

    data: Batch2DQuad = undefined,
};

pub const AssetManager = struct {
    fn GenericType(comptime T: type) type {
        return struct {
            id: ?u64 = null,
            data: T = undefined,
        };
    }

    const Texture = comptime GenericType(renderer.Texture);
    const Shader = comptime GenericType(u32);

    alloc: *std.mem.Allocator = undefined,
    shaders: std.ArrayList(Shader) = undefined,
    textures: std.ArrayList(Texture) = undefined,

    fn findShader(self: AssetManager, id: u64) Error!u64 {
        var i: u64 = 0;
        while (i < self.shaders.items.len) : (i += 1) {
            if (self.shaders.items[i].id == id) return i;
        }
        return Error.InvalidId;
    }

    fn findTexture(self: AssetManager, id: u64) Error!u64 {
        var i: u64 = 0;
        while (i < self.textures.items.len) : (i += 1) {
            if (self.textures.items[i].id == id) return i;
        }
        return Error.InvalidId;
    }

    pub fn init(self: *AssetManager) Error!void {
        self.shaders = std.ArrayList(Shader).init(self.alloc);
        self.textures = std.ArrayList(Texture).init(self.alloc);
        self.shaders.resize(5) catch {
            return Error.FailedToResize;
        };
        self.textures.resize(32) catch {
            return Error.FailedToResize;
        };
    }

    pub fn deinit(self: *AssetManager) void {
        var i: u64 = 0;
        i = 0;
        while (i < self.shaders.items.len) : (i += 1) {
            if (self.shaders.items[i].id) |id| {
                alog.notice("shader({}) destroyed!", .{id});
                gl.shaderProgramDelete(self.shaders.items[i].data);
                self.shaders.items[i].id = null;
            }
        }
        while (i < self.textures.items.len) : (i += 1) {
            if (self.textures.items[i].id) |id| {
                alog.notice("texture({}) destroyed!", .{id});
                self.textures.items[i].data.destroy();
                self.textures.items[i].id = null;
            }
        }

        self.shaders.deinit();
        self.textures.deinit();
    }

    pub fn isShaderExists(self: AssetManager, id: u64) bool {
        var i: u64 = 0;
        while (i < self.shaders.items.len) : (i += 1) {
            if (self.shaders.items[i].id == id) return true;
        }
        return false;
    }

    pub fn isTextureExists(self: AssetManager, id: u64) bool {
        var i: u64 = 0;
        while (i < self.textures.items.len) : (i += 1) {
            if (self.textures.items[i].id == id) return true;
        }
        return false;
    }

    pub fn loadShader(self: *AssetManager, id: u64, vertex: []const u8, fragment: []const u8) Error!void {
        if (self.isShaderExists(id)) {
            alog.err("shader({}) already exists!", .{id});
            return Error.AlreadyExists;
        }
        const program = try gl.shaderProgramCreate(self.alloc, vertex, fragment);
        try self.shaders.append(.{
            .id = id,
            .data = program,
        });
        alog.notice("shader({}) loaded!", .{id});
    }

    pub fn loadTexture(self: *AssetManager, id: u64, path: []const u8) Error!void {
        try self.loadTexturePro(id, try renderer.Texture.createFromPNG(self.alloc, path));
    }

    pub fn loadTextureFromMemory(self: *AssetManager, id: u64, mem: []const u8) Error!void {
        try self.loadTexturePro(id, try renderer.Texture.createFromPNGMemory(mem));
    }

    pub fn loadTexturePro(self: *AssetManager, id: u64, texture: renderer.Texture) Error!void {
        if (self.isTextureExists(id)) {
            alog.err("texture({}) already exists!", .{id});
            return Error.AlreadyExists;
        }
        try self.textures.append(.{ .id = id, .data = texture });
        alog.notice("texture({}) loaded!", .{id});
    }

    pub fn unloadShader(self: *AssetManager, id: u64) Error!void {
        if (!self.isShaderExists(id)) {
            alog.warn("shader({}) does not exists!", .{id});
            return;
        } else if (id == 0) {
            alog.warn("shader({}) is provided by the engine! It is not meant to unload manually!", .{id});
            return;
        }
        const i = try self.findShader(id);
        gl.shaderProgramDelete(self.shaders.items[i].data);
        _ = self.shaders.swapRemove(i);
    }

    pub fn unloadTexture(self: *AssetManager, id: u64) Error!void {
        if (!self.isTextureExists(id)) {
            alog.warn("texture({}) does not exists!", .{id});
            return;
        } else if (id == 0) {
            alog.warn("texture({}) is provided by the engine! It is not meant to unload manually!", .{id});
            return;
        }
        const i = try self.findTexture(id);
        self.textures.items[i].texture.destroy();
        _ = self.textures.swapRemove(i);
    }

    pub fn getShader(self: AssetManager, id: u64) Error!u32 {
        const i = self.findShader(id) catch |err| {
            if (err == Error.InvalidId) {
                alog.warn("shader({}) does not exists!", .{id});
                return Error.InvalidId;
            } else return err;
        };
        return self.shaders.items[i].data;
    }

    pub fn getTexture(self: AssetManager, id: u64) Error!renderer.Texture {
        const i = self.findTexture(id) catch |err| {
            if (err == Error.InvalidId) {
                alog.warn("texture({}) does not exists!", .{id});
                return Error.InvalidId;
            } else return err;
        };
        return self.textures.items[i].data;
    }
};

pub const Private = struct {
    pub const Temp = struct {
        shader: u32 = undefined,
        texture: renderer.Texture = undefined,
        cam2d: m.Camera2D = undefined,
    };

    defaults: Temp = undefined,
    current: Temp = undefined,

    batch_counter: usize = 0,
    batchs: []Batch = undefined,

    callbacks: Callbacks = Callbacks{},
    alloc: *std.mem.Allocator = undefined,

    winrun: bool = false,
    targetfps: f64 = 0.0,

    win: window.Info = window.Info{},
    input: input.Info = input.Info{},
    frametime: window.FrameTime = window.FrameTime{},
    fps: window.FpsCalculator = window.FpsCalculator{},

    assetmanager: AssetManager = undefined,

    mousep: m.Vec2f = m.Vec2f{},
};

var p: *Private = undefined;

pub fn setstruct(ps: *Private) void {
    p = ps;
}

pub fn createBatch() Error!void {
    var i: usize = 0;
    // NOTE: try to find empty batch before allocating one
    if (p.batch_counter == 0) {
        p.batchs = try p.alloc.alloc(Batch, 1);
        p.batch_counter += 1;
    } else {
        i = p.batch_counter;
        p.batchs = try p.alloc.realloc(p.batchs, p.batch_counter + 1);
        p.batch_counter += 1;
    }

    p.batchs[i].cam2d = p.defaults.cam2d;
    p.batchs[i].shader = try p.assetmanager.getShader(embed.default_shader.id);
    p.batchs[i].texture = try p.assetmanager.getTexture(embed.white_texture_id);
    p.batchs[i].state = BatchState.empty;

    p.batchs[i].data.submission_counter = 0;
    p.batchs[i].data.submitfn = submitQuadFn;
    try p.batchs[i].data.create(p.batchs[i].shader, setShaderAttribs);
}

pub fn findBatch() Error!usize {
    var i: usize = 0;
    while (i < p.batch_counter) : (i += 1) {
        if (p.batchs[i].state == BatchState.empty) {
            return i;
        }
    }
    return Error.FailedToFind;
}

pub fn destroyBatch(i: usize) void {
    p.batchs[i].data.destroy();
    p.batchs[i].data.submission_counter = 0;
    p.batchs[i] = Batch{};
}

pub fn drawBatch(i: usize) Error!void {
    var b = &p.batchs[i];
    b.cam2d.attach();
    defer b.cam2d.detach();

    gl.shaderProgramUse(b.shader);
    defer gl.shaderProgramUse(0);

    c.glActiveTexture(c.GL_TEXTURE0);
    gl.textureBind(gl.TextureType.t2D, b.texture.id);
    defer gl.textureBind(gl.TextureType.t2D, 0);

    const mvploc = gl.shaderProgramGetUniformLocation(b.shader, "MVP");
    gl.shaderProgramSetMat4x4f(mvploc, @ptrCast([*]const f32, &b.cam2d.view.toArray()));

    try b.data.draw(b.mode);
}

pub fn renderBatch(i: usize) Error!void {
    if (p.batchs[i].state == BatchState.active) {
        try drawBatch(i);
    } else alog.warn("batch(id: {}) <render> operation cannot be done, state: {}", .{ i, p.batchs[i].state });
}

pub fn cleanBatch(i: usize) Error!void {
    p.batchs[i].data.cleanAll();
    p.batchs[i].data.submission_counter = 0;
    p.batchs[i].cam2d = p.defaults.cam2d;
    p.batchs[i].state = BatchState.empty;
}

pub fn closeCallback(handle: ?*glfw.Window) void {
    p.winrun = false;
    if (p.callbacks.close) |fun| {
        fun();
    }
}

pub fn resizeCallback(handle: ?*glfw.Window, w: i32, h: i32) void {
    gl.viewport(0, 0, w, h);
    //gl.ortho(0, @intToFloat(f32, p.win.size.width), @intToFloat(f32, p.win.size.height), 0, -1, 1);
    if (p.callbacks.resize) |fun| {
        fun(w, h);
    }
}

pub fn keyboardCallback(handle: ?*glfw.Window, key: i32, sc: i32, ac: i32, mods: i32) void {
    p.input.handleKeyboard(key, ac);
}

pub fn mousebuttonCallback(handle: ?*glfw.Window, key: i32, ac: i32, mods: i32) void {
    p.input.handleMouse(key, ac);
}

pub fn mousePosCallback(handle: ?*glfw.Window, x: f64, y: f64) void {
    p.mousep.x = @floatCast(f32, x);
    p.mousep.y = @floatCast(f32, y);
}

pub fn submitTextureQuad(i: usize, p0: m.Vec2f, p1: m.Vec2f, p2: m.Vec2f, p3: m.Vec2f, srect: m.Rectangle, colour: Colour) Error!void {
    var b = &p.batchs[i];
    const w = @intToFloat(f32, b.texture.width);
    const h = @intToFloat(f32, b.texture.height);

    var psrect = srect;
    var flipx = false;
    if (psrect.size.x < 0) {
        flipx = true;
        psrect.size.x *= -1;
    }

    if (psrect.size.y < 0) {
        psrect.position.y -= psrect.size.y;
    }

    // top left
    const t0 = m.Vec2f{ .x = if (flipx) (psrect.position.x + psrect.size.x) / w else psrect.position.x / w, .y = psrect.position.y / h };

    // top right
    const t1 = m.Vec2f{ .x = if (flipx) psrect.position.x / w else (psrect.position.x + psrect.size.x) / w, .y = psrect.position.y / h };

    // bottom right
    const t2 = m.Vec2f{ .x = if (flipx) psrect.position.x / w else (psrect.position.x + psrect.size.x) / w, .y = (psrect.position.y + psrect.size.y) / h };

    // bottom left
    const t3 = m.Vec2f{ .x = if (flipx) (psrect.position.x + psrect.size.x) / w else psrect.position.x / w, .y = (psrect.position.y + psrect.size.y) / h };

    const vx = [Batch2DQuad.max_vertex_count]Vertex2D{
        .{ .position = p0, .texcoord = t0, .colour = colour },
        .{ .position = p1, .texcoord = t1, .colour = colour },
        .{ .position = p2, .texcoord = t2, .colour = colour },
        .{ .position = p3, .texcoord = t3, .colour = colour },
    };

    p.batchs[i].data.submitDrawable(vx) catch |err| {
        if (err == Error.ObjectOverflow) {
            try drawBatch(i);
            try cleanBatch(i);

            try p.batchs[i].data.submitDrawable(vx);
            alog.notice("batch(id: {}) flushed!", .{i});
        } else return err;
    };
}

fn setShaderAttribs() void {
    const stride = @sizeOf(Vertex2D);
    gl.shaderProgramSetVertexAttribArray(0, true);
    gl.shaderProgramSetVertexAttribArray(1, true);
    gl.shaderProgramSetVertexAttribArray(2, true);

    gl.shaderProgramSetVertexAttribPointer(0, 2, f32, false, stride, @intToPtr(?*const c_void, @byteOffsetOf(Vertex2D, "position")));
    gl.shaderProgramSetVertexAttribPointer(1, 2, f32, false, stride, @intToPtr(?*const c_void, @byteOffsetOf(Vertex2D, "texcoord")));
    gl.shaderProgramSetVertexAttribPointer(2, 4, f32, false, stride, @intToPtr(?*const c_void, @byteOffsetOf(Vertex2D, "colour")));
}

fn submitQuadFn(self: *Batch2DQuad, vertex: [Batch2DQuad.max_vertex_count]Vertex2D) renderer.Error!void {
    try submitVerticesQuad(Batch2DQuad, self, vertex);
    try submitIndiciesQuad(Batch2DQuad, self);

    self.submission_counter += 1;
}

fn submitVerticesQuad(comptime typ: type, self: *typ, vertex: [typ.max_vertex_count]typ.Vertex) renderer.Error!void {
    try self.submitVertex(self.submission_counter, 0, vertex[0]);
    try self.submitVertex(self.submission_counter, 1, vertex[1]);
    try self.submitVertex(self.submission_counter, 2, vertex[2]);
    try self.submitVertex(self.submission_counter, 3, vertex[3]);
}

fn submitIndiciesQuad(comptime typ: type, self: *typ) renderer.Error!void {
    if (self.submission_counter == 0) {
        try self.submitIndex(self.submission_counter, 0, 0);
        try self.submitIndex(self.submission_counter, 1, 1);
        try self.submitIndex(self.submission_counter, 2, 2);
        try self.submitIndex(self.submission_counter, 3, 2);
        try self.submitIndex(self.submission_counter, 4, 3);
        try self.submitIndex(self.submission_counter, 5, 0);
    } else {
        const back = self.index_list[self.submission_counter - 1];
        var i: u8 = 0;
        while (i < typ.max_index_count) : (i += 1) {
            try self.submitIndex(self.submission_counter, i, back[i] + 4);
            try self.submitIndex(self.submission_counter, i, back[i] + 4);
            try self.submitIndex(self.submission_counter, i, back[i] + 4);
            try self.submitIndex(self.submission_counter, i, back[i] + 4);
            try self.submitIndex(self.submission_counter, i, back[i] + 4);
            try self.submitIndex(self.submission_counter, i, back[i] + 4);
        }
    }
}
