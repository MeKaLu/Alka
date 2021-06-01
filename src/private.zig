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
const core = @import("core/core.zig");
const glfw = core.glfw;
const renderer = core.renderer;
const gl = core.gl;
const input = core.input;
const window = core.window;
const fs = core.fs;
const c = core.c;
const m = core.math;
const utils = core.utils;

usingnamespace core.log;
const alog = std.log.scoped(.alka);

pub const embed = struct {
    pub const default_shader = struct {
        pub const id = 0;
        pub const vertex_shader = @embedFile("../assets/embed/texture.vert");
        pub const fragment_shader = @embedFile("../assets/embed/texture.frag");
    };
    pub const white_texture_id = 0;
};

const perror = error{ InvalidBatch, InvalidMVP, EngineIsInitialized, EngineIsNotInitialized, FailedToFindPrivateBatch };
const asseterror = error{ AssetAlreadyExists, FailedToAllocate, InvalidAssetID };
/// Error set
pub const Error = error{ FailedToFindBatch, CustomBatchInUse, CustomShaderInUse } || perror || asseterror || core.Error;

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

pub const PrivateBatchState = enum { unknown, empty, active, deactive };
pub const PrivateBatch = struct {
    state: PrivateBatchState = PrivateBatchState.unknown,
    mode: gl.DrawMode = undefined,
    shader: u32 = undefined,
    texture: renderer.Texture = undefined,
    cam2d: m.Camera2D = undefined,

    data: Batch2DQuad = undefined,

    drawfun: fn (corebatch: Batch2DQuad, mode: gl.DrawMode, shader: *u32, texture: *renderer.Texture, cam2d: *m.Camera2D) Error!void = undefined,
};

pub const Batch = struct {
    id: i32 = -1,
    mode: gl.DrawMode = undefined,
    shader: u32 = undefined,
    texture: renderer.Texture = undefined,
    cam2d: *m.Camera2D = undefined,
    subcounter: *const u32 = 0,

    drawfun: fn (corebatch: Batch2DQuad, mode: gl.DrawMode, shader: *u32, texture: *renderer.Texture, cam2d: *m.Camera2D) Error!void = drawDefault,

    pub fn drawDefault(corebatch: Batch2DQuad, mode: gl.DrawMode, shader: *u32, texture: *renderer.Texture, cam2d: *m.Camera2D) Error!void {
        cam2d.attach();
        defer cam2d.detach();

        gl.shaderProgramUse(shader.*);
        defer gl.shaderProgramUse(0);

        gl.textureActive(.texture0);
        gl.textureBind(.t2D, texture.id);
        defer gl.textureBind(.t2D, 0);

        const mvploc = gl.shaderProgramGetUniformLocation(shader.*, "MVP");
        if (mvploc == -1) return Error.InvalidMVP;
        gl.shaderProgramSetMat4x4f(mvploc, cam2d.view);

        try corebatch.draw(mode);
    }
};

pub const AssetManager = struct {
    fn GenericType(comptime T: type) type {
        return struct {
            id: ?u64 = null,
            data: T = undefined,
        };
    }

    const Shader = comptime GenericType(u32);
    const Texture = comptime GenericType(renderer.Texture);
    const Font = comptime GenericType(renderer.Font);

    alloc: *std.mem.Allocator = undefined,
    shaders: std.ArrayList(Shader) = undefined,
    textures: std.ArrayList(Texture) = undefined,
    fonts: std.ArrayList(Font) = undefined,

    fn findShader(self: AssetManager, id: u64) Error!u64 {
        var i: u64 = 0;
        while (i < self.shaders.items.len) : (i += 1) {
            if (self.shaders.items[i].id == id) return i;
        }
        return Error.InvalidAssetID;
    }

    fn findTexture(self: AssetManager, id: u64) Error!u64 {
        var i: u64 = 0;
        while (i < self.textures.items.len) : (i += 1) {
            if (self.textures.items[i].id == id) return i;
        }
        return Error.InvalidAssetID;
    }

    fn findFont(self: AssetManager, id: u64) Error!u64 {
        var i: u64 = 0;
        while (i < self.fonts.items.len) : (i += 1) {
            if (self.fonts.items[i].id == id) return i;
        }
        return Error.InvalidAssetID;
    }

    pub fn init(self: *AssetManager) Error!void {
        self.shaders = std.ArrayList(Shader).init(self.alloc);
        self.textures = std.ArrayList(Texture).init(self.alloc);
        self.fonts = std.ArrayList(Font).init(self.alloc);
        self.shaders.resize(5) catch {
            return Error.FailedToAllocate;
        };
        self.textures.resize(32) catch {
            return Error.FailedToAllocate;
        };
        self.fonts.resize(5) catch {
            return Error.FailedToAllocate;
        };
    }

    pub fn deinit(self: *AssetManager) void {
        var i: u64 = 0;
        while (i < self.shaders.items.len) : (i += 1) {
            if (self.shaders.items[i].id) |id| {
                alog.notice("shader(id: {}) unloaded!", .{id});
                gl.shaderProgramDelete(self.shaders.items[i].data);
                self.shaders.items[i].id = null;
            }
        }
        i = 0;
        while (i < self.textures.items.len) : (i += 1) {
            if (self.textures.items[i].id) |id| {
                alog.notice("texture(id: {}) unloaded!", .{id});
                self.textures.items[i].data.destroy();
                self.textures.items[i].id = null;
            }
        }
        i = 0;
        while (i < self.fonts.items.len) : (i += 1) {
            if (self.fonts.items[i].id) |id| {
                alog.notice("font(id: {}) unloaded!", .{id});
                self.fonts.items[i].data.destroy();
                self.fonts.items[i].id = null;
            }
        }

        self.shaders.deinit();
        self.textures.deinit();
        self.fonts.deinit();
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

    pub fn isFontExists(self: AssetManager, id: u64) bool {
        var i: u64 = 0;
        while (i < self.fonts.items.len) : (i += 1) {
            if (self.fonts.items[i].id == id) return true;
        }
        return false;
    }

    pub fn loadShader(self: *AssetManager, id: u64, vertex: []const u8, fragment: []const u8) Error!void {
        if (self.isShaderExists(id)) {
            alog.err("shader(id: {}) already exists!", .{id});
            return Error.AssetAlreadyExists;
        }
        const program = try gl.shaderProgramCreate(self.alloc, vertex, fragment);
        try self.shaders.append(.{
            .id = id,
            .data = program,
        });
        alog.notice("shader(id: {}) loaded!", .{id});
    }

    pub fn loadTexture(self: *AssetManager, id: u64, path: []const u8) Error!void {
        try self.loadTexturePro(id, try renderer.Texture.createFromPNG(self.alloc, path));
    }

    pub fn loadTextureFromMemory(self: *AssetManager, id: u64, mem: []const u8) Error!void {
        try self.loadTexturePro(id, try renderer.Texture.createFromPNGMemory(mem));
    }

    pub fn loadTexturePro(self: *AssetManager, id: u64, texture: renderer.Texture) Error!void {
        if (self.isTextureExists(id)) {
            alog.err("texture(id: {}) already exists!", .{id});
            return Error.AssetAlreadyExists;
        }
        try self.textures.append(.{ .id = id, .data = texture });
        alog.notice("texture(id: {}) loaded!", .{id});
    }

    pub fn loadFont(self: *AssetManager, id: u64, path: []const u8, pixelsize: i32) Error!void {
        try self.loadFontPro(id, try renderer.Font.createFromTTF(self.alloc, path, null, pixelsize));
    }

    pub fn loadFontFromMemory(self: *AssetManager, id: u64, mem: []const u8, pixelsize: i32) Error!void {
        try self.loadFontPro(id, try renderer.Font.createFromTTFMemory(self.alloc, mem, null, pixelsize));
    }

    pub fn loadFontPro(self: *AssetManager, id: u64, font: renderer.Font) Error!void {
        if (self.isFontExists(id)) {
            alog.err("font(id: {}) already exists!", .{id});
            return Error.AssetAlreadyExists;
        }
        try self.fonts.append(.{ .id = id, .data = font });
        alog.notice("font(id: {}) loaded!", .{id});
    }

    pub fn unloadShader(self: *AssetManager, id: u64) Error!void {
        if (!self.isShaderExists(id)) {
            alog.warn("shader(id: {}) does not exists!", .{id});
            return;
        } else if (id == 0) {
            alog.warn("shader(id: {}) is provided by the engine! It is not meant to unload manually!", .{id});
            return;
        }
        const i = try self.findShader(id);
        gl.shaderProgramDelete(self.shaders.items[i].data);
        _ = self.shaders.swapRemove(i);
        alog.notice("shader(id: {}) unloaded!", .{id});
    }

    pub fn unloadTexture(self: *AssetManager, id: u64) Error!void {
        if (!self.isTextureExists(id)) {
            alog.warn("texture(id: {}) does not exists!", .{id});
            return;
        } else if (id == 0) {
            alog.warn("texture(id: {}) is provided by the engine! It is not meant to unload manually!", .{id});
            return;
        }
        const i = try self.findTexture(id);
        self.textures.items[i].texture.destroy();
        _ = self.textures.swapRemove(i);
        alog.notice("texture(id: {}) unloaded!", .{id});
    }

    pub fn unloadFont(self: *AssetManager, id: u64) Error!void {
        if (!self.isFontExists(id)) {
            alog.warn("font(id: {}) does not exists!", .{id});
            return;
        } else if (id == 0) {
            alog.warn("font(id: {}) is provided by the engine! It is not meant to unload manually!", .{id});
            return;
        }
        const i = try self.findFont(id);
        self.fonts.items[i].font.destroy();
        _ = self.fonts.swapRemove(i);
        alog.notice("font(id: {}) unloaded!", .{id});
    }

    pub fn getShader(self: AssetManager, id: u64) Error!u32 {
        const i = self.findShader(id) catch |err| {
            if (err == Error.InvalidAssetID) {
                alog.warn("shader(id: {}) does not exists!", .{id});
                return Error.InvalidAssetID;
            } else return err;
        };
        return self.shaders.items[i].data;
    }

    pub fn getTexture(self: AssetManager, id: u64) Error!renderer.Texture {
        const i = self.findTexture(id) catch |err| {
            if (err == Error.InvalidAssetID) {
                alog.warn("texture(id: {}) does not exists!", .{id});
                return Error.InvalidAssetID;
            } else return err;
        };
        return self.textures.items[i].data;
    }

    pub fn getFont(self: AssetManager, id: u64) Error!renderer.Font {
        const i = self.findFont(id) catch |err| {
            if (err == Error.InvalidAssetID) {
                alog.warn("font(id: {}) does not exists!", .{id});
                return Error.InvalidAssetID;
            } else return err;
        };
        return self.fonts.items[i].data;
    }
};

pub const Private = struct {
    pub const Temp = struct {
        shader: u32 = undefined,
        texture: renderer.Texture = undefined,
        cam2d: m.Camera2D = undefined,
    };

    pub const Layer = struct {
        defaults: Temp = undefined,

        force_shader: ?u64 = null,
        force_batch: ?usize = null,
        batch_counter: usize = 0,
        batchs: []PrivateBatch = undefined,
    };

    layers: utils.UniqueList(Layer) = undefined,

    defaults: Temp = undefined,
    force_shader: ?u64 = null,
    force_batch: ?usize = null,
    batch_counter: usize = 0,
    batchs: []PrivateBatch = undefined,

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

pub fn createPrivateBatch() Error!void {
    var i: usize = 0;
    // NOTE: try to find empty batch before allocating one
    if (p.batch_counter == 0) {
        p.batchs = try p.alloc.alloc(PrivateBatch, 1);
        p.batch_counter += 1;
    } else {
        i = blk: {
            var j: usize = 0;
            var didbreak = false;
            while (j < p.batch_counter) : (j += 1) {
                if (p.batchs[j].state == PrivateBatchState.empty) {
                    didbreak = true;
                    break;
                }
            }
            if (!didbreak) {
                // to be safe
                j = p.batch_counter;
                p.batchs = try p.alloc.realloc(p.batchs, p.batch_counter + 1);
                p.batch_counter += 1;
            }
            break :blk j;
        };
    }

    p.batchs[i].drawfun = Batch.drawDefault;
    p.batchs[i].cam2d = p.defaults.cam2d;
    p.batchs[i].shader = try p.assetmanager.getShader(embed.default_shader.id);
    p.batchs[i].texture = try p.assetmanager.getTexture(embed.white_texture_id);
    p.batchs[i].state = PrivateBatchState.empty;

    p.batchs[i].data.submission_counter = 0;
    p.batchs[i].data.submitfn = submitQuadFn;
    try p.batchs[i].data.create(p.batchs[i].shader, setShaderAttribs);
}

pub fn findPrivateBatch() Error!usize {
    var i: usize = 0;
    while (i < p.batch_counter) : (i += 1) {
        if (p.batchs[i].state == PrivateBatchState.empty) {
            return i;
        }
    }
    return Error.FailedToFindPrivateBatch;
}

pub fn destroyPrivateBatch(i: usize) void {
    p.batchs[i].data.destroy();
    p.batchs[i].data.submission_counter = 0;
    p.batchs[i] = PrivateBatch{};
}

pub fn drawPrivateBatch(i: usize) Error!void {
    var b = &p.batchs[i];

    return b.drawfun(b.data, b.mode, &b.shader, &b.texture, &b.cam2d);
}

pub fn renderPrivateBatch(i: usize) Error!void {
    if (p.batchs[i].state == PrivateBatchState.active) {
        try drawPrivateBatch(i);
    } else if (p.batchs[i].data.submission_counter > 0) alog.debug("batch(id: {}) <render> operation cannot be done, state: {}", .{ i, p.batchs[i].state });
}

pub fn cleanPrivateBatch(i: usize) Error!void {
    p.batchs[i].data.cleanAll();
    p.batchs[i].data.submission_counter = 0;
    p.batchs[i].cam2d = p.defaults.cam2d;
    p.batchs[i].state = PrivateBatchState.empty;
}

pub fn closeCallback(handle: ?*glfw.Window) void {
    p.winrun = false;
    if (p.callbacks.close) |fun| {
        fun();
    }
    p.callbacks.close = null;
}

pub fn resizeCallback(handle: ?*glfw.Window, w: i32, h: i32) void {
    //gl.viewport(0, 0, w, h);
    //gl.ortho(0, @intToFloat(f32, p.win.size.width), @intToFloat(f32, p.win.size.height), 0, -1, 1);
    p.win.size.width = w;
    p.win.size.height = h;
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
            try drawPrivateBatch(i);
            try cleanPrivateBatch(i);

            try p.batchs[i].data.submitDrawable(vx);
            //alog.notice("batch(id: {}) flushed!", .{i});
        } else return err;
    };
}

pub fn submitFontPointQuad(i: usize, font_id: u64, codepoint: i32, position: m.Vec2f, psize: f32, colour: Colour) Error!void {
    var b = &p.batchs[i];
    const font = try p.assetmanager.getFont(font_id);

    const index = @intCast(usize, font.glyphIndex(codepoint));
    const scale_factor: f32 = psize / @intToFloat(f32, font.base_size);

    // zig fmt: off
    const rect = m.Rectangle{ 
    .position = 
        .{ 
            .x = position.x + @intToFloat(f32, font.glyphs[index].offx) * scale_factor - @intToFloat(f32, font.glyph_padding) * scale_factor, 
            .y = position.y + @intToFloat(f32, font.glyphs[index].offy) * scale_factor - @intToFloat(f32, font.glyph_padding) * scale_factor 
        }, 
    .size = 
        .{ 
            .x = (font.rects[index].size.x + 2 * @intToFloat(f32, font.glyph_padding)) * scale_factor, 
            .y = (font.rects[index].size.y + 2 * @intToFloat(f32, font.glyph_padding)) * scale_factor 
        } 
    };

    const src = m.Rectangle{ 
        .position = m.Vec2f{
            .x = font.rects[index].position.x - @intToFloat(f32, font.glyph_padding),
            .y = font.rects[index].position.y - @intToFloat(f32, font.glyph_padding),
        }, 
        .size = m.Vec2f{
            .x = font.rects[index].size.x + 2 * @intToFloat(f32, font.glyph_padding),
            .y = font.rects[index].size.y + 2 * @intToFloat(f32, font.glyph_padding),
        } 
    };
    // zig fmt: on

    const pos0 = m.Vec2f{ .x = rect.position.x, .y = rect.position.y };
    const pos1 = m.Vec2f{ .x = rect.position.x + rect.size.x, .y = rect.position.y };
    const pos2 = m.Vec2f{ .x = rect.position.x + rect.size.x, .y = rect.position.y + rect.size.y };
    const pos3 = m.Vec2f{ .x = rect.position.x, .y = rect.position.y + rect.size.y };

    return submitTextureQuad(i, pos0, pos1, pos2, pos3, src, colour);
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
