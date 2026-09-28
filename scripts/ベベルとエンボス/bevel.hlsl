Texture2D<float4> tex0 : register(t0);
Texture2D<float4> tex1 : register(t1);
Texture2D<float4> tex2 : register(t2);

cbuffer Params : register(b0) {
  float threshold;
  float bevelWidth;
  float jumpStep;
  float shape;
  float lightX;
  float lightY;
  float strength;
  float outputMode;
  float red;
  float green;
  float blue;
  float shadow;
  float opacity;
};

// Two bytes per component, relative to the current pixel, at 1/64 pixel precision.
// Values survive both UNORM8 and float16 image buffers; zero means no seed.
// The supported bevel width (<=150) keeps offsets inside the signed 512-pixel range.
float4 packOffset(float2 offset) {
  uint2 value = (uint2)round(offset * 64.0 + 32768.0);
  return float4(value.x >> 8, value.x & 255, value.y >> 8, value.y & 255) / 255.0;
}

float2 unpackOffset(float4 value) {
  float4 bytes = round(value * 255.0);
  return (float2(bytes.x * 256.0 + bytes.y, bytes.z * 256.0 + bytes.w) - 32768.0) / 64.0;
}

bool validSeed(float4 value) { return any(value != 0.0); }

float4 bevel_seed(float4 position : SV_Position) : SV_Target {
  int2 p = int2(position.xy);
  float a = tex0.Load(int3(p, 0)).a;
  float left = tex0.Load(int3(p + int2(-1, 0), 0)).a;
  float right = tex0.Load(int3(p + int2(1, 0), 0)).a;
  float up = tex0.Load(int3(p + int2(0, -1), 0)).a;
  float down = tex0.Load(int3(p + int2(0, 1), 0)).a;
  if (a <= threshold || min(min(left, right), min(up, down)) > threshold) return 0;

  float dx = 0, dy = 0;
  if (right <= threshold)
    dx = (a - threshold) / (a - right);
  else if (left <= threshold)
    dx = -(a - threshold) / (a - left);
  if (down <= threshold)
    dy = (a - threshold) / (a - down);
  else if (up <= threshold)
    dy = -(a - threshold) / (a - up);
  // Same subpixel correction as the source, without division by zero on axial edges.
  float sum = abs(dx) + abs(dy);
  return packOffset(sum > 0 ? float2(dx * abs(dx), dy * abs(dy)) / sum : float2(0, 0));
}

float4 bevel_jump(float4 position : SV_Position) : SV_Target {
  int2 p = int2(position.xy);
  uint w, h;
  tex0.GetDimensions(w, h);
  float bestDistance = (bevelWidth + 2.0) * (bevelWidth + 2.0);
  float4 best = 0;
  [unroll] for (int y = -1; y <= 1; y++) {
    [unroll] for (int x = -1; x <= 1; x++) {
      int2 delta = int2(x, y) * (int)jumpStep;
      int2 q = p + delta;
      if (any(q < 0) || q.x >= (int)w || q.y >= (int)h) continue;
      float4 candidate = tex0.Load(int3(q, 0));
      if (!validSeed(candidate)) continue;
      float2 offset = unpackOffset(candidate) + delta;
      float distanceSquared = dot(offset, offset);
      if (distanceSquared < bestDistance) {
        bestDistance = distanceSquared;
        best = packOffset(offset);
      }
    }
  }
  return best;
}

float signedDistance(int2 p) {
  float4 seed = tex0.Load(int3(p, 0));
  float distance = validSeed(seed) ? length(unpackOffset(seed)) : bevelWidth + 2.0;
  return tex1.Load(int3(p, 0)).a > threshold ? -distance : distance;
}

float4 bevel_shade(float4 position : SV_Position) : SV_Target {
  int2 p = int2(position.xy);
  if (!validSeed(tex0.Load(int3(p, 0)))) return 0;
  float distance = signedDistance(p);
  float2 gradient = float2(signedDistance(p + int2(1, 0)) - signedDistance(p - int2(1, 0)),
                           signedDistance(p + int2(0, 1)) - signedDistance(p - int2(0, 1)));
  // Central differences span two pixels; preserve cancellation where opposing bevels meet.
  float gray = dot(gradient / max(length(gradient), 2.0), float2(lightX, lightY)) * strength;
  return float4(max(gray, 0), max(-gray, 0), saturate(bevelWidth - abs(distance)), distance < 0 ? 1 : 0);
}

float4 bevel_layer(float4 position : SV_Position) : SV_Target {
  int2 p = int2(position.xy);
  float4 field = tex0.Load(int3(p, 0));
  float originalAlpha = tex1.Load(int3(p, 0)).a;
  float gray = field.r - field.g;
  if (shape == 3) gray *= originalAlpha * 2.0 - 1.0;
  float alpha = max(shadow > 0 ? -gray : gray, 0);
  if (outputMode == 0) {
    if (shape == 1)
      alpha *= field.b;
    else if (shape >= 2)
      alpha *= field.b > 0 ? (field.a > 0 ? 1 : field.b) : 0;
  } else {
    alpha *= field.b;
    if (shape == 0) alpha = min(alpha, 1.0 - originalAlpha);
    if (shape == 1) alpha = min(alpha, originalAlpha);
  }
  alpha *= opacity;
  // AviUtl2 image textures use premultiplied alpha.
  return float4(float3(red, green, blue) * alpha, alpha);
}

float4 bevel_base(float4 position : SV_Position) : SV_Target {
  float4 original = tex0.Load(int3(int2(position.xy), 0));
  float3 background = float3(red, green, blue);
  if (shape == 0) return float4(background, 1);
  if (shape == 1) return float4(original.a > 0 ? original.rgb / original.a : float3(0, 0, 0), 1);
  return float4(original.rgb + background * (1.0 - original.a), 1);
}

float4 bevel_finish(float4 position : SV_Position) : SV_Target {
  int2 p = int2(position.xy);
  float3 color = tex0.Load(int3(p, 0)).rgb;
  float4 original = tex1.Load(int3(p, 0));
  float band = tex2.Load(int3(p, 0)).b;
  float alpha = shape == 1 ? original.a : max(original.a, band);
  if (shape == 0) color = original.rgb + color * (1.0 - original.a);
  return float4(color * alpha, alpha);
}
