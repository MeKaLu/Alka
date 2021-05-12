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
const Builder = @import("std").build.Builder;
const Build = @import("std").build;
const Builtin = @import("std").builtin;
const Zig = @import("std").zig;

const globalflags = [_][]const u8{"-std=c99"};

pub var strip = false;

pub fn compileGLFWWin32(exe: *Build.LibExeObjStep, comptime enginepath: []const u8) void {
    const flags = [_][]const u8{"-O2"} ++ globalflags;
    exe.linkSystemLibrary("gdi32");
    exe.linkSystemLibrary("opengl32");

    exe.defineCMacro("_GLFW_WIN32");

    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/wgl_context.c", &flags);

    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/win32_init.c", &flags);
    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/win32_joystick.c", &flags);
    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/win32_monitor.c", &flags);
    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/win32_thread.c", &flags);
    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/win32_time.c", &flags);
    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/win32_window.c", &flags);
}

pub fn compileGLFWLinux(exe: *Build.LibExeObjStep, comptime enginepath: []const u8) void {
    const flags = [_][]const u8{"-O2"} ++ globalflags;
    exe.linkSystemLibrary("X11");

    exe.defineCMacro("_GLFW_X11");

    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/glx_context.c", &flags);

    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/posix_thread.c", &flags);
    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/posix_time.c", &flags);

    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/x11_init.c", &flags);
    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/x11_window.c", &flags);
    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/x11_monitor.c", &flags);

    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/xkb_unicode.c", &flags);
    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/linux_joystick.c", &flags);
}

pub fn compileGLFWShared(exe: *Build.LibExeObjStep, comptime enginepath: []const u8) void {
    const flags = [_][]const u8{"-O2"} ++ globalflags;
    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/init.c", &flags);
    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/context.c", &flags);
    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/input.c", &flags);
    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/monitor.c", &flags);
    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/window.c", &flags);
    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/vulkan.c", &flags);

    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/osmesa_context.c", &flags);
    exe.addCSourceFile(enginepath ++ "include/glfw-3.3.2/src/egl_context.c", &flags);

    exe.addIncludeDir(enginepath ++ "include/glfw-3.3.2/include/");
}

pub fn compileOneFile(exe: *Build.LibExeObjStep, comptime enginepath: []const u8) void {
    const flags = [_][]const u8{"-O3"} ++ globalflags;
    exe.addCSourceFile(enginepath ++ "include/onefile/GLAD/gl.c", &flags);
    exe.addCSourceFile(enginepath ++ "include/onefile/stb/image.c", &flags);
    exe.addCSourceFile(enginepath ++ "include/onefile/stb/rect_pack.c", &flags);
    exe.addCSourceFile(enginepath ++ "include/onefile/stb/truetype.c", &flags);
}

pub fn setup(b: *Builder, target: Zig.CrossTarget, comptime gamename: []const u8, comptime gamepath: []const u8, comptime enginepath: []const u8) *Build.LibExeObjStep {
    const exe = b.addExecutable(gamename, gamepath);
    exe.strip = strip;
    exe.linkSystemLibrary("c");
    exe.addIncludeDir(enginepath ++ "include/onefile/");

    compileOneFile(exe, enginepath);

    const target_os = target.getOsTag();
    switch (target_os) {
        .windows => {
            exe.setTarget(target);

            exe.linkSystemLibrary("gdi32");
            exe.linkSystemLibrary("opengl32");

            exe.subsystem = Builtin.SubSystem.Console;

            compileGLFWWin32(exe, enginepath);
        },
        .linux => {
            exe.setTarget(target);
            exe.linkSystemLibrary("X11");

            compileGLFWLinux(exe, enginepath);
        },
        else => {},
    }

    compileGLFWShared(exe, enginepath);

    return exe;
}

pub fn setupWithStatic(b: *Builder, target: Zig.CrossTarget, gamename: []const u8, gamepath: []const u8, comptime enginepath: []const u8) *Build.LibExeObjStep {
    const exe = b.addExecutable(gamename, gamepath);

    exe.addPackagePath("alka_core", enginepath ++ "src/core/core.zig");
    exe.addPackagePath("alka", enginepath ++ "src/alka.zig");

    exe.strip = strip;
    exe.linkSystemLibrary("c");
    exe.addIncludeDir(enginepath ++ "include/onefile/");

    compileOneFile(exe, enginepath);

    const target_os = target.getOsTag();
    switch (target_os) {
        .windows => {
            exe.setTarget(target);

            exe.linkSystemLibrary("gdi32");
            exe.linkSystemLibrary("opengl32");

            exe.subsystem = Builtin.SubSystem.Console;

            compileGLFWWin32(exe, enginepath);
        },
        .linux => {
            exe.setTarget(target);
            exe.linkSystemLibrary("X11");

            compileGLFWLinux(exe, enginepath);
        },
        else => {},
    }

    compileGLFWShared(exe, enginepath);

    return exe;
}
