#version 460 core

precision highp float;

#include <flutter/runtime_effect.glsl>

// Lets a blurred picture go, from full above to nothing below.
//
// It runs over a blur of the page, as the outer part of a filter whose inner
// part is the blur. Where it lets go, the page below shows through, so a few
// blurs laid over one another, each letting go a little further down, turn
// smoothly from a strong blur to none, with no step between them.
//
// Positions are in the screen's pixels, from its top.

// The size of the blurred picture. The engine fills this in.
uniform vec2 u_size;
// Where the blur starts to let go, and where it is gone.
uniform float u_from;
uniform float u_to;

uniform sampler2D u_blurred;

out vec4 frag_color;

void main() {
  vec2 position = FlutterFragCoord().xy;
  float kept = 1.0 - smoothstep(u_from, u_to, position.y);
  // Colours come premultiplied: all four fade together.
  frag_color = texture(u_blurred, position / u_size) * kept;
}
