#version 460 core

precision highp float;

#include <flutter/runtime_effect.glsl>

// The lens at the edge of a piece of drawn glass.
//
// Apple's Liquid Glass is thick at its rim: the last points before the edge
// do not show what lies under them, but a squeezed mirror image of what lies
// further in. The edge itself shows the spine of the piece, the line that
// is farthest from every edge, and the pull dies away towards the inside.
//
// This runs as a backdrop filter over glass that is already drawn, so it only
// moves pixels around. Everything is measured in pixels of the picture the
// engine hands in.

// The size of that picture. The engine fills this in.
uniform vec2 u_size;
// The middle of the glass and half its width and height.
uniform vec2 u_center;
uniform vec2 u_half;
// The radius of its corners.
uniform float u_radius;
// How far from the edge the bending starts.
uniform float u_band;
// How far towards the spine the edge reaches: all the way at 1, which
// mirrors what it shows, and not at all at 0.
uniform float u_fold;

uniform sampler2D u_backdrop;

out vec4 frag_color;

void main() {
  vec2 from_center = FlutterFragCoord().xy - u_center;
  // The nearest point of the spine, and the way from there to this pixel.
  vec2 reach = max(u_half - u_radius, 0.0);
  vec2 spine = clamp(from_center, -reach, reach);
  vec2 out_from_spine = from_center - spine;
  float depth = u_radius - length(out_from_spine);
  float pull = clamp(1.0 - depth / max(u_band, 0.001), 0.0, 1.0);
  pull *= sqrt(pull) * u_fold;
  vec2 seen = u_center + spine + out_from_spine * (1.0 - pull);
  // Flutter up to 3.44 handed such a picture over upside down on OpenGL ES,
  // and its documentation still says to turn it there. Later versions, which
  // this app is built with, keep it upright on every backend.
  frag_color = texture(u_backdrop, seen / u_size);
}
