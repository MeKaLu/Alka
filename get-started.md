# Examples
More on [examples](https://github.com/Kiakra/Alka/tree/master/examples)

## How to compile?

Download this github repo and copy the "libbuild.zig" file to your project for zig's build system

After that all you need to do put this code in `build.zig` file:

```zig
const Builder = @import("std").build.Builder;
const lib = @import("libbuild.zig");

pub fn build(b: *Builder) void {
	const target = b.standardTargetOptions(.{});
	const mode = b.standardReleaseOptions();
    
  lib.strip = b.option(bool, "strip", "Strip the exe?") orelse false;

  // Note: the 'enginepath' should be a relative path!
  const exe = lib.setupWithStatic(b, target, app_name, path_to_main_src, enginepath); 
  exe.setOutputDir("build");
  exe.setBuildMode(mode);
  exe.install();
}
```
`zig build` and done!

### [Basic application](https://github.com/Kiakra/Alka/blob/master/examples/basic_setup.zig)
