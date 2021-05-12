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

const glfw = @import("glfw.zig");
const time = @import("std").time;

usingnamespace @import("log.zig");
const alogw = std.log.scoped(.alka_core_window);

pub const FrameTime = struct {
    update: f64 = 0,
    draw: f64 = 0,
    delta: f64 = 0,
    last: f64 = 0,
    current: f64 = 0,

    /// Start updating frametime
    pub fn start(fr: *FrameTime) glfw.GLFWError!void {
        fr.current = try glfw.getTime();
        fr.update = fr.current - fr.last;
        fr.last = fr.current;
    }

    /// Stop updating frametime
    pub fn stop(fr: *FrameTime) glfw.GLFWError!void {
        fr.current = try glfw.getTime();
        fr.draw = fr.current - fr.last;
        fr.last = fr.current;

        fr.delta = fr.update + fr.draw;
    }

    /// Sleep for the sake of cpu
    pub fn sleep(fr: *FrameTime, targetfps: f64) glfw.GLFWError!void {
        if (fr.delta < targetfps) {
            const ms = (targetfps - fr.delta) * 1000;
            const sleep_time = ms * 1000000;
            time.sleep(@floatToInt(u64, sleep_time));

            fr.current = try glfw.getTime();
            fr.delta += fr.current - fr.last;
            fr.last = fr.current;
        }
    }
};

pub const FpsCalculator = struct {
    counter: u32 = 0,
    fps: u32 = 0,
    last: f64 = 0,

    /// Calculates the fps
    pub fn calculate(fp: FpsCalculator, fr: FrameTime) FpsCalculator {
        var fps = fp;
        const fuck = fr.current - fps.last;
        fps.counter += 1;
        if (fuck >= 1.0) {
            fps.fps = fps.counter;
            fps.counter = 0;
            fps.last = fr.current;
        }
        return fps;
    }
};

pub const Info = struct {
    handle: ?*glfw.Window = null,
    title: []const u8 = "<Insert Title>",

    size: Size = Size{},
    minsize: Size = Size{},
    maxsize: Size = Size{},
    position: Position = Position{},
    callbacks: Callbacks = Callbacks{},

    pub const Size = struct {
        width: i32 = 1024,
        height: i32 = 768,
    };

    pub const Position = struct {
        x: i32 = 0,
        y: i32 = 0,
    };

    pub const UpdateProperty = enum { size, sizelimits, title, position, all };

    pub const Callbacks = struct {
        close: ?fn (handle: ?*glfw.Window) void = null,
        resize: ?fn (handle: ?*glfw.Window, w: i32, h: i32) void = null,
        mousepos: ?fn (handle: ?*glfw.Window, x: f64, y: f64) void = null,
        mouseinp: ?fn (handle: ?*glfw.Window, key: i32, ac: i32, mods: i32) void = null,
        keyinp: ?fn (handle: ?*glfw.Window, key: i32, sc: i32, ac: i32, mods: i32) void = null,
        textinp: ?fn (handle: ?*glfw.Window, codepoint: u32) void = null,
    };

    /// Create the window
    pub fn create(win: *Info, fullscreen: bool, centered: bool) glfw.GLFWError!void {
        if (win.handle != null)
            alogw.crit("handle must be null while creating the window! Continuing execution.", .{});

        win.handle = try glfw.createWindow(win.size.width, win.size.height, @ptrCast([*:0]const u8, win.title), if (fullscreen) try glfw.getPrimaryMonitor() else null, null);

        if (centered) {
            var monitor = try glfw.getPrimaryMonitor();
            const videomode = try glfw.getVideoMode(monitor);

            win.position.x = @divTrunc((videomode.width - win.size.width), 2);
            win.position.y = @divTrunc((videomode.height - win.size.height), 2);
        }

        try win.setCallbacks();
        try win.update(UpdateProperty.all);
    }

    /// Create the window
    pub fn createPro(win: *Info, monitor: ?*glfw.Monitor) glfw.GLFWError!void {
        if (win.handle != null)
            alogw.crit("handle must be null while creating the window! Continuing execution.", .{});

        win.handle = try glfw.createWindow(win.size.width, win.size.height, @ptrCast([*:0]const u8, win.title), monitor, null);

        try win.setCallbacks();
        try win.update(UpdateProperty.all);
    }

    /// Sets the window callbacks
    pub fn setCallbacks(win: *Info) glfw.GLFWError!void {
        if (win.callbacks.close != null) {
            _ = try glfw.setWindowCloseCallback(win.handle, @ptrCast(glfw.WindowCloseFun, win.callbacks.close));
        }
        if (win.callbacks.resize != null) {
            _ = try glfw.setWindowSizeCallback(win.handle, @ptrCast(glfw.WindowSizeFun, win.callbacks.resize));
        }
        if (win.callbacks.mousepos != null) {
            _ = try glfw.setCursorPosCallback(win.handle, @ptrCast(glfw.CursorPosFun, win.callbacks.mousepos));
        }
        if (win.callbacks.mouseinp != null) {
            _ = try glfw.setMouseButtonCallback(win.handle, @ptrCast(glfw.MouseButtonFun, win.callbacks.mouseinp));
        }
        if (win.callbacks.keyinp != null) {
            _ = try glfw.setKeyCallback(win.handle, @ptrCast(glfw.KeyFun, win.callbacks.keyinp));
        }
        if (win.callbacks.textinp != null) {
            _ = try glfw.setCharCallback(win.handle, @ptrCast(glfw.CharFun, win.callbacks.textinp));
        }
    }

    /// Destroys the window
    pub fn destroy(win: *Info) glfw.GLFWError!void {
        if (win.handle == null)
            alogw.crit("handle has to be valid when destroying the window! Continuing execution.", .{});
        try glfw.destroyWindow(win.handle);
        win.handle = null;
    }

    /// Updates the properties
    pub fn update(win: *Info, p: UpdateProperty) glfw.GLFWError!void {
        switch (p) {
            UpdateProperty.size => {
                try glfw.setWindowSize(win.handle, win.size.width, win.size.height);
            },
            UpdateProperty.sizelimits => {
                try glfw.setWindowSizeLimits(win.handle, win.minsize.width, win.minsize.height, win.maxsize.width, win.maxsize.height);
            },
            UpdateProperty.title => {
                try glfw.setWindowTitle(win.handle, @ptrCast([*:0]const u8, win.title));
            },
            UpdateProperty.position => {
                try glfw.setWindowPos(win.handle, win.position.x, win.position.y);
            },
            UpdateProperty.all => {
                try glfw.setWindowSize(win.handle, win.size.width, win.size.height);
                try glfw.setWindowSizeLimits(win.handle, win.minsize.width, win.minsize.height, win.maxsize.width, win.maxsize.height);
                try glfw.setWindowTitle(win.handle, @ptrCast([*:0]const u8, win.title));
                try glfw.setWindowPos(win.handle, win.position.x, win.position.y);
            },
        }
    }
};
