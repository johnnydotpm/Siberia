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
// mirrors what it shows, and not at all at 0. Below 0 the rim reaches out
// instead, past the edge, and what lies under the glass shows smaller, as
// through the knob of a switch held on iOS 26.
uniform float u_fold;
// How much the rim parts the colours, as thick glass does: red bent a
// little more than green, blue a little less. 0 keeps them together.
uniform float u_disperse;

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
  vec4 colour = texture(u_backdrop, seen / u_size);
  // Only the bent rim parts the colours: elsewhere one reading does.
  if (u_disperse > 0.0 && abs(pull) > 0.001) {
    vec2 red = u_center + spine + out_from_spine * (1.0 - pull * (1.0 + u_disperse));
    vec2 blue = u_center + spine + out_from_spine * (1.0 - pull * (1.0 - u_disperse));
    colour.r = texture(u_backdrop, red / u_size).r;
    colour.b = texture(u_backdrop, blue / u_size).b;
  }
  frag_color = colour;
}
