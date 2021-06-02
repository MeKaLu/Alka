const Builder = @import("std").build.Builder;
const Build = @import("std").build;

const lib = @import("libbuild.zig");

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const engine_path = "./";

    lib.strip = b.option(bool, "strip", "Strip the exe?") orelse false;

    const examples = b.option(bool, "examples", "Compile the examples?") orelse false;
    const main = b.option(bool, "main", "Compile the main source?") orelse false;

    if (examples) {
        {
            const exe = lib.setup(b, target, "basic_setup", "examples/basic_setup.zig", engine_path);
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }

        {
            const exe = lib.setup(b, target, "input", "examples/input.zig", engine_path);
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }

        {
            const exe = lib.setup(b, target, "shape_drawing", "examples/shape_drawing.zig", engine_path);
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }

        {
            const exe = lib.setup(b, target, "texture_drawing", "examples/texture_drawing.zig", engine_path);
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }

        {
            const exe = lib.setup(b, target, "text_rendering", "examples/text_rendering.zig", engine_path);
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }

        {
            const exe = lib.setup(b, target, "ecs", "examples/ecs.zig", engine_path);
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }

        {
            const exe = lib.setup(b, target, "ecs_benchmark", "examples/ecs_benchmark.zig", engine_path);
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }

        {
            const exe = lib.setup(b, target, "camera2d", "examples/camera2d.zig", engine_path);
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }

        {
            const exe = lib.setup(b, target, "camera2d_advanced", "examples/camera2d_advanced.zig", engine_path);
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }

        {
            const exe = lib.setup(b, target, "gui", "examples/gui.zig", engine_path);
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }

        {
            const exe = lib.setup(b, target, "custombatch", "examples/custombatch.zig", engine_path);
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }

        {
            const exe = lib.setup(b, target, "customshaders", "examples/customshaders.zig", engine_path);
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }

        {
            const exe = lib.setup(b, target, "shooter", "examples/shooter.zig", engine_path);
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }
    }

    if (main) {
        const exe = b.addExecutable("main", "src/main.zig");
        exe.strip = lib.strip;
        exe.linkSystemLibrary("c");
        exe.addIncludeDir(engine_path ++ "include/onefile/");

        lib.include(exe, engine_path);
        lib.compileOneFile(exe, engine_path);

        const target_os = target.getOsTag();
        switch (target_os) {
            .windows => {
                exe.setTarget(target);

                exe.linkSystemLibrary("gdi32");
                exe.linkSystemLibrary("opengl32");

                exe.subsystem = .Console;

                lib.compileGLFWWin32(exe, engine_path);
            },
            .linux => {
                exe.setTarget(target);
                exe.linkSystemLibrary("X11");

                lib.compileGLFWLinux(exe, engine_path);
            },
            else => {},
        }

        lib.compileGLFWShared(exe, engine_path);
        exe.setOutputDir("build");
        exe.setBuildMode(mode);
        exe.install();

        const run_cmd = exe.run();
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }
}
