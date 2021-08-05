const Builder = @import("std").build.Builder;
const lib = @import("libbuild.zig");

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    lib.strip = b.option(bool, "strip", "Strip the exe?") orelse false;

    const exe = lib.setup(b, target, "app", "src/main.zig", "../../");
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
