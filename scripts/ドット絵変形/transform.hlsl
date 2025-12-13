Texture2D tex0 : register(t0);
SamplerState sampler0 : register(s0);

cbuffer cb0 : register(b0) {
  float min_x;
  float min_y;
  float base_w;
  float base_h;
  float center_x;
  float center_y;
  float scale_x;
  float scale_y;
  float angle;
};

float2 rotate_point(float x, float y, float angle) {
  float cos_a = cos(angle);
  float sin_a = sin(angle);
  float rx = cos_a * x - sin_a * y;
  float ry = sin_a * x + cos_a * y;
  return float2(rx, ry);
}

float4 transform(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
  float new_x = min_x + pos.x;
  float new_y = min_y + pos.y;

  float rel_x = new_x - center_x;
  float rel_y = new_y - center_y;

  float2 rotated = rotate_point(rel_x, rel_y, -angle);
  float2 scaled = float2(rotated.x / scale_x, rotated.y / scale_y);

  float sample_x = scaled.x + center_x;
  float sample_y = scaled.y + center_y;

  if (sample_x < 0 || sample_x >= base_w || sample_y < 0 || sample_y >= base_h) {
    // NOTE: sampler = "dot"は範囲外を透明にするという仕様になっているけど一応明示的に透明にする
    return float4(0, 0, 0, 0);
  } else {
    float2 sample_uv = float2(sample_x / base_w, sample_y / base_h);
    return tex0.Sample(sampler0, sample_uv);
  }
}

// vim: set ft=hlsl ts=4 sts=4 sw=4 noet:
