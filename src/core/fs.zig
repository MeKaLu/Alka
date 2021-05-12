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
pub const Error = error{FailedToReadFile};

pub fn readFile(alloc: *std.mem.Allocator, path: []const u8) Error![]const u8 {
    var f = std.fs.cwd().openFile(path, .{ .read = true }) catch return Error.FailedToReadFile;
    defer f.close();

    f.seekFromEnd(0) catch return Error.FailedToReadFile;
    const size = f.getPos() catch return Error.FailedToReadFile;
    f.seekTo(0) catch return Error.FailedToReadFile;
    const mem = f.readToEndAlloc(alloc, size) catch return Error.FailedToReadFile;
    return mem;
}
