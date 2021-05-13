// -----------------------------------------
// |           Alka 1.0.0                  |
// -----------------------------------------
//
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
const glfw = @import("glfw.zig");

usingnamespace @import("log.zig");
const alogi = std.log.scoped(.nil_core_input);

/// Error set
pub const Error = error{ InvalidBinding, NoEmptyBinding };

pub const Key = glfw.Key;
pub const Mouse = glfw.Mouse;

/// States
pub const State = enum { none = 0, pressed, down, released };

/// Input info
pub const Info = struct {
    /// For managing key / button states
    /// I prefer call them as bindings
    pub const BindingManager = struct {
        status: State = State.none,
        key: Key = Key.Invalid,
        mouse: Mouse = Mouse.Invalid,
    };

    /// Maximum key count
    pub const max_key_count: u8 = 50;
    /// Maximum mouse button count
    pub const max_mouse_count: u8 = 5;

    /// Binded key list
    key_list: [max_key_count]BindingManager = undefined,
    /// Binded mouse button list
    mouse_list: [max_mouse_count]BindingManager = undefined,

    /// Clears the key bindings
    pub fn keyClearBindings(self: *Info) void {
        var i: u8 = 0;
        var l = &self.key_list;
        while (i < max_key_count) : (i += 1) {
            l[i] = BindingManager{};
        }
    }

    /// Clears the mouse button bindings
    pub fn mouseClearBindings(self: *Info) void {
        var i: u8 = 0;
        var l = &self.mouse_list;
        while (i < max_mouse_count) : (i += 1) {
            l[i] = BindingManager{};
        }
    }

    /// Clears all the bindings
    pub fn clearBindings(self: *Info) void {
        self.keyClearBindings();
        self.mouseClearBindings();
    }

    /// Binds a key
    pub fn bindKey(self: *Info, key: Key) Error!void {
        var i: u8 = 0;
        var l = &self.key_list;
        while (i < max_key_count) : (i += 1) {
            if (i == @enumToInt(Key.Invalid)) {
                continue;
            } else if (l[i].key == Key.Invalid) {
                l[i].key = key;
                l[i].status = State.none;
                return;
            }
        }
        return Error.NoEmptyBinding;
    }

    /// Unbinds a key
    pub fn unbindKey(self: *Info, key: Key) Error!void {
        var i: u8 = 0;
        var l = &self.key_list;
        while (i < max_key_count) : (i += 1) {
            if (l[i].key == key) {
                l[i] = BindingManager{};
                return;
            }
        }
        return Error.InvalidBinding;
    }

    /// Binds a mouse button
    pub fn bindMouse(self: *Info, mouse: Mouse) Error!void {
        var i: u8 = 0;
        var l = &self.mouse_list;
        while (i < max_mouse_count) : (i += 1) {
            if (i == @enumToInt(Mouse.Invalid)) {
                continue;
            } else if (l[i].mouse == Mouse.Invalid) {
                l[i].mouse = mouse;
                l[i].status = State.none;
                return;
            }
        }
        return Error.NoEmptyBinding;
    }

    /// Unbinds a mouse button
    pub fn unbindMouse(self: *Info, mouse: Mouse) Error!void {
        var i: u8 = 0;
        var l = &self.mouse_list;
        while (i < max_mouse_count) : (i += 1) {
            if (l[i].mouse == mouse) {
                l[i] = BindingManager{};
                return;
            }
        }
        return Error.InvalidBinding;
    }

    /// Returns a binded key state
    pub fn keyState(self: *Info, key: Key) Error!State {
        var i: u8 = 0;
        var l = &self.key_list;
        while (i < max_key_count) : (i += 1) {
            if (l[i].key == key) {
                return l[i].status;
            }
        }
        return Error.InvalidBinding;
    }

    /// Returns a const reference to a binded key state
    pub fn keyStatePtr(self: *Info, key: Key) Error!*const State {
        var i: u8 = 0;
        var l = &self.key_list;
        while (i < max_key_count) : (i += 1) {
            if (l[i].key == key) {
                return &l[i].status;
            }
        }
        return Error.InvalidBinding;
    }

    /// Returns a binded key state
    pub fn mouseState(self: *Info, mouse: Mouse) Error!State {
        var i: u8 = 0;
        var l = &self.mouse_list;
        while (i < max_mouse_count) : (i += 1) {
            if (l[i].mouse == mouse) {
                return l[i].status;
            }
        }
        return Error.InvalidBinding;
    }

    /// Returns a const reference to a binded key state
    pub fn mouseStatePtr(self: *Info, mouse: Mouse) Error!*const State {
        var i: u8 = 0;
        var l = &self.mouse_list;
        while (i < max_mouse_count) : (i += 1) {
            if (l[i].mouse == mouse) {
                return &l[i].status;
            }
        }
        return Error.InvalidBinding;
    }

    /// Returns a value based on the given states
    pub fn getValue(comptime rtype: type, left: State, right: State) rtype {
        var r: rtype = undefined;
        if (left == .down) r -= 1;
        if (right == .down) r += 1;
        return r;
    }

    /// Handles the inputs
    /// Warning: Call just before polling/processing the events
    /// Keep in mind binding states will be useless after polling events
    pub fn handle(self: *Info) void {
        var i: u8 = 0;
        while (i < max_key_count) : (i += 1) {
            if (i < max_mouse_count) {
                var l = &self.mouse_list[i];
                if (l.status == State.released) {
                    l.status = State.none;
                } else if (l.status == State.pressed) {
                    l.status = State.down;
                }
            }
            var l = &self.key_list[i];
            if (l.key == Key.Invalid) {
                continue;
            } else if (l.status == State.released) {
                l.status = State.none;
            } else if (l.status == State.pressed) {
                l.status = State.down;
            }
        }
    }

    /// Handles the keyboard inputs
    pub fn handleKeyboard(input: *Info, key: i32, ac: i32) void {
        var l = &input.key_list;
        var i: u8 = 0;
        while (i < Info.max_key_count) : (i += 1) {
            if (@enumToInt(l[i].key) != key) {
                continue;
            }
            switch (ac) {
                0 => {
                    if (l[i].status == State.released) {
                        l[i].status = State.none;
                    } else if (l[i].status == State.down) {
                        l[i].status = State.released;
                    }
                },
                1, 2 => {
                    if (l[i].status != State.down) l[i].status = State.pressed;
                },
                else => {
                    alogi.err("unknown action!", .{});
                },
            }
        }
    }

    /// Handles the mouse button inputs
    pub fn handleMouse(input: *Info, key: i32, ac: i32) void {
        var l = &input.mouse_list;
        var i: u8 = 0;
        while (i < Info.max_mouse_count) : (i += 1) {
            if (@enumToInt(l[i].key) != key) {
                continue;
            }
            switch (ac) {
                0 => {
                    if (l[i].status == State.released) {
                        l[i].status = State.none;
                    } else if (l[i].status == State.down) {
                        l[i].status = State.released;
                    }
                },
                1, 2 => {
                    if (l[i].status != State.down) l[i].status = State.pressed;
                },
                else => {
                    alogi.err("unknown action!", .{});
                },
            }
        }
    }
};
