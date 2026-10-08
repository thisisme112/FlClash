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
uniform float uBand;
uniform float uRadius;
uniform vec2 uTrailA;
uniform vec2 uTrailC;
uniform vec2 uTrailB;
uniform float uFlown;
uniform float uTrailWidth;
uniform float uLaunch;
uniform float uBeam;
uniform vec2 uWave;
uniform float uZoom;
uniform vec2 uShake;
uniform float uHasCloud;
uniform sampler2D uSky;
uniform sampler2D uCloud;

out vec4 fragColor;

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
  return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
             mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
  float value = 0.0;
  float amplitude = 0.5;
  mat2 turn = mat2(1.6, 1.2, -1.2, 1.6);
  for (int i = 0; i < 4; i++) {
    value += amplitude * vnoise(p);
    p = turn * p;
    amplitude *= 0.5;
  }
  return value;
}

vec3 pal(vec3 noon, vec3 dusk) {
  return mix(noon, dusk, uDusk);
}

vec3 sunColor() { return pal(vec3(1.0, 0.984, 0.918), vec3(1.0, 0.886, 0.722)); }
vec3 rimColor() { return pal(vec3(1.0, 0.906, 0.722), vec3(1.0, 0.69, 0.44)); }

vec3 cloudTone(float lit) {
  vec3 shade = pal(vec3(0.55, 0.64, 0.84), vec3(0.42, 0.37, 0.62));
  vec3 body = pal(vec3(0.93, 0.95, 0.99), vec3(0.95, 0.78, 0.76));
  vec3 light = pal(vec3(1.0), vec3(1.0, 0.91, 0.84));
  vec3 tone = mix(shade, body, smoothstep(0.2, 0.7, lit));
  return mix(tone, light, smoothstep(0.72, 1.0, lit));
}

// How far the sky has torn at s along the wake, 0 to about 1. The tear outruns
// the screen almost at once, so no pointed ends are seen closing it in.
float openAt(float s) {
  float front = uHalfSpan * (0.6 + 8.0 * uParting);
  float x = s / front;
  float width = uParting * uParting * (3.0 - 2.0 * uParting);
  return width * sqrt(max(0.0, 1.0 - x * x));
}

// Where each half's rolling edge has got to, measured out from the wake. The
// ends roll faster, so the rolls curve away from the gap, ")(".
float rollFront(float s, float open) {
  float reach = min(abs(s) / uHalfSpan, 1.0);
  return open * uMaxGap * (1.0 + 1.6 * reach * reach);
}

// Streaks of air rushing out from the wake to both sides, brightest at their
// heads; uWave holds how far they have travelled and how strong they are.
float airRush(float s, float d, float side) {
  if (uWave.y <= 0.0) {
    return 0.0;
  }
  float lane = smoothstep(0.72, 0.95, vnoise(vec2(s * 0.22, side * 3.0)));
  float head = abs(d) - uWave.x * (0.55 + 0.7 * vnoise(vec2(s * 0.015, side * 7.0)));
  float tail = smoothstep(-170.0, 0.0, head) * exp(-max(head, 0.0) * max(head, 0.0) / 40.0);
  return lane * tail * tail * uWave.y * 0.6;
}

// The painted cloud bank laid along a torn edge, its billowing top toward the
// gap. The texture repeats mirrored along the wake so no seam shows.
vec4 edgeCloud(float s, float depth, float side) {
  float u = s * 0.22 / uBand + side * 0.37;
  u = abs(fract(u * 0.5) * 2.0 - 1.0);
  vec4 cloud = texture(uCloud, vec2(u, 0.21 + depth * 0.33));
  cloud.rgb *= pal(vec3(1.0), vec3(0.83, 0.75, 0.95));
  return cloud;
}

vec4 noiseCloud(float s, float fromEdge, float side) {
  vec2 grain = vec2(s, fromEdge) * 0.012 + side * 3.1;
  float lumps = vnoise(grain) * 0.6 + vnoise(grain * 2.3) * 0.25 + fbm(grain * 6.0) * 0.15;
  float billow = 1.0 - fromEdge / uBand + (lumps - 0.45) * 1.3;
  float amount = smoothstep(0.35, 0.5, billow);
  return vec4(cloudTone(1.0 - fromEdge / uBand) * amount, amount);
}

vec2 flightAt(float t) {
  float m = 1.0 - t;
  return m * m * uTrailA + 2.0 * m * t * uTrailC + t * t * uTrailB;
}

// The rocket's contrail along its arc, wider where it passed longer ago, and
// the smoke left on the pad; both are carried apart with the sky.
vec3 contrail(vec3 color, vec2 q) {
  if (uLaunch <= 0.0) {
    return color;
  }
  float nearest = 1e9;
  float at = 0.0;
  float stride = uFlown / 12.0;
  for (int i = 0; i <= 12; i++) {
    float t = stride * float(i);
    float d = length(q - flightAt(t));
    if (d < nearest) {
      nearest = d;
      at = t;
    }
  }
  for (int i = 0; i < 3; i++) {
    stride *= 0.5;
    float before = clamp(at - stride, 0.0, uFlown);
    float after = clamp(at + stride, 0.0, uFlown);
    float d0 = length(q - flightAt(before));
    float d1 = length(q - flightAt(after));
    if (d0 < nearest) {
      nearest = d0;
      at = before;
    }
    if (d1 < nearest) {
      nearest = d1;
      at = after;
    }
  }
  float width = uTrailWidth * (0.45 + 3.4 * (uFlown - at));
  float padRadius = uTrailWidth * 2.6 * uLaunch;
  vec2 pad = uTrailA + vec2(0.0, uTrailWidth * 0.6);
  bool nearTrail = uFlown > 0.0 && nearest < width * 1.5;
  if (!nearTrail && length(q - pad) > padRadius * 1.5) {
    return color;
  }
  float grain = fbm(q * 0.03 + 11.0);
  float trail = uFlown > 0.0
      ? 1.0 - smoothstep(width * 0.5, width, nearest + (grain - 0.5) * width * 0.9)
      : 0.0;
  float smoke = (1.0 - smoothstep(padRadius * 0.45, padRadius,
      length(q - pad) + (grain - 0.5) * uTrailWidth)) * uLaunch;
  float amount = max(trail * 0.95, smoke);
  if (amount <= 0.0) {
    return color;
  }
  vec2 normal = (q - flightAt(at)) / max(width, 1.0);
  float lit = clamp(dot(normal, kLight) * 0.6 + 0.55 + (grain - 0.5) * 0.6, 0.0, 1.0);
  return mix(color, cloudTone(lit), amount);
}

vec3 skyAt(vec2 point) {
  vec2 camera = uSize * 0.5 + (point - uSize * 0.5) / uZoom + uShake;
  return texture(uSky, clamp(camera / uSize, 0.0, 1.0)).rgb;
}

// The sky sheet at s along the wake and x out from its torn edge: the painted
// sky, the cloud bank lining the edge, and the contrail.
vec3 sheetAt(float s, float x, float side, float open) {
  vec2 point = uSeam + uAlong * s + vec2(-uAlong.y, uAlong.x) * side * x;
  vec3 color = skyAt(point);
  if (open > 0.0 && x < uBand) {
    float depth = x / uBand;
    float shown = min(1.0, open * 4.0) * (1.0 - smoothstep(0.7, 1.0, depth));
    vec4 cloud = uHasCloud > 0.5 ? edgeCloud(s, depth, side) : noiseCloud(s, x, side);
    cloud.rgb += rimColor() * (1.0 - smoothstep(0.0, 0.3, depth)) * 0.3 * cloud.a;
    color = cloud.rgb * shown + color * (1.0 - cloud.a * shown);
  }
  return contrail(color, point);
}

void main() {
  const float tau = 6.2831853;
  vec2 p = FlutterFragCoord().xy;
  vec2 across = vec2(-uAlong.y, uAlong.x);
  vec2 offset = p - uSeam;
  float s = dot(offset, uAlong);
  float d = dot(offset, across);
  float side = d < 0.0 ? -1.0 : 1.0;
  float x = abs(d);
  float open = openAt(s);
  float front = rollFront(s, open);
  vec4 result = vec4(0.0);
  float shadow = 0.0;
  float inGap = 0.0;
  if (front <= 0.5) {
    result = vec4(sheetAt(s, x, side, open), 1.0);
  } else {
    // Each half rolls up from its torn edge onto a tube that lifts toward the
    // viewer and travels outward, thickening as it gathers the sheet. A point
    // on the tube at angle a sits over x = front - radius * sin(a) and came
    // from front - radius * a on the flat sheet.
    float radius = uRadius + front * 0.07;
    float ragged = (fbm(vec2(s * 0.03, side * 5.0)) - 0.5) * 24.0 * min(1.0, open * 5.0);
    float sheet = -1e6;
    float facing = 0.0;
    float underside = 0.0;
    if (abs(x - front) <= radius) {
      float a = asin(clamp((front - x) / radius, -1.0, 1.0));
      float top = 3.14159265 - a;
      float turns = floor((front / radius - top) / tau);
      if (turns >= 0.0) {
        float angle = top + turns * tau;
        sheet = front - radius * angle;
        facing = -cos(angle);
      } else {
        float low = a < 0.0 ? a + tau : a;
        if (low * radius <= front) {
          sheet = front - radius * low;
          facing = cos(low);
          underside = 1.0;
        }
      }
    }
    if (sheet > ragged) {
      vec3 color = sheetAt(s, sheet, side, open);
      color = mix(color, cloudTone(0.85), underside * 0.55);
      float light = 0.62 + 0.38 * facing;
      result = vec4(color * light + vec3(pow(max(facing, 0.0), 10.0) * 0.12), 1.0);
    } else if (x > front) {
      float contact = (1.0 - smoothstep(front + radius, front + radius * 1.9, x)) * 0.22;
      result = vec4(sheetAt(s, x, side, open) * (1.0 - contact), 1.0);
    } else {
      inGap = 1.0;
      shadow = (1.0 - smoothstep(0.0, radius * 1.6, front - radius - x)) * 0.34 *
          min(1.0, open * 4.0);
    }
    // Cloud billows round the roll's outline, so it reads as a rolling cloud
    // rather than a tube.
    float rim = abs(x - front) / radius;
    if (rim < 1.5) {
      float fringe = clamp((1.45 - rim) / 0.75, 0.0, 1.0);
      vec4 cloud = uHasCloud > 0.5
          ? edgeCloud(s * 0.7 + front * 0.4, fringe * 0.9, side)
          : noiseCloud(s, (1.0 - fringe) * uBand, side);
      float amount = cloud.a * min(1.0, open * 4.0) * (1.0 - smoothstep(0.85, 1.0, fringe));
      vec3 lit = cloud.rgb + rimColor() * 0.18 * cloud.a;
      result = vec4(lit * amount + result.rgb * (1.0 - amount), max(result.a, amount));
      inGap *= 1.0 - amount;
    }
  }
  float beam = uBeam * 0.6 * exp(-x / (front * 0.35 + 18.0));
  float rush = airRush(s, d, side) * inGap;
  vec3 glow = sunColor() * beam * 0.95 * inGap + vec3(rush * 0.85);
  float alpha = max(result.a, clamp(shadow + max(beam * inGap, rush), 0.0, 1.0));
  fragColor = vec4(min(result.rgb + glow, vec3(alpha)), alpha);
}
