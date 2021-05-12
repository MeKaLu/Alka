#version 330 core

out vec4 final;
in vec2 ourTexCoord;
in vec4 ourColour;
uniform sampler2D uTexture;

void main() {
  vec4 sampled = vec4(1, 1, 1, texture(uTexture, ourTexCoord).r);
  final = vec4(ourColour.xyz, 1.0) * sampled;
}
