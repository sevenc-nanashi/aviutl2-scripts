cbuffer PixelSortParams : register(b0) {
  float thresholdMin;
  float thresholdMax;

  float maxLevelsF;
  float orderingF;

  float directionF;
  float visualizeRed;
  float visualizeGreen;
  float visualizeBlue;
  float visualizeFillAlpha;
  float visualizeSourceAlpha;
};

Texture2D<float4> sortedTex : register(t0);
Texture2D<float4> metaTex : register(t1);

uint GetDirection() { return directionF >= 0.5 ? 1u : 0u; }

uint2 MetaPosition(uint xMeta, uint y, uint dir) { return dir != 0u ? uint2(xMeta, y) : uint2(y, xMeta); }

float4 bitonic_pixelsort_visualize_sort_range(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
  uint width;
  uint height;
  sortedTex.GetDimensions(width, height);

  uint2 dst = min(uint2(pos.xy), uint2(width - 1u, height - 1u));
  float4 current = sortedTex.Load(int3(dst, 0));

  uint dir = GetDirection();
  uint size = dir != 0u ? width : height;
  uint x = dir != 0u ? dst.x : dst.y;
  uint y = dir != 0u ? dst.y : dst.x;
  uint xMeta = x / 2u;

  float4 meta = metaTex.Load(int3(MetaPosition(xMeta, y, dir), 0));
  int startL = (int)round(meta.x);
  int startR = (int)round(meta.y);

  bool inRange = (startR - startL > 1) && ((int)x >= startL) && ((int)x <= startR);
  if (!inRange || x >= size) {
    return current * saturate(visualizeSourceAlpha);
  }

  float3 visualizeColor = saturate(float3(visualizeRed, visualizeGreen, visualizeBlue));
  float fillAlpha = saturate(visualizeFillAlpha);
  float sourceAlpha = saturate(visualizeSourceAlpha);
  float3 rgb = current.rgb * sourceAlpha + visualizeColor * fillAlpha;
  return float4(saturate(rgb), current.a);
}
