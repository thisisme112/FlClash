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
uniform vec2 uBend;
uniform float uRise;
uniform float uFlight;
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

float waveExtent() {
  return length(uSize) * 0.95;
}

float waveRadius() {
  return waveExtent() * (1.0 - exp(-1.8 * uPressure));
}

float arrivalAge(float radius) {
  float arrival = -log(1.0 - min(radius / waveExtent(), 0.995)) / 1.8;
  return max(0.0, uPressure - arrival);
}

vec2 airFlow(vec2 blast) {
  float radius = length(blast);
  float age = arrivalAge(radius);
  float impulse = (1.0 - exp(-5.0 * age)) * exp(-radius / waveExtent());
  vec2 radial = blast / max(radius, 1.0);
  vec2 curl = vec2(-radial.y, radial.x) * sin(radius * 0.034 - age * 8.0);
  float travel = min(radius * 0.65, min(uSize.x, uSize.y) * 0.46 * impulse);
  return (radial + curl * 0.16) * travel;
}

vec4 cloudBank(vec2 blast, float clearing) {
  vec2 q = blast - airFlow(blast);
  float texture = billows(q * 0.024 + vec2(uPressure, -uPressure));
  float age = arrivalAge(length(blast));
  q += vec2(texture - 0.5, noise(q * 0.018) - 0.5) * age * 25.0;
  float scale = min(uSize.x, uSize.y);
  vec2 uv = vec2(q.y / (uSize.x * 1.9) + 0.5, 0.5 - q.x / (scale * 0.95));
  vec4 cloud = paintedCloud(uv);
  float opening = scale * 0.4 * (1.0 - exp(-5.0 * uPressure));
  float edge = length(blast * vec2(0.9, 1.0)) + (texture - 0.5) * 18.0;
  float channel = uPressure > 0.0 ? smoothstep(opening - 10.0, opening + 8.0, edge) : 1.0;
  return cloud * channel * clearing;
}

vec4 rolledClouds(vec2 blast, float clearing) {
  vec4 cloud = vec4(0);
  float scale = min(uSize.x, uSize.y);
  for (int i = 0; i < 8; i++) {
    float index = float(i);
    float age = max(0.0, uPressure - index * 0.018);
    if (age <= 0.0) {
      continue;
    }
    float angle = index * 0.78539816 + 0.2;
    vec2 radial = vec2(cos(angle), sin(angle));
    float spread = scale * (0.08 + 0.48 * (1.0 - exp(-3.0 * age)));
    vec2 center = radial * spread;
    float radius = scale * (0.035 + 0.13 * (1.0 - exp(-5.0 * age)));
    vec2 v = blast - center;
    if (length(v) > radius * 1.3) {
      continue;
    }
    float side = sin(angle) < 0.0 ? -1.0 : 1.0;
    float turn = angle + side * (1.0 - exp(-2.5 * age)) * 4.0;
    float c = cos(turn), sn = sin(turn);
    vec2 rotated = mat2(c, -sn, sn, c) * v;
    float spiralAngle = atan(rotated.y, rotated.x) + 3.14159265;
    float spiral = radius * (0.15 + spiralAngle * 0.12);
    float width = radius * (0.3 - spiralAngle * 0.021);
    float texture = billows(rotated * 0.055 + index);
    float ribbon = glow(length(v) - spiral + (texture - 0.5) * 10.0, width);
    float alpha = ribbon * sin(spiralAngle * 0.5) * smoothstep(0.0, 0.1, age)
                  * exp(-age * 1.1) * 0.86 * clearing;
    vec2 uv = vec2(0.5 + rotated.x / (radius * 3.5), 0.5 + rotated.y / (radius * 4.0));
    vec4 painted = paintedCloud(uv);
    painted.rgb *= mix(0.82, 1.06, smoothstep(-0.4, 0.5, rotated.y / radius));
    cloud = over(painted * alpha, cloud);
  }
  return cloud;
}

vec4 pressureWave(vec2 blast, float clearing) {
  if (uPressure <= 0.0) {
    return vec4(0);
  }
  float grain = billows(blast * 0.038 - uPressure * 1.6);
  float shell = glow(length(blast) - waveRadius() + (grain - 0.5) * 16.0,
                     8.0 + uPressure * 17.0);
  float alpha = shell * smoothstep(0.0, 0.06, uPressure) * exp(-2.3 * uPressure)
                * (0.42 + grain * 0.25) * clearing;
  vec3 light = mix(vec3(0.96, 0.99, 1.0), vec3(1.0, 0.84, 0.85), uDusk);
  return vec4(light * alpha, alpha);
}

vec4 exhaust(vec2 point) {
  float height = uRest.y - point.y;
  if (uThrust <= 0.0 || height < 0.0 || point.y < uHead.y || uFlight <= 0.0) {
    return vec4(0);
  }
  float t = sqrt(height / uRise);
  float age = max(0.0, uFlight - t);
  float x = uRest.x + (uBend.x + uBend.y * t) * t * t;
  float slope = (uBend.x + 1.5 * uBend.y * t) / uRise;
  float distance = (point.x - x) / sqrt(1.0 + slope * slope);
  float width = uLength * (0.04 + age * 0.34);
  float grain = billows(vec2(height * 0.04 - age * 3.0, distance * 0.06));
  float smoke = glow(distance + (grain - 0.5) * width, width * (0.6 + grain));
  float ends = smoothstep(0.0, uLength, height) * smoothstep(0.0, 0.025, age);
  float alpha = smoke * ends * uThrust * (1.0 - smoothstep(0.8, 1.0, uTime)) * 0.7;
  vec3 light = mix(vec3(0.93, 0.97, 1.0), vec3(0.84, 0.83, 0.97), uDusk);
  return vec4(light * alpha, alpha);
}

void main() {
  vec2 point = FlutterFragCoord().xy;
  vec2 across = vec2(-uAlong.y, uAlong.x);
  vec2 offset = point - uImpact;
  vec2 blast = vec2(dot(offset, uAlong), dot(offset, across));
  float radius = uReveal * (length(uSize) * 1.35 + uLength);
  float grain = billows(blast * 0.021 - uPressure * 0.9);
  float clearing = uReveal <= 0.0 ? 1.0 : smoothstep(radius - 24.0, radius + 24.0,
                         length(blast) + (grain - 0.5) * 65.0);
  vec2 flow = airFlow(blast);
  vec2 screenFlow = uAlong * flow.x + across * flow.y;
  vec4 result = vec4(0);
  if (uForeground < 0.5) {
    float parallax = uFlight * uFlight * (1.0 - uReveal);
    vec2 source = mix(point - screenFlow * 0.24, uSize * 0.5, parallax * 0.045);
    source += uAlong * parallax * 9.0;
    vec3 sky = texture(uSky, clamp(source / uSize, 0.0, 1.0)).rgb;
    float light = glow(length(blast) - waveRadius(), 50.0) * uPressure * exp(-3.0 * uPressure);
    sky += vec3(0.12, 0.14, 0.17) * light;
    result = vec4(sky * clearing, clearing);
    result = over(exhaust(point - screenFlow * 0.12) * clearing, result);
    float swept = uReveal > 0.0 ? glow(length(blast) - radius + (grain - 0.5) * 65.0, 30.0) : 0.0;
    float alpha = swept * (0.35 + grain * 0.35) * (1.0 - uReveal);
    vec3 vapor = cloudColor(0.6 + grain * 0.4, 5.0);
    result = over(vec4(vapor * alpha, alpha), result);
  } else {
    result = cloudBank(blast, clearing);
    result = over(rolledClouds(blast, clearing), result);
    result = over(pressureWave(blast, clearing), result);
  }
  fragColor = result;
}
