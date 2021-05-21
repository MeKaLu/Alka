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
const alka = @import("alka.zig");
const m = alka.math;
const utils = @import("core/utils.zig");
const UniqueList = utils.UniqueList;

usingnamespace @import("core/log.zig");
const alog = std.log.scoped(.alka_gui);

/// Error Set
pub const Error = error{ GUIisAlreadyInitialized, GUIisNotInitialized, InvalidCanvasID } || alka.Error;

pub const Events = struct {
    update: ?fn (self: *Element, deltatime: f32) anyerror!void = null,
    fixed: ?fn (self: *Element, fixedtime: f32) anyerror!void = null,
    draw: ?fn (self: *Element) anyerror!void = null,

    onCreate: ?fn (self: *Element) anyerror!void = null,
    onDestroy: ?fn (self: *Element) anyerror!void = null,

    onEnter: ?fn (self: *Element, position: m.Vec2f) anyerror!void = null,

    onHover: ?fn (self: *Element, position: m.Vec2f) anyerror!void = null,

    /// State does not matter
    onClick: ?fn (self: *Element, position: m.Vec2f, button: alka.input.Mouse) anyerror!void = null,

    onPressed: ?fn (self: *Element, position: m.Vec2f, button: alka.input.Mouse) anyerror!void = null,
    onDown: ?fn (self: *Element, position: m.Vec2f, button: alka.input.Mouse) anyerror!void = null,
    onReleased: ?fn (self: *Element, position: m.Vec2f, button: alka.input.Mouse) anyerror!void = null,

    onExit: ?fn (self: *Element, position: m.Vec2f) anyerror!void = null,
};

pub const Element = struct {
    id: ?u64 = null,

    transform: m.Transform2D = undefined,
    colour: alka.Colour = undefined,
    events: Events = undefined,

    /// Initializes the element
    /// DO NOT USE MANUALLY
    pub fn init(id: u64, tr: m.Transform2D, colour: alka.Colour) Element {
        return Element{
            .id = id,
            .transform = tr,
            .colour = colour,
            .events = Events{},
        };
    }

    /// Deinitializes the element
    /// DO NOT USE MANUALLY
    pub fn deinit(self: *Element) void {
        self.events = undefined;
        self.id = null;
    }
};

const Canvas = struct {
    alloc: *std.mem.Allocator = undefined,
    id: ?u64 = null,

    transform: m.Transform2D = undefined,
    colour: alka.Colour = undefined,
    elements: UniqueList(Element) = undefined,

    fn calculateElementTransform(canvas: m.Transform2D, tr: m.Transform2D) m.Transform2D {
        const newpos = canvas.position.add(tr.position);
        const newsize = tr.size;
        const newrot: f32 = canvas.rotation + tr.rotation;

        return m.Transform2D{ .position = newpos, .size = newsize, .rotation = newrot };
    }

    fn calculateElementColour(canvas: alka.Colour, col: alka.Colour) alka.Colour {
        const newcol = alka.Colour{
            .r = canvas.r * col.r,
            .g = canvas.g * col.g,
            .b = canvas.b * col.b,
            .a = canvas.a * col.a,
        };

        return newcol;
    }

    /// Initializes the canvas
    pub fn init(alloc: *std.mem.Allocator, id: u64, tr: m.Transform2D, colour: alka.Colour) Error!Canvas {
        return Canvas{
            .alloc = alloc,
            .id = id,
            .transform = tr,
            .colour = colour,
            .elements = try UniqueList(Element).init(alloc, 0),
        };
    }

    /// Deinitializes the canvas
    /// also destroys the elements
    /// can return `anyerror`
    pub fn deinit(self: *Canvas) !void {
        var it = self.elements.iterator();

        while (it.next()) |entry| {
            if (entry.data != null) {
                // .next() increases the index by 1
                // so we need '- 1' to get the current entry
                var element = &self.elements.items[it.index - 1].data.?;

                if (element.events.onDestroy) |fun| try fun(element);
                element.deinit();
            }
        }

        self.elements.deinit();
        self.id = null;
    }

    /// Creates a element
    /// can return `anyerror`
    pub fn createElement(self: *Canvas, id: u64, transform: m.Transform2D, colour: alka.Colour) !*Element {
        var element = Element.init(
            id,
            calculateElementTransform(self.transform, transform),
            calculateElementColour(self.colour, colour),
        );
        try self.elements.append(id, element);

        var ptr = try self.elements.getPtr(id);
        if (ptr.events.onCreate) |fun| try fun(ptr);

        return ptr;
    }

    /// Returns the READ-ONLY element
    pub fn getElement(self: Canvas, id: u64) Error!Element {
        return self.elements.get(id);
    }

    /// Returns the MUTABLE element
    pub fn getElementPtr(self: *Canvas, id: u64) Error!*Element {
        return self.elements.getPtr(id);
    }

    /// Destroys a element
    /// can return `anyerror`
    pub fn destroyElement(self: *Canvas, id: u64) !void {
        var element = try self.elements.getPtr(id);

        if (element.events.onDestroy) |fun| try fun(ptr);
        element.deinit();

        if (!self.elements.remove(id)) return Error.InvalidCanvasID;
    }

    /// Update the canvas
    /// can return `anyerror`
    pub fn update(self: Canvas, dt: f32) !void {
        var it = self.elements.iterator();

        while (it.next()) |entry| {
            if (entry.data != null) {
                // .next() increases the index by 1
                // so we need '- 1' to get the current entry
                var element = &self.elements.items[it.index - 1].data.?;

                if (element.events.update) |fun| try fun(element, dt);
            }
        }
    }

    /// (fixed) Update the canvas
    /// can return `anyerror`
    pub fn fixed(self: Canvas, dt: f32) !void {
        var it = self.elements.iterator();

        while (it.next()) |entry| {
            if (entry.data != null) {
                // .next() increases the index by 1
                // so we need '- 1' to get the current entry
                var element = &self.elements.items[it.index - 1].data.?;

                if (element.events.fixed) |fun| try fun(element, dt);
            }
        }
    }

    /// Draw the canvas
    /// can return `anyerror`
    pub fn draw(self: Canvas) !void {
        var it = self.elements.iterator();

        while (it.next()) |entry| {
            if (entry.data != null) {
                // .next() increases the index by 1
                // so we need '- 1' to get the current entry
                var element = &self.elements.items[it.index - 1].data.?;

                if (element.events.draw) |fun| try fun(element);
            }
        }
    }
};

const Private = struct {
    alloc: *std.mem.Allocator = undefined,

    canvas: UniqueList(Canvas) = undefined,

    is_initialized: bool = false,
};

var p = Private{};

/// Initializes the GUI interface
pub fn init(alloc: *std.mem.Allocator) Error!void {
    if (p.is_initialized) return Error.GUIisAlreadyInitialized;

    p.alloc = alloc;

    p.canvas = try UniqueList(Canvas).init(p.alloc, 0);

    p.is_initialized = true;
    alog.info("fully initialized!", .{});
}

/// Deinitializes the GUI interface
/// also destroys the elements
/// can return `anyerror`
pub fn deinit() !void {
    if (!p.is_initialized) return Error.GUIisNotInitialized;

    var it = p.canvas.iterator();

    while (it.next()) |entry| {
        if (entry.data != null) {
            // .next() increases the index by 1
            // so we need '- 1' to get the current entry
            var canvas = &p.canvas.items[it.index - 1].data.?;
            try canvas.deinit();
        }
    }

    p.canvas.deinit();

    p = Private{};

    p.is_initialized = false;
    alog.info("fully deinitialized!", .{});
}

/// Creates a canvas
pub fn createCanvas(id: u64, tr: m.Transform2D, col: alka.Colour) Error!*Canvas {
    if (!p.is_initialized) return Error.GUIisNotInitialized;

    var canvas = try Canvas.init(p.alloc, id, tr, col);
    try p.canvas.append(id, canvas);
    return p.canvas.getPtr(id);
}

/// Returns the READ-ONLY canvas
pub fn getCanvas(id: u64) Error!Canvas {
    if (!p.is_initialized) return Error.GUIisNotInitialized;

    return p.canvas.get(id);
}

/// Returns the MUTABLE canvas
pub fn getCanvasPtr(id: u64) Error!*Canvas {
    if (!p.is_initialized) return Error.GUIisNotInitialized;

    return p.canvas.getPtr(id);
}

/// Destroys a canvas
/// can return `anyerror`
pub fn destroyCanvas(id: u64) !void {
    if (!p.is_initialized) return Error.GUIisNotInitialized;

    var canvas = try p.canvas.getPtr(id);
    try canvas.deinit();

    if (!p.canvas.remove(id)) return Error.InvalidCanvasID;
}

/// Update the canvases
/// can return `anyerror`
pub fn update(dt: f32) !void {
    var it = p.canvas.iterator();

    while (it.next()) |entry| {
        if (entry.data != null) {
            // .next() increases the index by 1
            // so we need '- 1' to get the current entry
            var element = &p.canvas.items[it.index - 1].data.?;
            if (element.id != null) try element.update(dt);
        }
    }
}

/// (fixed) Update the canvases
/// can return `anyerror`
pub fn fixed(dt: f32) !void {
    var it = p.canvas.iterator();

    while (it.next()) |entry| {
        if (entry.data != null) {
            // .next() increases the index by 1
            // so we need '- 1' to get the current entry
            var element = &p.canvas.items[it.index - 1].data.?;
            if (element.id != null) try element.fixed(dt);
        }
    }
}

/// Draw the canvases
/// can return `anyerror`
pub fn draw() !void {
    var it = p.canvas.iterator();

    while (it.next()) |entry| {
        if (entry.data != null) {
            // .next() increases the index by 1
            // so we need '- 1' to get the current entry
            var element = &p.canvas.items[it.index - 1].data.?;
            if (element.id != null) try element.draw();
        }
    }
}
