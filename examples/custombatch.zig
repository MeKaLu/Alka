const std = @import("std");
const alka = @import("alka");

const m = alka.math;
usingnamespace alka.log;

pub const mlog = std.log.scoped(.app);
pub const log_level: std.log.Level = .info;

const vertex_shader =
    \\#version 330 core
    \\layout (location = 0) in vec2 aPos;
    \\layout (location = 1) in vec2 aTexCoord;
    \\layout (location = 2) in vec4 aColour;
    \\
    \\out vec2 ourTexCoord;
    \\out vec4 ourColour;
    \\uniform mat4 view;
    \\
    \\void main() {
    \\  gl_Position = view * vec4(aPos.xy, 0.0, 1.0);
    \\  ourTexCoord = aTexCoord;
    \\  ourColour = aColour;
    \\}
;

const fragment_shader =
    \\#version 330 core
    \\out vec4 final;
    \\in vec2 ourTexCoord;
    \\in vec4 ourColour;
    \\uniform sampler2D uTexture;
    \\
    \\void main() {
    \\  vec4 texelColour = texture(uTexture, ourTexCoord);
    \\  final = vec4(1, 0, 0, 1) * texelColour; // everything is red
    \\}
;

fn batchDraw(corebatch: alka.Batch2DQuad, mode: alka.gl.DrawMode, shader: *u32, texture: *alka.renderer.Texture, cam2d: *m.Camera2D) alka.Error!void {
    cam2d.attach();
    defer cam2d.detach();

    alka.gl.shaderProgramUse(shader.*);
    defer alka.gl.shaderProgramUse(0);

    alka.gl.textureActive(.texture0);
    alka.gl.textureBind(.t2D, texture.id);
    defer alka.gl.textureBind(.t2D, 0);

    const mvploc = alka.gl.shaderProgramGetUniformLocation(shader.*, "view");
    alka.gl.shaderProgramSetMat4x4f(mvploc, cam2d.view);

    try corebatch.draw(mode);
}

fn draw() !void {
    const asset = alka.getAssetManager();

    // create the batch
    // NOTE: if the batch exists, it won't create one, instead returns the existing batch
    // drawmode, shader_id, texture_id
    var batch = try alka.createBatch(alka.gl.DrawMode.triangles, 1, 0);
    // this way we can change how we draw the batch
    // if not used, it'll draw the defaultbatch
    // which stored at: `Batch.drawDefault`
    batch.drawfun = batchDraw;
    alka.setBatchFun(batch);

    // there is also

    // usefull when using non-assetmanager loaded shaders and textures
    // createBatchNoID(mode: gl.DrawMode, sh: u32, texture: renderer.Texture) Error!Batch
    //
    // every draw call will create batches even if you don't create one explicitly
    // this is usefull in case you need to explicitly use auto-gen batchs
    // getBatch(mode: gl.DrawMode, sh_id: u64, texture_id: u64) Error!Batch
    //
    // usefull when using non-assetmanager loaded shaders and textures
    // getBatchNoID(mode: gl.DrawMode, sh: u32, texture: renderer.Texture) Error!Batch
    //
    // explicitly renders the batch, does not clean the batch tho
    // so you need to use cleanBatch() if you don't want to end up with
    // 2x draw call
    // renderBatch(batch: Batch) Error!void
    //
    // explicitly clears the batch
    // cleanBatch(batch: Batch) void

    // push the batch
    try alka.pushBatch(batch);
    {
        const r = m.Rectangle{ .position = m.Vec2f{ .x = 100.0, .y = 200.0 }, .size = m.Vec2f{ .x = 50.0, .y = 50.0 } };
        const col = alka.Colour{ .r = 1, .g = 1, .b = 1, .a = 1 };
        try alka.drawRectangleAdv(r, m.Vec2f{ .x = 25, .y = 25 }, m.deg2radf(45), col);

        // custom batch forces to use drawmode: triangles, so it'll be corrupted rectangle
        //try alka.drawRectangleLinesAdv(r, m.Vec2f{ .x = 25, .y = 25 }, m.deg2radf(45), col);

        // there is also a 2dcamera in unique to every batch,
        // the alka.getCamera2D() is the global camera which every batch defaults for, every frame
        batch.cam2d.zoom.x = 0.5;
        batch.cam2d.zoom.y = 0.5;
    }
    // pop the batch
    alka.popBatch();

    const r2 = m.Rectangle{ .position = m.Vec2f{ .x = 200.0, .y = 200.0 }, .size = m.Vec2f{ .x = 30.0, .y = 30.0 } };
    const col2 = alka.Colour.rgba(30, 80, 200, 255);
    try alka.drawRectangle(r2, col2);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const callbacks = alka.Callbacks{
        .update = null,
        .fixed = null,
        .draw = draw,
        .resize = null,
        .close = null,
    };

    try alka.init(&gpa.allocator, callbacks, 1024, 768, "Custom batch", 0, false);

    try alka.getAssetManager().loadShader(1, vertex_shader, fragment_shader);

    try alka.open();
    try alka.update();
    try alka.close();

    try alka.deinit();

    const leaked = gpa.deinit();
    if (leaked) return error.Leak;
}
