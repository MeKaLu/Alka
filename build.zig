const Builder = @import("std").build.Builder;
const Build = @import("std").build;

const lib = @import("libbuild.zig");

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    lib.strip = b.option(bool, "strip", "Strip the exe?") orelse false;

    const examples = b.option(bool, "examples", "Compile the examples?") orelse false;
    const main = b.option(bool, "main", "Compile the main source?") orelse false;

    if (examples) {
        {
            const exe = lib.setupWithStatic(b, target, "basic_setup", "examples/basic_setup.zig", "./");
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }

        {
            const exe = lib.setupWithStatic(b, target, "input", "examples/input.zig", "./");
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }

        {
            const exe = lib.setupWithStatic(b, target, "shape_drawing", "examples/shape_drawing.zig", "./");
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }

        {
            const exe = lib.setupWithStatic(b, target, "texture_drawing", "examples/texture_drawing.zig", "./");
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }

        {
            const exe = lib.setupWithStatic(b, target, "text_rendering", "examples/text_rendering.zig", "./");
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }

        {
            const exe = lib.setupWithStatic(b, target, "ecs", "examples/ecs.zig", "./");
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }

        {
            const exe = lib.setupWithStatic(b, target, "ecs_benchmark", "examples/ecs_benchmark.zig", "./");
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }

        {
            const exe = lib.setupWithStatic(b, target, "camera2d", "examples/camera2d.zig", "./");
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }

        {
            const exe = lib.setupWithStatic(b, target, "custombatch", "examples/custombatch.zig", "./");
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }

        {
            const exe = lib.setupWithStatic(b, target, "shooter", "examples/shooter.zig", "./");
            exe.setOutputDir("build");
            exe.setBuildMode(mode);
            exe.install();
        }
    }

    if (main) {
        const exe = lib.setup(b, target, "main", "src/main.zig", "./");
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
