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
uniform vec2 uWave;
uniform sampler2D uSky;

out vec4 fragColor;

vec2 fragCoord() {
  return FlutterFragCoord().xy;
}

vec2 skyUv(vec2 p) {
  return clamp(p / uSize, 0.0, 1.0);
}

const vec2 kLight = vec2(0.62, -0.78);

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash12(i);
  float b = hash12(i + vec2(1.0, 0.0));
  float c = hash12(i + vec2(0.0, 1.0));
  float d = hash12(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
  float value = 0.0;
  float amplitude = 0.5;
  mat2 turn = mat2(1.6, 1.2, -1.2, 1.6);
  for (int i = 0; i < 5; i++) {
    value += amplitude * vnoise(p);
    p = turn * p;
    amplitude *= 0.5;
  }
  return value;
}

float fbm3(vec2 p) {
  float value = 0.0;
  float amplitude = 0.5;
  mat2 turn = mat2(1.6, 1.2, -1.2, 1.6);
  for (int i = 0; i < 3; i++) {
    value += amplitude * vnoise(p);
    p = turn * p;
    amplitude *= 0.5;
  }
  return value;
}

// Noon, or magic hour when the app is dark.
vec3 pal(vec3 noon, vec3 dusk) {
  return mix(noon, dusk, uDusk);
}

vec3 sunColor() { return pal(vec3(1.0, 0.984, 0.918), vec3(1.0, 0.886, 0.722)); }
vec3 rimColor() { return pal(vec3(1.0, 0.906, 0.722), vec3(1.0, 0.69, 0.44)); }
vec3 shadeTop() { return pal(vec3(0.765, 0.812, 0.918), vec3(0.557, 0.475, 0.722)); }
vec3 shadeBottom() { return pal(vec3(0.478, 0.565, 0.769), vec3(0.306, 0.271, 0.514)); }
vec3 cloudBody() { return pal(vec3(0.933, 0.953, 0.988), vec3(0.969, 0.776, 0.706)); }
vec3 cloudLight() { return pal(vec3(1.0, 1.0, 1.0), vec3(1.0, 0.914, 0.824)); }

float openAt(float s) {
  float front = uHalfSpan * (0.1 + 3.2 * uParting);
  float x = s / front;
  float width = uParting * uParting * (3.0 - 2.0 * uParting);
  return width * sqrt(max(0.0, 1.0 - x * x));
}

vec3 cloudTone(float lit) {
  vec3 shade = mix(shadeTop(), shadeBottom(), 0.35);
  vec3 tone = mix(shade, cloudBody(), smoothstep(0.2, 0.7, lit));
  return mix(tone, cloudLight(), smoothstep(0.72, 1.0, lit));
}

// The rocket's contrail and the smoke at the pad, both carried apart with the
// sky as it tears.
vec3 contrail(vec3 color, vec2 q) {
  if (uLaunch <= 0.0) {
    return color;
  }
  vec2 path = uTrailB - uTrailA;
  float length2 = dot(path, path);
  float along = length2 > 1.0 ? clamp(dot(q - uTrailA, path) / length2, 0.0, 1.0) : 0.0;
  vec2 nearest = uTrailA + path * along;
  float width = uTrailWidth * (0.6 + 2.0 * (1.0 - along)) * (1.0 - 0.4 * along);
  float padRadius = uTrailWidth * 2.4 * uLaunch;
  vec2 pad = uTrailA - uAlong * uTrailWidth;
  bool nearTrail = length2 > 1.0 && length(q - nearest) < width * 1.5;
  if (!nearTrail && length(q - pad) > padRadius * 1.5) {
    return color;
  }
  float grain = fbm(q * 0.035 + 11.0);
  float reach = length(q - nearest) + (grain - 0.5) * width * 0.9;
  float trail = length2 > 1.0 ? 1.0 - smoothstep(width * 0.55, width, reach) : 0.0;
  float padReach = length(q - pad) + (grain - 0.5) * uTrailWidth;
  float smoke = (1.0 - smoothstep(padRadius * 0.45, padRadius, padReach)) * uLaunch;
  float amount = max(trail, smoke);
  if (amount <= 0.0) {
    return color;
  }
  vec2 normal = (q - nearest) / max(width, 1.0);
  float lit = clamp(dot(normal, kLight) * 0.6 + 0.55 + (grain - 0.5) * 0.6, 0.0, 1.0);
  return mix(color, cloudTone(lit), amount);
}

void main() {
  vec2 p = fragCoord();
  vec2 across = vec2(-uAlong.y, uAlong.x);
  vec2 offset = p - uSeam;
  float s = dot(offset, uAlong);
  float d = dot(offset, across);
  float side = d < 0.0 ? -1.0 : 1.0;
  float open = openAt(s);
  float gap = open * uMaxGap * 1.3;
  float ragged = open > 0.0
      ? (fbm3(vec2(s * 0.035, side * 5.0)) - 0.5) * 70.0 * min(1.0, open * 5.0)
      : 0.0;
  float fromEdge = abs(d) - gap - ragged;
  vec4 result = vec4(0.0);
  if (open <= 0.0 || fromEdge > 0.0) {
    vec2 source = p - across * side * gap;
    vec3 color = texture(uSky, skyUv(source)).rgb;
    float reach = 120.0 * (0.45 + open);
    if (open > 0.0 && fromEdge < reach * 1.6) {
      vec2 grainAt = vec2(s, fromEdge) * 0.012 + side * 3.1;
      float lumps = vnoise(grainAt) * 0.6 + vnoise(grainAt * 2.3) * 0.25 + fbm(grainAt * 6.0) * 0.15;
      float billow = 1.0 - fromEdge / reach + (lumps - 0.45) * 1.3;
      float amount = smoothstep(0.35, 0.5, billow) * min(1.0, open * 4.0);
      float lit = (1.0 - smoothstep(0.0, reach * 0.9, fromEdge)) * (0.65 + 0.7 * fbm3(grainAt * 2.0));
      vec3 tone = cloudTone(clamp(lit, 0.0, 1.0));
      tone = mix(tone, rimColor(), (1.0 - smoothstep(0.35, 0.46, billow)) * 0.85);
      color = mix(color, tone, amount);
    }
    result = vec4(contrail(color, source), 1.0);
  }
  float beam = uBeam * exp(-max(0.0, abs(d) - gap * 0.2) / (gap * 0.7 + 30.0));
  float ring = uWave.y * exp(-pow((length(offset) - uWave.x) / 22.0, 2.0));
  vec3 glow = sunColor() * beam * 0.95 + vec3(ring * 0.5);
  float alpha = max(result.a, clamp(max(beam, ring), 0.0, 1.0));
  fragColor = vec4(min(result.rgb + glow, vec3(alpha)), alpha);
}
