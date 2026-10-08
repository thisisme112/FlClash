#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform float uDusk;
uniform vec2 uSeam;
uniform vec2 uAlong;
uniform float uHalfSpan;
uniform float uMaxGap;
uniform float uParting;
uniform vec2 uTrailA;
uniform vec2 uTrailB;
uniform float uTrailWidth;
uniform float uLaunch;
uniform float uBeam;
uniform sampler2D uSky;

out vec4 fragColor;

float opening(float along) {
  float front = uHalfSpan * (0.15 + 3.0 * uParting);
  float arc = along / front;
  float ease = uParting * uParting * (3.0 - 2.0 * uParting);
  return ease * sqrt(max(0.0, 1.0 - arc * arc));
}

float glow(float distance, float width) {
  float scaled = distance / max(width, 0.5);
  return exp(-scaled * scaled);
}

vec3 contrail(vec3 sky, vec2 point) {
  vec2 flight = uTrailB - uTrailA;
  float length2 = dot(flight, flight);
  if (uLaunch <= 0.0 || length2 < 1.0) {
    return sky;
  }
  float along = clamp(dot(point - uTrailA, flight) / length2, 0.0, 1.0);
  vec2 offset = point - uTrailA - flight * along;
  vec2 across = vec2(-uAlong.y, uAlong.x);
  float distance = dot(offset, across);
  float width = uTrailWidth * (1.5 - along * 0.9);
  float ends = smoothstep(0.0, 0.035, along) * (1.0 - smoothstep(0.985, 1.0, along));
  float core = glow(distance, width * 0.32);
  float halo = glow(distance, width * 1.8);
  float pink = glow(distance - width * 0.65, width * 0.4);
  vec3 light = mix(vec3(0.90, 0.97, 1.0), vec3(1.0, 0.90, 0.94), uDusk);
  vec3 color = mix(sky, light, core * ends * 0.88 * uLaunch);
  return color + (vec3(0.52, 0.76, 1.0) * halo * 0.1 + vec3(1.0, 0.68, 0.79) * pink * 0.055) * ends * uLaunch;
}

void main() {
  vec2 point = FlutterFragCoord().xy;
  vec2 across = vec2(-uAlong.y, uAlong.x);
  vec2 offset = point - uSeam;
  float along = dot(offset, uAlong);
  float distance = dot(offset, across);
  float side = distance < 0.0 ? -1.0 : 1.0;
  float open = opening(along);
  float gap = open * uMaxGap * 1.3;
  float billow = (sin(along * 0.016 + side) * 8.0 + sin(along * 0.037) * 3.0) * open;
  float edge = abs(distance) - gap - billow;
  float cover = open <= 0.0 ? 1.0 : smoothstep(-1.0, 2.0, edge);
  vec2 source = mix(point, uSize * 0.5, uParting * 0.035);
  vec3 sky = texture(uSky, clamp(source / uSize, 0.0, 1.0)).rgb;
  sky = contrail(sky, point);
  float silver = glow(edge, 9.0) * min(1.0, open * 6.0);
  vec3 rim = mix(vec3(0.94, 0.98, 1.0), vec3(1.0, 0.84, 0.79), uDusk);
  sky = mix(sky, rim, silver * 0.38);
  float beam = uBeam * glow(distance, gap * 0.5 + 16.0) * 0.15;
  float alpha = max(cover, beam);
  vec3 color = sky * cover + rim * beam;
  fragColor = vec4(min(color, vec3(alpha)), alpha);
}
