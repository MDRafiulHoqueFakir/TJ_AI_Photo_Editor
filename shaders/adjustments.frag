#version 460 core
#include <flutter/runtime_effect.glsl>

// Real-time tonal + color adjustments. Runs on the GPU via Impeller, so the
// whole preview re-renders every frame as sliders drag (target 60fps).
//
// Uniform layout MUST match the float order set in GpuImageEngine.

precision highp float;

uniform vec2 uSize;        // output size in px
uniform sampler2D uTexture; // source image

uniform float uBrightness; // -1..1  (additive in linear-ish space)
uniform float uContrast;    // -1..1
uniform float uSaturation;  // -1..1
uniform float uExposure;    // -1..1  (stops, scaled)
uniform float uWarmth;      // -1..1  (cool<->warm)
uniform float uVignette;    // 0..1

out vec4 fragColor;

// Rec. 709 luma
const vec3 kLuma = vec3(0.2126, 0.7152, 0.0722);

vec3 applyContrast(vec3 c, float amt) {
  // pivot around mid-grey
  return (c - 0.5) * (1.0 + amt) + 0.5;
}

vec3 applySaturation(vec3 c, float amt) {
  float l = dot(c, kLuma);
  return mix(vec3(l), c, 1.0 + amt);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec3 c = texture(uTexture, uv).rgb;

  // Exposure (multiplicative, ~±2 stops) then brightness (additive).
  c *= pow(2.0, uExposure * 2.0);
  c += uBrightness * 0.5;

  c = applyContrast(c, uContrast);
  c = applySaturation(c, uSaturation);

  // Warmth: push R up / B down (or inverse) for white-balance feel.
  c.r += uWarmth * 0.10;
  c.b -= uWarmth * 0.10;

  // Vignette
  if (uVignette > 0.0) {
    vec2 d = uv - 0.5;
    float v = smoothstep(0.8, 0.2, dot(d, d) * 2.0);
    c *= mix(1.0, v, uVignette);
  }

  fragColor = vec4(clamp(c, 0.0, 1.0), 1.0);
}
