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
const renderer = core.renderer;
const gl = core.gl;

const alog = std.log.scoped(.alka);

pub const Error = error{ AssetAlreadyExists, FailedToAllocate, InvalidAssetID } || core.Error;

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
