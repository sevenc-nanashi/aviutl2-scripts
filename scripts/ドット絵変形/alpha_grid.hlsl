Texture2D tex0 : register(t0);
SamplerState sampler0 : register(s0);
cbuffer cb0 : register(b0) { float size; };

float4 alpha_grid(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
  float checker = fmod(floor(pos.x / size) + floor(pos.y / size), 2.0);

  if (checker < 1.0) {
    return float4(0.25, 0.25, 0.25, 1);
  } else {
    return float4(0, 0, 0, 1);
  }
}

// vim: set ft=hlsl ts=4 sts=4 sw=4 noet:
