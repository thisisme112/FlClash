#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform float uDusk;

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

float mass(vec2 q, vec2 center, float radius) {
  return 1.0 - length((q - center) / vec2(radius * 1.2, radius));
}

// Blends two masses so they merge into one cloud instead of meeting at a crease.
float merge(float a, float b) {
  float k = 0.12;
  float h = clamp(0.5 + 0.5 * (a - b) / k, 0.0, 1.0);
  return mix(b, a, h) + k * h * (1.0 - h);
}

// Where clouds stand, in screen-width units: a cumulonimbus piled from round
// masses on the start side, a bank along the foot and a few small clouds aloft.
float cloudShape(vec2 q, float tall) {
  float shape = -1.0;
  for (int i = 0; i < 9; i++) {
    float k = float(i);
    vec2 center = vec2(
      0.2 + (hash12(vec2(k, 1.0)) - 0.5) * 0.26,
      tall - 0.06 - k * 0.088 - hash12(vec2(k, 4.0)) * 0.03
    );
    shape = merge(shape, mass(q, center, 0.25 - k * 0.019));
  }
  for (int i = 0; i < 9; i++) {
    float k = float(i);
    vec2 center = vec2(-0.05 + k * 0.14, tall - 0.02 - hash12(vec2(k, 2.0)) * 0.05);
    shape = merge(shape, mass(q, center, 0.12 + hash12(vec2(k, 3.0)) * 0.06));
  }
  for (int i = 0; i < 4; i++) {
    float k = float(i);
    float lift = hash12(vec2(k, 5.0));
    shape = merge(shape, mass(q, vec2(0.6 + k * 0.06, tall * 0.4 - lift * 0.035), 0.055));
    shape = merge(shape, mass(q, vec2(0.22 + k * 0.045, tall * 0.23 - lift * 0.02), 0.038));
    shape = merge(shape, mass(q, vec2(0.84 + k * 0.05, tall * 0.56 - lift * 0.03), 0.045));
  }
  return shape;
}

float cloudDensity(vec2 q, float tall) {
  vec2 warp = vec2(fbm3(q * 2.0), fbm3(q * 2.0 + 7.1)) - 0.5;
  vec2 at = q + warp * 0.05;
  float billow = vnoise(at * 7.0) * 0.45 + vnoise(at * 15.0) * 0.3 + fbm(at * 30.0) * 0.25;
  return cloudShape(at, tall) + (billow - 0.5) * 0.55;
}

float hexagon(vec2 v) {
  v = abs(v);
  return max(v.x * 0.866 + v.y * 0.5, v.y);
}

vec3 flare(vec2 p, vec2 sun, vec2 aim, float along, float radius, vec3 tint, float strength) {
  vec2 center = sun + (aim - sun) * along;
  float inside = 1.0 - smoothstep(radius * 0.8, radius, hexagon(p - center));
  return tint * inside * strength;
}

void main() {
  vec2 p = fragCoord();
  vec2 uv = p / uSize;
  float w = uSize.x;
  vec3 g0 = pal(vec3(0.043, 0.227, 0.62), vec3(0.078, 0.102, 0.306));
  vec3 g1 = pal(vec3(0.118, 0.435, 0.851), vec3(0.231, 0.235, 0.561));
  vec3 g2 = pal(vec3(0.373, 0.714, 0.949), vec3(0.69, 0.384, 0.561));
  vec3 g3 = pal(vec3(0.831, 0.945, 1.0), vec3(1.0, 0.667, 0.447));
  vec3 color = uv.y < 0.38 ? mix(g0, g1, uv.y / 0.38)
      : uv.y < 0.72 ? mix(g1, g2, (uv.y - 0.38) / 0.34)
      : mix(g2, g3, (uv.y - 0.72) / 0.28);

  vec2 sun = vec2(0.86, 0.07) * uSize;
  vec2 fromSun = (p - sun) / w;
  float sunDistance = length(fromSun);
  vec3 sunlight = sunColor();
  float angle = atan(fromSun.y, fromSun.x);
  color += sunlight * smoothstep(0.5, 0.9, vnoise(vec2(angle * 10.0, 3.7))) *
      exp(-sunDistance * 1.6) * 0.16;

  float wisp = smoothstep(0.52, 0.82, fbm(vec2(uv.x * 2.5 + uv.y * 1.5, uv.y * 26.0))) *
      (1.0 - smoothstep(0.08, 0.36, uv.y));
  color = mix(color, cloudLight(), wisp * 0.45);

  vec2 trailFrom = vec2(-0.05, 0.34) * uSize;
  vec2 trailTo = vec2(0.58, 0.16) * uSize;
  vec2 trail = trailTo - trailFrom;
  float along = clamp(dot(p - trailFrom, trail) / dot(trail, trail), 0.0, 1.0);
  float trailDistance = length(p - trailFrom - trail * along);
  color += vec3(along * (exp(-trailDistance / 1.1) * 0.85 + exp(-trailDistance / 4.0) * 0.2));

  vec2 q = p / w;
  float tall = uSize.y / w;
  float density = cloudDensity(q, tall);
  float cover = smoothstep(0.0, 0.035, density);
  if (cover > 0.0) {
    float toward = cloudDensity(q + kLight * 0.02, tall);
    float lit = clamp((density - toward) * 7.0 + 0.45, 0.0, 1.0);
    float thick = smoothstep(0.05, 0.6, density);
    vec3 shade = mix(shadeTop(), shadeBottom(), clamp(uv.y * 1.1 - 0.05, 0.0, 1.0));
    vec3 cloud = mix(shade, cloudBody(), smoothstep(0.25, 0.75, lit) * (1.0 - thick * 0.45));
    cloud = mix(cloud, cloudLight(), smoothstep(0.65, 0.95, lit));
    float edge = 1.0 - smoothstep(0.0, 0.08, density);
    cloud = mix(cloud, rimColor() + 0.1, edge * smoothstep(0.5, 0.9, lit) * 0.7);
    cloud += sunlight * exp(-sunDistance * 3.0) * 0.25;
    color = mix(color, cloud, cover);
  }

  color += sunlight * (exp(-sunDistance * 10.0) * 0.9 + exp(-sunDistance * 3.0) * 0.3);
  color = mix(color, sunlight, smoothstep(0.045, 0.03, sunDistance));
  color += vec3(exp(-abs(p.y - sun.y) / (w * 0.004)) * exp(-abs(fromSun.x) * 2.2) * 0.55);
  vec2 aim = vec2(0.42, 0.5) * uSize;
  color += flare(p, sun, aim, 0.35, 0.035 * w, vec3(0.67, 0.9, 1.0), 0.22);
  color += flare(p, sun, aim, 0.55, 0.06 * w, vec3(0.75, 1.0, 0.82), 0.12);
  color += flare(p, sun, aim, 0.8, 0.02 * w, vec3(1.0, 0.78, 0.94), 0.25);
  color += flare(p, sun, aim, 1.15, 0.09 * w, vec3(0.63, 0.78, 1.0), 0.1);
  color += flare(p, sun, aim, 1.4, 0.04 * w, vec3(1.0, 0.94, 0.75), 0.18);
  fragColor = vec4(min(color, vec3(1.0)), 1.0);
}
