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

const c = @import("c.zig");
const gl = @import("gl.zig");
usingnamespace @import("math/math.zig");
usingnamespace @import("log.zig");

const alkalog = std.log.scoped(.alka_core_renderer);

/// Error set
pub const Error = error{
    FailedToGenerateBuffers,
    ObjectOverflow,
    VertexOverflow,
    IndexOverflow,
    UnknownSubmitFn,
    FailedToLoadTexture,
    FailedToReadFile,
};

fn readFile(alloc: *std.mem.Allocator, path: []const u8) Error![]const u8 {
    var f = std.fs.cwd().openFile(path, .{ .read = true }) catch return Error.FailedToReadFile;
    defer f.close();

    f.seekFromEnd(0) catch return Error.FailedToReadFile;
    const size = f.getPos() catch return Error.FailedToReadFile;
    f.seekTo(0) catch return Error.FailedToReadFile;
    const mem = f.readToEndAlloc(alloc, size) catch return Error.FailedToReadFile;
    return mem;
}

fn texLoadSetup(self: *Texture) void {
    gl.texturesGen(1, @ptrCast([*]u32, &self.id));
    gl.textureBind(gl.TextureType.t2D, self.id);

    gl.textureTexParameteri(gl.TextureType.t2D, gl.TextureParamaterType.min_filter, gl.TextureParamater.filter_nearest);
    gl.textureTexParameteri(gl.TextureType.t2D, gl.TextureParamaterType.mag_filter, gl.TextureParamater.filter_nearest);

    gl.textureTexParameteri(gl.TextureType.t2D, gl.TextureParamaterType.wrap_s, gl.TextureParamater.wrap_repeat);
    gl.textureTexParameteri(gl.TextureType.t2D, gl.TextureParamaterType.wrap_t, gl.TextureParamater.wrap_repeat);
}

/// Colour generic struct
pub fn ColourGeneric(comptime typ: type) type {
    switch (typ) {
        f16, f32, f64, f128 => {
            return struct {
                r: typ = 0,
                g: typ = 0,
                b: typ = 0,
                a: typ = 0,

                pub fn rgba(r: u32, g: u32, b: u32, a: u32) @This() {
                    return .{
                        .r = @intToFloat(typ, r) / 255.0,
                        .g = @intToFloat(typ, g) / 255.0,
                        .b = @intToFloat(typ, b) / 255.0,
                        .a = @intToFloat(typ, a) / 255.0,
                    };
                }
            };
        },
        u8, u16, u32, u64, u128 => {
            return struct {
                r: typ = 0,
                g: typ = 0,
                b: typ = 0,
                a: typ = 0,

                pub fn rgba(r: u32, g: u32, b: u32, a: u32) @This() {
                    return .{
                        .r = @intCast(typ, r),
                        .g = @intCast(typ, g),
                        .b = @intCast(typ, b),
                        .a = @intCast(typ, a),
                    };
                }
            };
        },
        else => @compileError("Non-implemented type"),
    }
}

pub const Colour = ColourGeneric(f32);
pub const UColour = ColourGeneric(u8);

/// Vertex generic struct
pub fn VertexGeneric(istextcoord: bool, comptime positiontype: type) type {
    if (positiontype == Vec2f or positiontype == Vec3f) {
        if (!istextcoord) {
            return struct {
                const Self = @This();
                position: positiontype = positiontype{},
                colour: Colour = comptime Colour.rgba(255, 255, 255, 255)
            };
        }
        return struct {
            const Self = @This();
            position: positiontype = positiontype{},
            texcoord: Vec2f = Vec2f{},
            colour: Colour = comptime Colour.rgba(255, 255, 255, 255)
        };
    }
    @compileError("Unknown position type");
}

/// Batch generic structure
pub fn BatchGeneric(max_object: u32, max_index: u32, max_vertex: u32, comptime vertex_type: type) type {
    return struct {
        const Self = @This();
        pub const max_object_count: u32 = max_object;
        pub const max_index_count: u32 = max_index;
        pub const max_vertex_count: u32 = max_vertex;
        pub const Vertex: type = vertex_type;

        vertex_array: u32 = 0,
        buffers: [2]u32 = [2]u32{ 0, 0 },

        vertex_list: [max_object_count][max_vertex_count]vertex_type = undefined,
        index_list: [max_object_count][max_index_count]u32 = undefined,

        submitfn: ?fn (self: *Self, vertex: [Self.max_vertex_count]vertex_type) Error!void = null,
        submission_counter: u32 = 0,

        /// Creates the batch
        pub fn create(self: *Self, shaderprogram: u32, shadersetattribs: fn () void) Error!void {
            self.submission_counter = 0;
            gl.vertexArraysGen(1, @ptrCast([*]u32, &self.vertex_array));
            gl.buffersGen(2, &self.buffers);

            if (self.vertex_array == 0 or self.buffers[0] == 0 or self.buffers[1] == 0) {
                gl.vertexArraysDelete(1, @ptrCast([*]const u32, &self.vertex_array));
                gl.buffersDelete(2, @ptrCast([*]const u32, &self.buffers));
                return Error.FailedToGenerateBuffers;
            }

            gl.vertexArrayBind(self.vertex_array);
            defer gl.vertexArrayBind(0);

            gl.bufferBind(gl.BufferType.array, self.buffers[0]);
            gl.bufferBind(gl.BufferType.elementarray, self.buffers[1]);

            defer gl.bufferBind(gl.BufferType.array, 0);
            defer gl.bufferBind(gl.BufferType.elementarray, 0);

            gl.bufferData(gl.BufferType.array, @sizeOf(vertex_type) * max_vertex_count * max_object_count, @ptrCast(?*const c_void, &self.vertex_list), gl.DrawType.dynamic);
            gl.bufferData(gl.BufferType.elementarray, @sizeOf(u32) * max_index_count * max_object_count, @ptrCast(?*const c_void, &self.index_list), gl.DrawType.dynamic);

            gl.shaderProgramUse(shaderprogram);
            defer gl.shaderProgramUse(0);
            shadersetattribs();
        }

        /// Destroys the batch
        pub fn destroy(self: Self) void {
            gl.vertexArraysDelete(1, @ptrCast([*]const u32, &self.vertex_array));
            gl.buffersDelete(2, @ptrCast([*]const u32, &self.buffers));
        }

        /// Set the vertex data from set and given position
        pub fn submitVertex(self: *Self, firstposition: u32, lastposition: u32, data: Vertex) Error!void {
            if (firstposition >= Self.max_object_count) {
                return Error.ObjectOverflow;
            } else if (lastposition >= Self.max_vertex_count) {
                return Error.VertexOverflow;
            }
            self.vertex_list[firstposition][lastposition] = data;
        }

        /// Set the index data from set and given position
        pub fn submitIndex(self: *Self, firstposition: u32, lastposition: u32, data: u32) Error!void {
            if (firstposition >= Self.max_object_count) {
                return Error.ObjectOverflow;
            } else if (lastposition >= Self.max_index_count) {
                return Error.IndexOverflow;
            }
            self.index_list[firstposition][lastposition] = data;
        }

        /// Submit a drawable object
        pub fn submitDrawable(self: *Self, obj: [Self.max_vertex_count]vertex_type) Error!void {
            if (self.submission_counter >= Self.max_object_count) {
                return Error.ObjectOverflow;
            } else if (self.submitfn) |fun| {
                try fun(self, obj);
                return;
            }
            return Error.UnknownSubmitFn;
        }

        /// Cleans the lists
        pub fn cleanAll(self: *Self) void {
            var i: u32 = 0;
            while (i < Self.max_object_count) : (i += 1) {
                var j: u32 = 0;
                while (j < Self.max_index_count) : (j += 1) {
                    self.index_list[i][j] = 0;
                }
                j = 0;
                while (j < Self.max_vertex_count) : (j += 1) {
                    self.vertex_list[i][j] = .{};
                }
            }
        }

        /// Draw the submitted objects
        pub fn draw(self: Self, drawmode: gl.DrawMode) Error!void {
            if (self.submission_counter > Self.max_object_count) return Error.ObjectOverflow;
            gl.vertexArrayBind(self.vertex_array);
            defer gl.vertexArrayBind(0);

            gl.bufferBind(gl.BufferType.array, self.buffers[0]);
            gl.bufferBind(gl.BufferType.elementarray, self.buffers[1]);

            defer gl.bufferBind(gl.BufferType.array, 0);
            defer gl.bufferBind(gl.BufferType.elementarray, 0);

            gl.bufferSubData(gl.BufferType.array, 0, @sizeOf(Vertex) * max_vertex_count * max_object_count, @ptrCast(?*const c_void, &self.vertex_list));
            gl.bufferSubData(gl.BufferType.elementarray, 0, @sizeOf(u32) * max_index_count * max_object_count, @ptrCast(?*const c_void, &self.index_list));

            gl.drawElements(drawmode, @intCast(i32, Self.max_object_count * Self.max_index_count), u32, null);
        }
    };
}

pub const Texture = struct {
    id: u32 = 0,
    width: i32 = 0,
    height: i32 = 0,

    /// Creates a texture from png file
    pub fn createFromPNG(alloc: *std.mem.Allocator, path: []const u8) Error!Texture {
        const mem = try readFile(alloc, path);
        defer alloc.free(mem);
        return try createFromPNGMemory(mem);
    }

    /// Creates a texture from png memory
    pub fn createFromPNGMemory(mem: []const u8) Error!Texture {
        var result = Texture{};
        texLoadSetup(&result);
        defer gl.textureBind(gl.TextureType.t2D, 0);

        var nrchannels: i32 = 0;

        c.stbi_set_flip_vertically_on_load(0);
        var data: ?*u8 = c.stbi_load_from_memory(@ptrCast([*c]const u8, mem), @intCast(i32, mem.len), &result.width, &result.height, &nrchannels, 4);
        defer c.stbi_image_free(data);

        if (data == null) {
            gl.texturesDelete(1, @ptrCast([*]u32, &result.id));
            return Error.FailedToLoadTexture;
        }

        gl.textureTexImage2D(gl.TextureType.t2D, 0, gl.TextureFormat.rgba8, result.width, result.height, 0, gl.TextureFormat.rgba, u8, data);
        gl.texturesGenMipmap(gl.TextureType.t2D);

        return result;
    }

    /// Creates a texture from TTF font file with given string
    pub fn createFromTTF(alloc: *std.mem.Allocator, filepath: []const u8, string: []const u8, w: i32, h: i32, lineh: i32) Error!Texture {
        var result = Texture{ .width = w, .height = h };
        texLoadSetup(&result);
        defer gl.textureBind(gl.TextureType.t2D, 0);

        const mem = try readFile(alloc, filepath);
        defer alloc.free(mem);

        var info: c.stbtt_fontinfo = undefined;
        if (c.stbtt_InitFont(&info, @ptrCast([*c]const u8, mem), 0) == 0) {
            return Error.FailedToReadFile;
        }

        // calculate font scaling
        const scale: f32 = c.stbtt_ScaleForPixelHeight(&info, @intToFloat(f32, lineh));

        var x: i32 = 0;
        var ascent: i32 = 0;
        var descent: i32 = 0;
        var linegap: i32 = 0;

        c.stbtt_GetFontVMetrics(&info, &ascent, &descent, &linegap);

        ascent = @floatToInt(i32, @round(@intToFloat(f32, ascent) * scale));
        descent = @floatToInt(i32, @round(@intToFloat(f32, descent) * scale));

        // create a bitmap for the phrase
        var bitmap: []u8 = alloc.alloc(u8, @intCast(usize, w * h)) catch return Error.FailedToLoadTexture;
        {
            var i: usize = 0;
            while (i < w * h) : (i += 1) {
                bitmap[i] = 0;
            }
        }

        {
            var i: usize = 0;
            while (i < string.len) : (i += 1) {
                if (string[i] == 0) continue;

                // how wide is this character
                var ax: i32 = 0;
                var lsb: i32 = 0;
                c.stbtt_GetCodepointHMetrics(&info, string[i], &ax, &lsb);

                // get bounding box for character (may be offset to account for chars that
                // dip above or below the line
                var c_x1: i32 = 0;
                var c_y1: i32 = 0;
                var c_x2: i32 = 0;
                var c_y2: i32 = 0;
                c.stbtt_GetCodepointBitmapBox(&info, string[i], scale, scale, &c_x1, &c_y1, &c_x2, &c_y2);

                // compute y (different characters have different heights
                var y: i32 = ascent + c_y1;

                // render character (stride and offset is important here)
                var byteOffset = x + @floatToInt(i32, @round(@intToFloat(f32, lsb) * scale) + @intToFloat(f32, (y * w)));
                c.stbtt_MakeCodepointBitmap(&info, @ptrCast([*c]u8, bitmap[@intCast(usize, byteOffset)..]), c_x2 - c_x1, c_y2 - c_y1, w, scale, scale, string[i]);

                // advance x
                x += @floatToInt(i32, @round(@intToFloat(f32, ax) * scale));

                if (string.len >= i) continue;
                // add kerning
                var kern: i32 = 0;
                kern = c.stbtt_GetCodepointKernAdvance(&info, string[i], string[i + 1]);
                x += @floatToInt(i32, @round(@intToFloat(f32, kern) * scale));
            }
        }

        // convert image data from grayscale to grayalpha
        // two channels
        var gralpha: []u8 = alloc.alloc(u8, @intCast(usize, w * h * 2)) catch return Error.FailedToLoadTexture;
        {
            var i: usize = 0;
            var k: usize = 0;
            while (i < w * h) : (i += 1) {
                gralpha[k] = 255;
                gralpha[k + 1] = bitmap[i];
                k += 2;
            }
        }
        alloc.free(bitmap);
        bitmap = gralpha;
        defer alloc.free(bitmap);

        gl.textureTexImage2D(gl.TextureType.t2D, 0, gl.TextureFormat.rg8, result.width, result.height, 0, gl.TextureFormat.rg, u8, @ptrCast(?*c_void, bitmap));
        // source: https://github.com/raysan5/raylib/blob/cba412cc313e4f95eafb3fba9303400e65c98984/src/rlgl.h#L2447
        const swizzle = comptime [_]u32{ c.GL_RED, c.GL_RED, c.GL_RED, c.GL_GREEN };
        c.glTexParameteriv(c.GL_TEXTURE_2D, c.GL_TEXTURE_SWIZZLE_RGBA, @ptrCast([*c]const i32, &swizzle));

        gl.texturesGenMipmap(gl.TextureType.t2D);

        return result;
    }

    /// Creates a texture from given colour
    pub fn createFromColour(colour: [*]UColour, w: i32, h: i32) Texture {
        var result = Texture{ .width = w, .height = h };
        texLoadSetup(&result);
        defer gl.textureBind(gl.TextureType.t2D, 0);

        gl.textureTexImage2D(gl.TextureType.t2D, 0, gl.TextureFormat.rgba8, result.width, result.height, 0, gl.TextureFormat.rgba, u8, @ptrCast(?*c_void, colour));
        gl.texturesGenMipmap(gl.TextureType.t2D);
        return result;
    }

    /// Destroys the texture
    pub fn destroy(self: *Texture) void {
        gl.texturesDelete(1, @ptrCast([*]const u32, &self.id));
        self.id = 0;
    }
};
