#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform float uDusk;
uniform vec2 uRest;
uniform vec2 uAlong;
uniform vec2 uHead;
uniform vec2 uImpact;
uniform float uLength;
uniform float uTime;
uniform float uThrust;
uniform float uPressure;
uniform float uReveal;
uniform float uForeground;
uniform float uHasCloud;
uniform sampler2D uSky;
uniform sampler2D uCloud;

out vec4 fragColor;

float hash12(vec2 p) {
  vec3 h = fract(vec3(p.xyx) * 0.1031);
  h += dot(h, h.yzx + 33.33);
  return fract((h.x + h.y) * h.z);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x),
             mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

float billows(vec2 p) {
  return noise(p) * 0.57 + noise(p * 2.1 + 7.3) * 0.29 + noise(p * 4.3 + 13.1) * 0.14;
}

float glow(float distance, float width) {
  float scaled = distance / max(width, 0.5);
  return exp(-scaled * scaled);
}

vec4 over(vec4 front, vec4 back) {
  return front + back * (1.0 - front.a);
}

vec3 cloudColor(float light, float depth) {
  vec3 shade = mix(vec3(0.43, 0.57, 0.80), vec3(0.28, 0.31, 0.53), uDusk);
  vec3 body = mix(vec3(0.81, 0.89, 0.99), vec3(0.66, 0.62, 0.83), uDusk);
  vec3 sun = mix(vec3(1.0, 0.98, 0.92), vec3(1.0, 0.82, 0.76), uDusk);
  vec3 cloud = mix(shade, body, smoothstep(0.13, 0.65, light));
  cloud = mix(cloud, sun, smoothstep(0.52, 0.92, light));
  return cloud + sun * (1.0 - smoothstep(0.0, 15.0, depth)) * 0.06;
}

vec4 paintedCloud(vec2 uv) {
  if (uHasCloud < 0.5 || uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
    return vec4(0);
  }
  vec4 cloud = texture(uCloud, uv);
  cloud.rgb *= mix(vec3(1.0), vec3(0.83, 0.75, 0.95), uDusk);
  return cloud;
}

vec4 cloudBank(vec2 local, float head, float impact, float clearing) {
  float outward = sign(local.y) * uPressure * uSize.x * 0.24;
  vec2 q = vec2(local.x - impact, local.y - outward);
  float texture = billows(q * 0.024 + vec2(uPressure, -uPressure));
  q.x += (texture - 0.5) * uPressure * 24.0;
  vec2 uv = vec2(q.y / (uSize.x * 1.9) + 0.5,
                 0.5 - q.x / (uSize.x * 0.95));
  vec4 cloud = paintedCloud(uv);
  float behind = smoothstep(-uLength * 0.2, uLength * 0.55, head - local.x);
  float gap = uPressure * uSize.x * 0.25 * behind;
  float channel = gap > 0.0 ? smoothstep(gap - 12.0, gap + 12.0, abs(local.y)) : 1.0;
  return cloud * channel * clearing;
}

vec4 rolledClouds(vec2 local, float impact, float clearing) {
  vec4 cloud = vec4(0);
  if (uPressure <= 0.0) {
    return cloud;
  }
  float lifetime = 1.0 - smoothstep(0.84, 1.0, uTime);
  for (int i = 0; i < 4; i++) {
    float index = float(i);
    float age = clamp((uPressure - index * 0.12) / 0.65, 0.0, 1.0);
    if (age <= 0.0) {
      continue;
    }
    float radius = uSize.x * (0.055 + age * 0.18);
    for (int j = 0; j < 2; j++) {
      float side = j == 0 ? -1.0 : 1.0;
      vec2 center = vec2(impact - index * uSize.x * 0.07 + age * 32.0,
                         side * (20.0 + age * uSize.x * 0.28 + index * 10.0));
      vec2 v = local - center;
      if (length(v) > radius * 1.25) {
        continue;
      }
      float turn = side * age * 5.5 + index;
      float c = cos(turn), s = sin(turn);
      vec2 rotated = mat2(c, -s, s, c) * v;
      float angle = atan(rotated.y, rotated.x) + 3.14159265;
      float spiral = radius * (0.15 + angle * 0.12);
      float width = radius * (0.3 - angle * 0.021);
      float texture = billows(rotated * 0.055 + index);
      float ribbon = glow(length(v) - spiral + (texture - 0.5) * 12.0, width);
      float taper = sin(angle * 0.5);
      float alpha = ribbon * taper * smoothstep(0.0, 0.12, age) * lifetime * 0.96 * clearing;
      vec2 uv = vec2(0.5 + rotated.x / (radius * 3.5),
                     0.5 + rotated.y / (radius * 4.0));
      vec4 painted = paintedCloud(uv);
      painted.rgb *= mix(0.82, 1.06, smoothstep(-0.4, 0.5, rotated.y / radius));
      cloud = over(painted * alpha, cloud);
    }
  }
  return cloud;
}

vec4 pressureWave(vec2 local, float impact, float clearing) {
  if (uPressure <= 0.0 || uPressure >= 1.0) {
    return vec4(0);
  }
  vec2 q = vec2((local.x - impact) * 0.62, local.y);
  float radius = uSize.x * (0.09 + uPressure * 0.85);
  float grain = billows(q * 0.038 - uPressure * 1.6);
  float shell = glow(length(q) - radius + (grain - 0.5) * 20.0,
                     7.0 + (1.0 - uPressure) * 12.0);
  float alpha = shell * sin(uPressure * 3.14159265) * (0.3 + grain * 0.2) * clearing;
  vec3 light = mix(vec3(0.96, 0.99, 1.0), vec3(1.0, 0.84, 0.85), uDusk);
  return vec4(light * alpha, alpha);
}

vec4 exhaust(vec2 local, float head) {
  if (uThrust <= 0.0 || head < 1.0 || local.x < -uLength || local.x > head) {
    return vec4(0);
  }
  float age = clamp((head - local.x) / max(head, 1.0), 0.0, 1.0);
  float width = uLength * (0.05 + age * 0.24);
  float grain = billows(vec2(local.x * 0.04 - uTime * 4.0, local.y * 0.06));
  float smoke = glow(local.y + (grain - 0.5) * width, width * (0.6 + grain));
  float ends = smoothstep(-uLength, 0.0, local.x) * smoothstep(0.0, uLength * 0.4, head - local.x);
  float alpha = smoke * ends * uThrust * (1.0 - smoothstep(0.78, 0.98, uTime)) * 0.66;
  vec3 light = mix(vec3(0.93, 0.97, 1.0), vec3(0.84, 0.83, 0.97), uDusk);
  return vec4(light * alpha, alpha);
}

void main() {
  vec2 point = FlutterFragCoord().xy;
  vec2 across = vec2(-uAlong.y, uAlong.x);
  vec2 offset = point - uRest;
  vec2 local = vec2(dot(offset, uAlong), dot(offset, across));
  float head = dot(uHead - uRest, uAlong);
  float impact = dot(uImpact - uRest, uAlong);
  vec2 blast = vec2((local.x - impact) * 0.92, local.y);
  float radius = uReveal * (length(uSize) * 1.35 + uLength);
  float grain = billows(blast * 0.021 - uPressure * 0.9);
  float clearing = uReveal <= 0.0 ? 1.0 : smoothstep(radius - 24.0, radius + 24.0,
                         length(blast) + (grain - 0.5) * 65.0);
  vec4 result = vec4(0);
  if (uForeground < 0.5) {
    vec2 flow = across * sign(local.y) * uPressure * uReveal * 12.0;
    vec2 source = mix(point - flow, uSize * 0.5, uReveal * 0.06);
    vec3 sky = texture(uSky, clamp(source / uSize, 0.0, 1.0)).rgb;
    result = vec4(sky * clearing, clearing);
    vec4 smoke = exhaust(local, head) * clearing;
    result = over(smoke, result);
    float swept = uReveal > 0.0 ? glow(length(blast) - radius + (grain - 0.5) * 65.0, 30.0) : 0.0;
    float alpha = swept * (0.35 + grain * 0.35) * (1.0 - uReveal);
    vec3 vapor = cloudColor(0.6 + grain * 0.4, 5.0);
    result = over(vec4(vapor * alpha, alpha), result);
  } else {
    result = cloudBank(local, head, impact, clearing);
    result = over(rolledClouds(local, impact, clearing), result);
    result = over(pressureWave(local, impact, clearing), result);
  }
  fragColor = result;
}
