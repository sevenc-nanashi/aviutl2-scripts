Texture2D<float4> input0 : register(t0);
Texture2D<float4> input1 : register(t1);
Texture2D<float4> original : register(t2);
RWTexture2D<float4> output0 : register(u0);
cbuffer Params : register(b0) {
  float strength;
  float threshold;
  float exponent;
  float padding;
  float red;
  float green;
  float blue;
  float useColor;
  float radius;
  float vertical;
  float firstPass;
  float isFilter;
};

float3 ToYC(float3 rgb) {
  float y = dot(rgb, float3(0.299, 0.587, 0.114));
  return float3(y, (rgb.b - y) / 1.772, (rgb.r - y) / 1.402);
}
float3 ToRGB(float3 yc) {
  return float3(yc.x + 1.402 * yc.z, yc.x - 0.344136 * yc.y - 0.714136 * yc.z, yc.x + 1.772 * yc.y);
}

// shortcut: YC and intermediate storage use half precision; use packed buffers if bit-exact compatibility is needed.
// Store exponential luminance in logarithmic form to avoid overflowing RGBA16Float at speed=60.
float3 Decode(float3 yc) {
  if (exponent > 0) yc.x = exp2(yc.x * exponent) - 1;
  return yc;
}
float3 Encode(float3 yc) {
  yc.x = max(yc.x, 0);
  if (exponent > 0) yc.x = log2(1 + yc.x) / exponent;
  return yc;
}
float3 LimitYC(float3 yc) {
  if (yc.x > 2) {
    yc.yz *= saturate((4 - yc.x) / 2);
    yc.x = 2;
  }
  return yc;
}

float4 legacy_glow_extract(float4 pos : SV_Position) : SV_Target {
  float4 source = input0.Load(int3(int2(pos.xy) - int(padding), 0));
  float3 yc = ToYC(source.rgb);
  float difference = floor(yc.x * 4096) - floor(threshold * 4096);
  float s = floor(strength * 4096);
  float glow = difference < 0 ? 0 : saturate((floor(difference * min(s, 4096) / 4096) + max(s - 4096, 0)) / 4096);
  float2 chroma = source.a > 0 ? yc.yz / source.a : float2(0, 0);
  float3 light = useColor > 0 ? ToYC(float3(red, green, blue)) * glow : float3(glow, chroma * glow);
  if (source.a == 0) light = 0;
  light = floor(light * 4096) / 4096;
  if (exponent > 0) light.yz = clamp(floor(light.yz * 256 + 0.5), -128, 127) / 256;
  return float4(light, 0);
}

float3 ReadLine(int position, int lineIndex) {
  int2 p = vertical > 0 ? int2(lineIndex, position) : int2(position, lineIndex);
  return Decode(input0.Load(int3(p, 0)).xyz);
}
void AddCompensated(inout float3 sum, inout float3 error, float3 value) {
  float3 adjusted = value - error;
  precise float3 next = sum + adjusted;
  error = (next - sum) - adjusted;
  sum = next;
}

[numthreads(64, 1, 1)] void legacy_glow_blur(uint3 id : SV_DispatchThreadID) {
  uint width, height;
  input0.GetDimensions(width, height);
  int length = vertical > 0 ? height : width;
  int lines = vertical > 0 ? width : height;
  if (id.x >= uint(lines)) return;
  int r = int(radius);
  float3 sum = 0, error = 0;
  for (int i = 0; i <= r; i++) AddCompensated(sum, error, ReadLine(i, id.x));
  for (int p = 0; p < length; p++) {
    float3 value = sum / (2 * r + 1);
    if (exponent == 0)
      value = trunc(value * 4096) / 4096;
    else
      value.yz = round(value.yz * 256) / 256;
    int2 at = vertical > 0 ? int2(id.x, p) : int2(p, id.x);
    output0[at] = float4(Encode(value), 0);
    if (p - r >= 0) AddCompensated(sum, error, -ReadLine(p - r, id.x));
    if (p + r + 1 < length) AddCompensated(sum, error, ReadLine(p + r + 1, id.x));
  }
}

float4 legacy_glow_add(float4 pos : SV_Position)
    : SV_Target {
  int3 p = int3(pos.xy, 0);
  float3 total = Decode(input1.Load(p).xyz);
  if (firstPass > 0 && isFilter > 0 && exponent == 0) total = ToYC(original.Load(p).rgb);
  total += Decode(input0.Load(p).xyz);
  if (exponent == 0)
    total = LimitYC(total);
  else
    total.yz = clamp(total.yz, -0.5, 127.0 / 256);
  return float4(Encode(total), 0);
}

float4 legacy_glow_finish(float4 pos : SV_Position) : SV_Target {
  float4 source = input1.Load(int3(int2(pos.xy) - int(padding), 0));
  float3 glow = input0.Load(int3(pos.xy, 0)).xyz;
  float3 result = glow;
  if (isFilter == 0 || exponent > 0) result += ToYC(source.rgb);
  float alpha = isFilter > 0 ? source.a : saturate(source.a + glow.x);
  return float4(ToRGB(result), alpha);
}
