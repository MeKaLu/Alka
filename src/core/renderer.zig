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

const c = @import("c.zig");
const gl = @import("gl.zig");
const fs = @import("fs.zig");
const m = @import("math/math.zig");
const utf8 = @import("utf8.zig");
usingnamespace @import("log.zig");

const alog = std.log.scoped(.alka_core_renderer);

/// Error set
pub const Error = error{
    ObjectOverflow,
    VertexOverflow,
    IndexOverflow,
    UnknownSubmitFn,
    FailedToGenerateBuffers,
    FailedToLoadTexture,
    FailedToLoadFont,
    FailedToGenerateAtlas,
} || fs.Error;

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
    if (positiontype == m.Vec2f or positiontype == m.Vec3f) {
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
            texcoord: m.Vec2f = m.Vec2f{},
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

pub const TextureRaw = struct {
    width: i32 = 0,
    height: i32 = 0,
    pixels: ?[]u8 = null,
    rpixels: ?[*c]u8 = null,
};

pub const Texture = struct {
    id: u32 = 0,
    width: i32 = 0,
    height: i32 = 0,

    fn loadSetup(self: *Texture) void {
        gl.texturesGen(1, @ptrCast([*]u32, &self.id));
        gl.textureBind(gl.TextureType.t2D, self.id);

        gl.textureTexParameteri(gl.TextureType.t2D, gl.TextureParamaterType.min_filter, gl.TextureParamater.filter_nearest);
        gl.textureTexParameteri(gl.TextureType.t2D, gl.TextureParamaterType.mag_filter, gl.TextureParamater.filter_linear);

        gl.textureTexParameteri(gl.TextureType.t2D, gl.TextureParamaterType.wrap_s, gl.TextureParamater.wrap_repeat);
        gl.textureTexParameteri(gl.TextureType.t2D, gl.TextureParamaterType.wrap_t, gl.TextureParamater.wrap_repeat);
    }

    /// Creates a texture from png file
    pub fn createFromPNG(alloc: *std.mem.Allocator, path: []const u8) Error!Texture {
        const mem = try fs.readFile(alloc, path);
        defer alloc.free(mem);
        return try createFromPNGMemory(mem);
    }

    /// Creates a texture from png memory
    pub fn createFromPNGMemory(mem: []const u8) Error!Texture {
        var result = Texture{};
        loadSetup(&result);
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

    /// Creates a basic texture from TTF font file with given string
    pub fn createFromTTF(alloc: *std.mem.Allocator, filepath: []const u8, string: []const u8, w: i32, h: i32, lineh: i32) Error!Texture {
        var result = Texture{ .width = w, .height = h };
        loadSetup(&result);
        defer gl.textureBind(gl.TextureType.t2D, 0);

        const mem = try fs.readFile(alloc, filepath);
        defer alloc.free(mem);

        var info: c.stbtt_fontinfo = undefined;
        if (c.stbtt_InitFont(&info, @ptrCast([*c]const u8, mem), 0) == 0) {
            return Error.FailedToLoadFont;
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
        loadSetup(&result);
        defer gl.textureBind(gl.TextureType.t2D, 0);

        gl.textureTexImage2D(gl.TextureType.t2D, 0, gl.TextureFormat.rgba8, result.width, result.height, 0, gl.TextureFormat.rgba, u8, @ptrCast(?*c_void, colour));
        gl.texturesGenMipmap(gl.TextureType.t2D);
        return result;
    }

    /// Changes the filter of the texture
    pub fn setFilter(self: Texture, comptime min: gl.TextureParamater, comptime mag: gl.TextureParamater) void {
        gl.textureBind(gl.TextureType.t2D, self.id);
        defer gl.textureBind(gl.TextureType.t2D, 0);

        gl.textureTexParameteri(gl.TextureType.t2D, gl.TextureParamaterType.min_filter, min);
        gl.textureTexParameteri(gl.TextureType.t2D, gl.TextureParamaterType.mag_filter, mag);
    }

    /// Destroys the texture
    pub fn destroy(self: *Texture) void {
        gl.texturesDelete(1, @ptrCast([*]const u32, &self.id));
        self.id = 0;
    }
};

pub const Font = struct {
    pub const bitmap_alpha_threshold = 80;
    pub const char_padding = 4;
    pub const char_fallback = 63;

    pub const Glyph = struct {
        codepoint: i32 = undefined,
        offx: i32 = undefined,
        offy: i32 = undefined,
        advance: i32 = undefined,

        raw: TextureRaw = undefined,
    };

    alloc: *std.mem.Allocator = undefined,

    texture: Texture = undefined,
    rects: []m.Rectangle = undefined,
    glyphs: []Glyph = undefined,

    base_size: i32 = undefined,
    glyph_padding: i32 = undefined,

    // source: https://github.com/raysan5/raylib/blob/cba412cc313e4f95eafb3fba9303400e65 c98984/src/text.c#L553
    fn loadFontData(alloc: *std.mem.Allocator, mem: []const u8, fontsize: i32, fontchars: ?[]const i32) Error![]Glyph {
        var info: c.stbtt_fontinfo = undefined;
        if (c.stbtt_InitFont(&info, @ptrCast([*c]const u8, mem), 0) == 0) {
            return Error.FailedToLoadFont;
        }

        var genfontchars = false;
        var chars: []Glyph = undefined;

        // calculate font scale factor
        const scale_factor: f32 = c.stbtt_ScaleForPixelHeight(&info, @intToFloat(f32, fontsize));

        // calculate font basic metrics
        // NOTE: ascent is equivalent to font baseline
        var ascent: i32 = 0;
        var descent: i32 = 0;
        var linegap: i32 = 0;
        c.stbtt_GetFontVMetrics(&info, &ascent, &descent, &linegap);

        // in case np chars provided, default to 95
        var charcount = if (fontchars) |ch| ch.len else 95;

        // fill fontChars in case not provided externally
        // NOTE: by default we fill charsCount consecutevely, starting at 32 (space)
        var pfontchars: []i32 = undefined;
        defer alloc.free(pfontchars);
        pfontchars = alloc.alloc(i32, charcount) catch return Error.FailedToLoadFont;
        {
            var i: usize = 0;
            if (fontchars == null) {
                while (i < charcount) : (i += 1) {
                    pfontchars[i] = @intCast(i32, i) + 32;
                }
                genfontchars = true;
            } else |ch| {
                while (i < charcount) : (i += 1) {
                    pfontchars[i] = ch[i];
                }
            }
        }

        chars = alloc.alloc(Glyph, charcount) catch return Error.FailedToLoadFont;

        // NOTE: using simple packaging one char after another
        var i: usize = 0;
        while (i < charcount) : (i += 1) {
            // char width & height -on gen-
            var chw: i32 = 0;
            var chh: i32 = 0;
            // char value to get info for
            var ch: i32 = pfontchars[i];
            chars[i].codepoint = ch;

            chars[i].raw.rpixels = c.stbtt_GetCodepointBitmap(&info, scale_factor, scale_factor, @intCast(i32, ch), &chw, &chh, &chars[i].offx, &chars[i].offy);

            c.stbtt_GetCodepointHMetrics(&info, @intCast(i32, ch), &chars[i].advance, null);
            chars[i].advance = @floatToInt(i32, @intToFloat(f32, chars[i].advance) * scale_factor);

            // load char images
            chars[i].raw.width = chw;
            chars[i].raw.height = chh;

            chars[i].offy += @floatToInt(i32, @intToFloat(f32, ascent) * scale_factor);

            // NOTE: we create an empty image for space char, it could be further
            // required for atlas packing
            if (ch == 32) {
                chars[i].raw.pixels = alloc.alloc(u8, @intCast(usize, chars[i].advance * fontsize * 2)) catch return Error.FailedToLoadFont; // *2?
                var j: usize = 0;
                while (j < chars[i].advance * fontsize * 2) : (j += 1) {
                    chars[i].raw.pixels.?[j] = 0;
                }

                chars[i].raw.width = chars[i].advance;
                chars[i].raw.height = fontsize;
            }

            // Aliased bitmap (black & white) font generation, avoiding anti-aliasing
            // NOTE: For optimum results, bitmap font should be generated at base pixelsize
            var j: usize = 0;
            while (j < chw * chh) : (j += 1) {
                if (chars[i].raw.pixels) |px| {
                    if (px[j] < bitmap_alpha_threshold) {
                        px[j] = 0;
                    } else {
                        px[j] = 255;
                    }
                } else if (chars[i].raw.rpixels) |px| {
                    if (px[j] < bitmap_alpha_threshold) {
                        px[j] = 0;
                    } else {
                        px[j] = 255;
                    }
                }
            }
        }

        return chars;
    }

    fn genImageAtlas(self: *Font) Error!TextureRaw {
        var atlas: []u8 = undefined;
        var atlasw: i32 = 0;
        var atlash: i32 = 0;

        var alloc = self.alloc;

        const chars = self.glyphs;
        const fontsize = self.base_size;
        const padding = self.glyph_padding;

        self.rects = alloc.alloc(m.Rectangle, chars.len) catch return Error.FailedToGenerateAtlas;

        // Calculate image size based on required pixel area
        // NOTE 1: Image is forced to be squared and POT... very conservative!
        // NOTE 2: SDF font characters already contain an internal padding,
        // so image size would result bigger than default font type
        var required_area: f32 = 0;
        {
            var i: usize = 0;
            while (i < chars.len) : (i += 1) {
                required_area += @intToFloat(f32, ((chars[i].raw.width + 2 * padding) * (chars[i].raw.height + 2 * padding)));
            }
            var guess_size = @sqrt(required_area) * 1.3;
            var v2: f32 = 2; // compiler bug
            var image_size = @floatToInt(i32, std.math.pow(f32, 2, @ceil(@log(guess_size) / @log(v2)))); // calculate next POT

            atlasw = image_size;
            atlash = image_size;
            atlas = alloc.alloc(u8, @intCast(usize, atlasw * atlash)) catch return Error.FailedToGenerateAtlas;
            i = 0;
            while (i < atlasw * atlash) : (i += 1) {
                atlas[i] = 0;
            }
        }
        var context: *c.stbrp_context = alloc.create(c.stbrp_context) catch return Error.FailedToGenerateAtlas;
        defer alloc.destroy(context);

        var nodes: []c.stbrp_node = alloc.alloc(c.stbrp_node, chars.len) catch return Error.FailedToGenerateAtlas;
        defer alloc.free(nodes);

        c.stbrp_init_target(context, atlasw, atlash, @ptrCast([*c]c.stbrp_node, nodes), @intCast(i32, chars.len));

        var rects: []c.stbrp_rect = alloc.alloc(c.stbrp_rect, chars.len) catch return Error.FailedToGenerateAtlas;
        defer alloc.free(rects);

        // fill rectangles for packing
        var i: usize = 0;
        while (i < chars.len) : (i += 1) {
            rects[i].id = @intCast(i32, i);
            rects[i].w = @intCast(u16, chars[i].raw.width + 2 * padding);
            rects[i].h = @intCast(u16, chars[i].raw.height + 2 * padding);
        }

        // pack rects into atlas
        _ = c.stbrp_pack_rects(context, @ptrCast([*c]c.stbrp_rect, rects), @intCast(i32, chars.len));

        i = 0;
        while (i < chars.len) : (i += 1) {
            self.rects[i].position.x = @intToFloat(f32, rects[i].x + @intCast(u16, padding));
            self.rects[i].position.y = @intToFloat(f32, rects[i].y + @intCast(u16, padding));
            self.rects[i].size.x = @intToFloat(f32, chars[i].raw.width);
            self.rects[i].size.y = @intToFloat(f32, chars[i].raw.height);

            if (rects[i].was_packed == 1) {
                // copy pixel data from fc.data to atlas
                var y: usize = 0;
                while (y < chars[i].raw.height) : (y += 1) {
                    var x: usize = 0;
                    while (x < chars[i].raw.width) : (x += 1) {
                        if (chars[i].raw.pixels) |px| {
                            const index = @intCast(usize, (rects[i].y + padding + @intCast(i32, y)) * atlasw + (rects[i].x + padding + @intCast(i32, x)));
                            atlas[index] = px[y * @intCast(usize, chars[i].raw.width) + x];
                        } else if (chars[i].raw.rpixels) |px| {
                            const index = @intCast(usize, (rects[i].y + padding + @intCast(i32, y)) * atlasw + (rects[i].x + padding + @intCast(i32, x)));
                            atlas[index] = px[y * @intCast(usize, chars[i].raw.width) + x];
                        }
                    }
                }
            } else alog.warn("failed to pack char: {}", .{i});
        }

        // convert image data from grayscale to grayalpha
        // two channels
        var gralpha: []u8 = alloc.alloc(u8, @intCast(usize, atlasw * atlash * 2)) catch return Error.FailedToLoadTexture;
        {
            i = 0;
            var k: usize = 0;
            while (i < atlasw * atlash) : (i += 1) {
                gralpha[k] = 255;
                gralpha[k + 1] = atlas[i];
                k += 2;
            }
        }
        alloc.free(atlas);
        atlas = gralpha;
        return TextureRaw{ .pixels = atlas, .width = atlasw, .height = atlash };
    }

    /// Returns index position for a unicode char on font
    pub fn glyphIndex(self: Font, codepoint: i32) i32 {
        var index: i32 = char_fallback;

        var i: usize = 0;
        while (i < self.glyphs.len) : (i += 1) {
            if (self.glyphs[i].codepoint == codepoint) return @intCast(i32, i);
        }
        return index;
    }

    // source: https://github.com/raysan5/raylib/blob/cba412cc313e4f95eafb3fba9303400e65c98984/src/text.c#L1071
    /// Measure string size for Font
    pub fn measure(self: Font, string: []const u8, pixelsize: f32, spacing: f32) m.Vec2f {
        const len = @intCast(i32, string.len);
        var tlen: i32 = 0;
        var lenc: i32 = 0;

        var swi: f32 = 0;
        var tswi: f32 = 0;

        var shi: f32 = @intToFloat(f32, self.base_size);
        var scale_factor: f32 = pixelsize / shi;

        var letter: i32 = 0;
        var index: usize = 0;

        var i: usize = 0;
        while (i < len) : (i += 1) {
            lenc += 1;

            var next: i32 = 0;

            letter = utf8.nextCodepoint(string[i..], &next);
            index = @intCast(usize, self.glyphIndex(letter));

            // NOTE: normally we exit the decoding sequence as soon as a bad byte is found (and return 0x3f)
            // but we need to draw all of the bad bytes using the '?' symbol so to not skip any we set next = 1
            if (letter == 0x3f) next = 1;
            i += @intCast(usize, next - 1);

            if (letter == '\n') {
                if (self.glyphs[index].advance != 0) {
                    swi += @intToFloat(f32, self.glyphs[index].advance);
                } else swi += self.rects[index].size.x + @intToFloat(f32, self.glyphs[index].offx);
            } else {
                if (tswi < swi) tswi = swi;
                lenc = 0;
                tswi = 0;
                shi = @intToFloat(f32, self.base_size) * 1.5;
            }

            if (tlen < lenc) tlen = lenc;
        }

        if (tswi < swi) tswi = swi;

        return m.Vec2f{
            .x = tswi * scale_factor + @intToFloat(f32, tlen - 1) * spacing,
            .y = shi * scale_factor,
        };
    }

    pub fn createFromTTF(alloc: *std.mem.Allocator, filepath: []const u8, chars: ?[]const i32, pixelsize: i32) Error!Font {
        var mem = try fs.readFile(alloc, filepath);
        defer alloc.free(mem);
        return createFromTTFMemory(alloc, mem, chars, pixelsize);
    }

    pub fn createFromTTFMemory(alloc: *std.mem.Allocator, mem: []const u8, chars: ?[]const i32, pixelsize: i32) Error!Font {
        var result = Font{};
        result.alloc = alloc;
        result.base_size = pixelsize;
        result.glyph_padding = 0;

        result.glyphs = try loadFontData(alloc, mem, result.base_size, chars);

        result.glyph_padding = char_padding;

        var atlas = try result.genImageAtlas();
        result.texture.width = atlas.width;
        result.texture.height = atlas.height;

        gl.texturesGen(1, @ptrCast([*]u32, &result.texture.id));
        gl.textureBind(gl.TextureType.t2D, result.texture.id);
        defer gl.textureBind(gl.TextureType.t2D, 0);

        gl.textureTexParameteri(gl.TextureType.t2D, gl.TextureParamaterType.min_filter, gl.TextureParamater.filter_nearest);
        gl.textureTexParameteri(gl.TextureType.t2D, gl.TextureParamaterType.mag_filter, gl.TextureParamater.filter_linear);

        gl.textureTexParameteri(gl.TextureType.t2D, gl.TextureParamaterType.wrap_s, gl.TextureParamater.wrap_repeat);
        gl.textureTexParameteri(gl.TextureType.t2D, gl.TextureParamaterType.wrap_t, gl.TextureParamater.wrap_repeat);

        if (atlas.pixels) |pixels| {
            gl.textureTexImage2D(gl.TextureType.t2D, 0, gl.TextureFormat.rg8, result.texture.width, result.texture.height, 0, gl.TextureFormat.rg, u8, @ptrCast(?*c_void, pixels));

            // source: https://github.com/raysan5/raylib/blob/cba412cc313e4f95eafb3fba9303400e65c98984/src/rlgl.h#L2447
            const swizzle = comptime [_]u32{ c.GL_RED, c.GL_RED, c.GL_RED, c.GL_GREEN };
            c.glTexParameteriv(c.GL_TEXTURE_2D, c.GL_TEXTURE_SWIZZLE_RGBA, @ptrCast([*c]const i32, &swizzle));
            gl.texturesGenMipmap(gl.TextureType.t2D);

            alloc.free(pixels);
        }

        return result;
    }

    pub fn destroy(self: *Font) void {
        var i: usize = 0;
        while (i < self.glyphs.len) : (i += 1) {
            if (self.glyphs[i].raw.pixels) |px|
                self.alloc.free(px);
        }
        self.alloc.free(self.rects);
        self.alloc.free(self.glyphs);
        self.texture.destroy();
    }
};
