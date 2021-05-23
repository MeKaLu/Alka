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
    pub const State = enum { none, entered, onhover, exited };

    state: State = State.none,

    update: ?fn (self: *Element, deltatime: f32) anyerror!void = null,
    fixed: ?fn (self: *Element, fixedtime: f32) anyerror!void = null,
    draw: ?fn (self: *Element) anyerror!void = null,

    onCreate: ?fn (self: *Element) anyerror!void = null,
    onDestroy: ?fn (self: *Element) anyerror!void = null,

    onEnter: ?fn (self: *Element, position: m.Vec2f, relativepos: m.Vec2f) anyerror!void = null,

    onHover: ?fn (self: *Element, position: m.Vec2f, relativepos: m.Vec2f) anyerror!void = null,

    /// State does not matter
    onClick: ?fn (self: *Element, position: m.Vec2f, relativepos: m.Vec2f, button: alka.input.Mouse) anyerror!void = null,

    onPressed: ?fn (self: *Element, position: m.Vec2f, relativepos: m.Vec2f, button: alka.input.Mouse) anyerror!void = null,
    onDown: ?fn (self: *Element, position: m.Vec2f, relativepos: m.Vec2f, button: alka.input.Mouse) anyerror!void = null,
    onReleased: ?fn (self: *Element, position: m.Vec2f, relativepos: m.Vec2f, button: alka.input.Mouse) anyerror!void = null,

    onExit: ?fn (self: *Element, position: m.Vec2f, relativepos: m.Vec2f) anyerror!void = null,
};

pub const Element = struct {
    id: ?u64 = null,

    transform: m.Transform2D = undefined,

    colour: alka.Colour = undefined,
    events: Events = Events{},

    /// Initializes the element
    /// DO NOT USE MANUALLY
    pub fn init(id: u64, tr: m.Transform2D, colour: alka.Colour) Element {
        return Element{
            .id = id,
            .transform = tr,
            .colour = colour,
        };
    }

    /// Deinitializes the element
    /// DO NOT USE MANUALLY
    pub fn deinit(self: *Element) void {
        self.id = null;
    }
};

const Canvas = struct {
    const CElement = struct {
        element: Element = undefined,
        original_transform: m.Transform2D = undefined,
    };

    /// Iterator
    pub const Iterator = struct {
        parent: *Canvas = undefined,
        index: usize = undefined,

        pub fn next(it: *Iterator) ?*Element {
            if (it.index >= it.parent.elements.items.len) return null;
            var result = &it.parent.elements.items[it.index];
            it.index += 1;
            return if (result.data != null and result.data.?.element.id != null) &result.data.?.element else null;
        }

        /// Reset the iterator
        pub fn reset(it: *Iterator) void {
            it.index = 0;
        }
    };

    alloc: *std.mem.Allocator = undefined,
    id: ?u64 = null,

    transform: m.Transform2D = undefined,

    colour: alka.Colour = undefined,
    elements: UniqueList(CElement) = undefined,

    fn calculateElementTransform(canvas: m.Transform2D, tr: m.Transform2D) m.Transform2D {
        const newpos = canvas.getOriginated().add(tr.getOriginated());
        const newsize = tr.size;
        const newrot: f32 = canvas.rotation + tr.rotation;

        return m.Transform2D{ .position = newpos, .size = newsize, .rotation = newrot };
    }

    /// Initializes the canvas
    pub fn init(alloc: *std.mem.Allocator, id: u64, tr: m.Transform2D, colour: alka.Colour) Error!Canvas {
        return Canvas{
            .alloc = alloc,
            .id = id,
            .transform = tr,
            .colour = colour,
            .elements = try UniqueList(CElement).init(alloc, 1),
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
                var element = &self.elements.items[it.index - 1].data.?.element;

                if (element.events.onDestroy) |fun| try fun(element);
                element.deinit();
            }
        }

        self.elements.deinit();
        self.id = null;
    }

    /// Is the given transform inside of the canvas?
    pub fn isInside(self: Canvas, tr: m.Transform2D) bool {
        const otr = self.transform;

        const o0 = tr.getOriginated();
        const o1 = otr.getOriginated();

        const b0 = o0.x < o1.x + otr.size.x;
        const b1 = o0.y < o1.y + otr.size.y;

        const b2 = o0.x + tr.size.x > o1.x;
        const b3 = o0.y + tr.size.y > o1.y;

        return b0 and b1 and b2 and b3;
    }

    /// Creates a element
    /// NOTE: If element is not inside the canvas, it'll not
    /// call these for that element: update, fixed, draw 
    /// can return `anyerror`
    pub fn createElement(self: *Canvas, id: u64, transform: m.Transform2D, colour: alka.Colour, events: Events) !*Element {
        var element = Element.init(
            id,
            calculateElementTransform(self.transform, transform),
            colour,
        );
        element.events = events;
        try self.elements.append(id, CElement{ .element = element, .original_transform = transform });

        var ptr = try self.elements.getPtr(id);
        if (ptr.element.events.onCreate) |fun| try fun(&ptr.element);

        return &ptr.element;
    }

    /// Returns the READ-ONLY element
    pub fn getElement(self: Canvas, id: u64) Error!Element {
        const con = try self.elements.get(id);
        return con.element;
    }

    /// Returns the MUTABLE element
    pub fn getElementPtr(self: *Canvas, id: u64) Error!*Element {
        var ptr = try self.elements.getPtr(id);
        return &ptr.element;
    }

    /// Destroys a element
    /// can return `anyerror`
    pub fn destroyElement(self: *Canvas, id: u64) !void {
        var element = try self.elements.getPtr(id);

        if (element.element.events.onDestroy) |fun| try fun(&element.element);
        element.element.deinit();

        if (!self.elements.remove(id)) return Error.InvalidCanvasID;
    }

    /// Update the canvas
    /// can return `anyerror`
    pub fn update(self: Canvas, dt: f32) !void {
        var mlist: [alka.input.Info.max_mouse_count]alka.input.Info.BindingManager = undefined;
        var mlist_index: u8 = 0;
        {
            var i: u8 = 0;
            while (i < alka.input.Info.max_mouse_count) : (i += 1) {
                var l = alka.getInput().mouse_list[i];
                if (l.mouse != .Invalid) {
                    mlist[mlist_index] = l;
                    mlist_index += 1;
                }
            }
        }
        const cam = alka.getCamera2D();
        const mpos = alka.getMousePosition();
        //const mpos = cam.worldToScreen(alka.getMousePosition());
        //alog.debug("mpos: {d:.0}:{d:.0}", .{ mpos.x, mpos.y });

        var it = self.elements.iterator();
        while (it.next()) |entry| {
            if (entry.data != null) {
                // .next() increases the index by 1
                // so we need '- 1' to get the current entry
                var celement = &self.elements.items[it.index - 1].data.?;
                var element = &celement.element;
                if (element.events.update) |fun| try fun(element, dt);

                element.transform = calculateElementTransform(self.transform, celement.original_transform);
                if (!self.isInside(element.transform)) continue;

                const tr = element.transform;

                const pos = cam.worldToScreen(tr.getOriginated());
                const size = cam.worldToScreen(tr.size);
                //alog.debug("pos: {d:.0}:{d:.0}", .{ pos.x, pos.y });
                const aabb = blk: {
                    const rect = m.Rectangle{
                        .position = pos,
                        .size = size,
                    };
                    const res = rect.aabb(
                        m.Rectangle{
                            .position = mpos,
                            .size = m.Vec2f{ .x = 2, .y = 2 },
                        },
                    );
                    break :blk res;
                };

                const mrpos = blk: {
                    var mp = m.Vec2f.sub(mpos, pos);
                    if (mp.x < 0) mp.x = 0;
                    if (mp.y < 0) mp.y = 0;
                    break :blk mp;
                };

                switch (element.events.state) {
                    Events.State.none => {
                        if (aabb) {
                            element.events.state = .entered;
                        }
                    },

                    Events.State.entered => {
                        if (element.events.onEnter) |fun| try fun(element, mpos, mrpos);
                        element.events.state = .onhover;
                    },

                    Events.State.onhover => {
                        if (!aabb) {
                            element.events.state = .exited;
                        } else {
                            if (element.events.onHover) |fun|
                                try fun(element, mpos, mrpos);

                            var i: u8 = 0;
                            while (i < mlist_index) : (i += 1) {
                                var l = alka.getInput().mouse_list[i];
                                if (l.mouse != .Invalid) {
                                    switch (l.status) {
                                        .none => {},
                                        .pressed => {
                                            if (element.events.onClick) |mfun| try mfun(element, mpos, mrpos, l.mouse);
                                            if (element.events.onPressed) |mfun| try mfun(element, mpos, mrpos, l.mouse);
                                        },
                                        .down => {
                                            if (element.events.onClick) |mfun| try mfun(element, mpos, mrpos, l.mouse);
                                            if (element.events.onDown) |mfun| try mfun(element, mpos, mrpos, l.mouse);
                                        },
                                        .released => {
                                            if (element.events.onClick) |mfun| try mfun(element, mpos, mrpos, l.mouse);
                                            if (element.events.onReleased) |mfun| try mfun(element, mpos, mrpos, l.mouse);
                                        },
                                    }
                                }
                            }
                        }
                    },

                    Events.State.exited => {
                        if (element.events.onExit) |fun| try fun(element, mpos, mrpos);
                        element.events.state = .none;
                    },
                }
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
                var celement = &self.elements.items[it.index - 1].data.?;
                var element = &celement.element;
                if (element.events.fixed) |fun| try fun(element, dt);

                element.transform = calculateElementTransform(self.transform, celement.original_transform);
                if (!self.isInside(element.transform)) continue;
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
                var celement = &self.elements.items[it.index - 1].data.?;
                var element = &celement.element;
                element.transform = calculateElementTransform(self.transform, celement.original_transform);
                if (!self.isInside(element.transform)) continue;

                if (element.events.draw) |fun| try fun(element);
            }
        }

        return alka.drawRectangleAdv(
            self.transform.getRectangleNoOrigin(),
            self.transform.origin,
            m.deg2radf(self.transform.rotation),
            self.colour,
        );
    }

    /// Draw the canvas lines
    pub fn drawLines(self: Canvas, col: alka.Colour) Error!void {
        return alka.drawRectangleLinesAdv(
            self.transform.getRectangleNoOrigin(),
            self.transform.origin,
            m.deg2radf(self.transform.rotation),
            col,
        );
    }

    /// Returns the original transform of the element
    /// NOTE: READ-ONLY
    pub fn getTransform(self: Canvas, id: u64) Error!m.Transform2D {
        const con = try self.elements.get(id);
        return con.original_transform;
    }

    /// Returns the original transform of the element
    /// NOTE: MUTABLE
    pub fn getTransformPtr(self: *Canvas, id: u64) Error!*m.Transform2D {
        var ptr = try self.elements.getPtr(id);
        return &ptr.original_transform;
    }

    /// Returns the iterator
    pub fn iterator(self: *Canvas) Iterator {
        return Iterator{
            .parent = self,
            .index = 0,
        };
    }
};

const Private = struct {
    const CCanvas = struct {
        canvas: Canvas = undefined,
        original_transform: m.Transform2D = undefined,
    };

    alloc: *std.mem.Allocator = undefined,

    canvas: UniqueList(CCanvas) = undefined,

    is_initialized: bool = false,
};

var p = Private{};

/// Initializes the GUI interface
pub fn init(alloc: *std.mem.Allocator) Error!void {
    if (p.is_initialized) return Error.GUIisAlreadyInitialized;

    p.alloc = alloc;

    p.canvas = try UniqueList(Private.CCanvas).init(p.alloc, 0);

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
            var canvas = &p.canvas.items[it.index - 1].data.?.canvas;
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
    try p.canvas.append(id, Private.CCanvas{ .canvas = canvas, .original_transform = tr });
    var ptr = try p.canvas.getPtr(id);
    return &ptr.canvas;
}

/// Returns the READ-ONLY canvas
pub fn getCanvas(id: u64) Error!Canvas {
    if (!p.is_initialized) return Error.GUIisNotInitialized;

    const con = try p.canvas.get(id);
    return con.canvas;
}

/// Returns the MUTABLE canvas
pub fn getCanvasPtr(id: u64) Error!*Canvas {
    if (!p.is_initialized) return Error.GUIisNotInitialized;

    var ptr = try p.canvas.getPtr(id);
    return &ptr.canvas;
}

/// Destroys a canvas
/// can return `anyerror`
pub fn destroyCanvas(id: u64) !void {
    if (!p.is_initialized) return Error.GUIisNotInitialized;

    var ptr = try p.canvas.getPtr(id);
    var canvas = &ptr.canvas;
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
            var canvas = &p.canvas.items[it.index - 1].data.?.canvas;
            if (canvas.id != null) try canvas.update(dt);
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
            var canvas = &p.canvas.items[it.index - 1].data.?.canvas;
            if (canvas.id != null) try canvas.fixed(dt);
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
            var canvas = &p.canvas.items[it.index - 1].data.?.canvas;
            if (canvas.id != null) try canvas.draw();
        }
    }
}
