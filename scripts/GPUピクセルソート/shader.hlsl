#ifdef BPS_SIZE_4096
#define MAX_THREADS 256  // keeps MAX_PAIRS at 8, same as the default variant
#define MAX_SIZE 4096    // 16KiB of group shared memory
#else
#define MAX_THREADS 128  // threads per SM is usually multiple of 512 (NVIDIA). It may maximize occupancy.
#define MAX_SIZE 2048    // due to group shared memory limit
#endif
#define MAX_PAIRS (MAX_SIZE / MAX_THREADS / 2)

// directionF:
//   1.0 = horizontal, x方向に処理
//   0.0 = vertical, y方向に処理
//
// orderingF:
//   1.0 = ascending
//   0.0 = descending

cbuffer PixelSortParams : register(b0) {
  float thresholdMin;
  float thresholdMax;

  float visualizeSortRangeF;
  float orderingF;

  float directionF;
  float visualizeRed;
  float visualizeGreen;
  float visualizeBlue;
  float visualizeFillAlpha;
  float visualizeSourceAlpha;
};

Texture2D<float4> srcTex : register(t0);
RWTexture2D<float4> sortTex : register(u0);

groupshared uint groupCache[MAX_SIZE];
groupshared uint scanCache[MAX_THREADS];

float Brightness(float4 col) { return saturate(0.298912 * col.r + 0.586611 * col.g + 0.114478 * col.b); }

uint GetDirection() { return directionF >= 0.5 ? 1u : 0u; }

uint GetOrdering() { return orderingF >= 0.5 ? 1u : 0u; }

bool GetVisualizeSortRange() { return visualizeSortRangeF >= 0.5; }

uint2 SourcePosition(uint x, uint y, uint dir) { return dir != 0u ? uint2(x, y) : uint2(y, x); }

float4 VisualizeSortRange(float4 current, bool inRange) {
  float sourceAlpha = saturate(visualizeSourceAlpha);

  if (!inRange) {
    return current * sourceAlpha;
  }

  float3 visualizeColor = saturate(float3(visualizeRed, visualizeGreen, visualizeBlue));
  float fillAlpha = saturate(visualizeFillAlpha);
  float3 rgb = current.rgb * sourceAlpha + visualizeColor * fillAlpha;
  return float4(saturate(rgb), current.a);
}

[numthreads(MAX_THREADS, 1, 1)] void ENTRYPOINT(uint3 gid_l : SV_GroupID, uint3 gtid_l : SV_GroupThreadID) {
  uint dir = GetDirection();
  uint ord = GetOrdering();
  bool visualizeSortRange = GetVisualizeSortRange();

  uint gid = gid_l.x;
  uint gtid = gtid_l.x;

  uint width;
  uint height;
  sortTex.GetDimensions(width, height);

  uint size = dir != 0u ? width : height;
  uint reducedSize = (size + 1u) >> 1;
  uint ops = (reducedSize + MAX_THREADS - 1u) / MAX_THREADS;
  uint pairBase = gtid * ops;

  uint rangeMask = 0u;
  for (uint loadOp = 0u; loadOp < ops; loadOp++) {
    uint pair = pairBase + loadOp;
    uint xL = pair << 1;
    uint xR = xL + 1u;

    if (pair >= reducedSize) {
      continue;
    }

    float brL = 0.0;
    float brR = 0.0;

    if (xL < size) {
      brL = Brightness(srcTex.Load(int3(SourcePosition(xL, gid, dir), 0)));
    }

    if (xR < size) {
      brR = Brightness(srcTex.Load(int3(SourcePosition(xR, gid, dir), 0)));
    }

    bool inL = xL < size && thresholdMin <= brL && brL <= thresholdMax;
    bool inR = xR < size && thresholdMin <= brR && brR <= thresholdMax;

    rangeMask |= (inL ? 1u : 0u) << (loadOp * 2u);
    rangeMask |= (inR ? 1u : 0u) << (loadOp * 2u + 1u);

    groupCache[xL] = (xL << 16) | (f32tof16(brL) & 0xFFFFu);

    if (xR < size) {
      groupCache[xR] = (xR << 16) | (f32tof16(brR) & 0xFFFFu);
    }
  }

  uint preMeta[MAX_PAIRS];

  {
    uint seed = 0u;
    for (uint seedOp = 0u; seedOp < ops; seedOp++) {
      uint pair = pairBase + seedOp;
      uint xL = pair << 1;

      if (pair >= reducedSize) {
        continue;
      }

      if ((rangeMask & (1u << (seedOp * 2u))) == 0u) {
        seed = xL + 1u;
      }
      if ((rangeMask & (2u << (seedOp * 2u))) == 0u) {
        seed = xL + 2u;
      }
    }

    scanCache[gtid] = seed;
    GroupMemoryBarrierWithGroupSync();

    for (uint prefixOffset = 1u; prefixOffset < MAX_THREADS; prefixOffset <<= 1u) {
      uint own = scanCache[gtid];
      uint other = scanCache[max(gtid, prefixOffset) - prefixOffset];
      GroupMemoryBarrierWithGroupSync();
      scanCache[gtid] = max(own, gtid >= prefixOffset ? other : 0u);
      GroupMemoryBarrierWithGroupSync();
    }

    uint carry = scanCache[max(gtid, 1u) - 1u];
    carry = gtid > 0u ? carry : 0u;

    for (uint startOp = 0u; startOp < ops; startOp++) {
      uint pair = pairBase + startOp;
      uint xL = pair << 1;

      if (pair >= reducedSize) {
        preMeta[startOp] = xL << 16;
        continue;
      }

      bool inL = (rangeMask & (1u << (startOp * 2u))) != 0u;
      bool inR = (rangeMask & (2u << (startOp * 2u))) != 0u;

      uint start;
      if (inL) {
        start = carry;
      } else {
        carry = xL + 1u;
        start = inR ? carry : xL;
      }
      if (!inR) {
        carry = xL + 2u;
      }

      preMeta[startOp] = start << 16;
    }

    GroupMemoryBarrierWithGroupSync();
  }

  uint lineLevels;

  {
    uint seed = 0xFFFFu;
    for (uint suffixSeedOp = ops; suffixSeedOp > 0u;) {
      suffixSeedOp--;
      uint pair = pairBase + suffixSeedOp;
      uint xL = pair << 1;

      if (pair >= reducedSize) {
        continue;
      }

      if ((rangeMask & (2u << (suffixSeedOp * 2u))) == 0u) {
        seed = xL + 1u;
      }
      if ((rangeMask & (1u << (suffixSeedOp * 2u))) == 0u) {
        seed = xL;
      }
    }

    scanCache[gtid] = seed;
    GroupMemoryBarrierWithGroupSync();

    for (uint suffixOffset = 1u; suffixOffset < MAX_THREADS; suffixOffset <<= 1u) {
      uint own = scanCache[gtid];
      uint other = scanCache[min(gtid + suffixOffset, MAX_THREADS - 1u)];
      GroupMemoryBarrierWithGroupSync();
      scanCache[gtid] = min(own, gtid + suffixOffset < MAX_THREADS ? other : 0xFFFFu);
      GroupMemoryBarrierWithGroupSync();
    }

    uint carry = scanCache[min(gtid + 1u, MAX_THREADS - 1u)];
    carry = gtid + 1u < MAX_THREADS ? carry : 0xFFFFu;

    uint maxLen = 1u;
    for (uint endOp = ops; endOp > 0u;) {
      endOp--;
      uint pair = pairBase + endOp;
      uint xL = pair << 1;

      if (pair >= reducedSize) {
        continue;
      }

      bool inL = (rangeMask & (1u << (endOp * 2u))) != 0u;
      bool inR = (rangeMask & (2u << (endOp * 2u))) != 0u;

      if (!inR) {
        carry = xL + 1u;
      }

      uint start = preMeta[endOp] >> 16;
      uint end = inL || inR ? min(carry, size) - 1u : xL;

      if (!inL) {
        carry = xL;
      }

      uint xSlot = xL + (start & 1u);
      bool valid = end > start && xSlot <= end;
      start = valid ? start : xSlot;
      end = valid ? end : xSlot;

      preMeta[endOp] = (start << 16) | end;
      maxLen = max(maxLen, end - start + 1u);
    }

    GroupMemoryBarrierWithGroupSync();

    scanCache[gtid] = maxLen;
    GroupMemoryBarrierWithGroupSync();

    for (uint reduceOffset = MAX_THREADS >> 1u; reduceOffset > 0u; reduceOffset >>= 1u) {
      if (gtid < reduceOffset) {
        scanCache[gtid] = max(scanCache[gtid], scanCache[gtid + reduceOffset]);
      }
      GroupMemoryBarrierWithGroupSync();
    }

    maxLen = scanCache[0];
    lineLevels = maxLen <= 1u ? 0u : (uint)firstbithigh(maxLen) + 1u;
  }

  for (uint phase = 0u; (phase & 0xFFFFu) < lineLevels; phase++) {
    for (phase = (phase << 16) + (phase & 0xFFFFu); (phase >> 16) <= 0x7FFFu; phase -= (1u << 16)) {
      GroupMemoryBarrierWithGroupSync();

      for (uint sortOp = 0u; sortOp < ops; sortOp++) {
        uint pair = pairBase + sortOp;
        uint x = pair << 1;

        if (pair >= reducedSize) {
          continue;
        }

        uint metaPacked = preMeta[sortOp];
        uint rangeStart = metaPacked >> 16;
        uint rangeEnd = metaPacked & 0xFFFFu;

        uint useR = rangeStart & 1u;
        uint posInRange = x - rangeStart + useR;
        uint swapIndex = posInRange >> 1;
        uint comparatorSize = 1u << (phase >> 16);

        uint a =
            rangeStart + (swapIndex & (comparatorSize - 1u)) + ((swapIndex >> (phase >> 16)) * (comparatorSize << 1));

        uint b = a + comparatorSize;
        b = b <= rangeEnd ? b : a;

        uint block = (posInRange >> 1) >> phase;
        uint n = rangeEnd - rangeStart + 1u;
        uint endBlock = n >> (phase + 1u);

        bool ascPattern = ((endBlock & 1u) == 0u) == (ord != 0u);
        bool asc = ((block & 1u) == 0u) == ascPattern;

        uint valA = groupCache[a];
        uint valB = groupCache[b];

        float brA = f16tof32(valA & 0xFFFFu);
        float brB = f16tof32(valB & 0xFFFFu);

        bool comp = brA < brB;

        uint left = asc == comp ? valA : valB;
        uint right = asc == comp ? valB : valA;

        groupCache[a] = left;
        groupCache[b] = right;
      }
    }
  }

  GroupMemoryBarrierWithGroupSync();

  for (uint writeOp = 0u; writeOp < ops; writeOp++) {
    uint pair = pairBase + writeOp;
    uint xL = pair << 1;
    uint xR = xL + 1u;

    if (pair >= reducedSize) {
      continue;
    }

    uint valA = groupCache[xL];
    uint idxLeft = valA >> 16;

    uint metaPacked = preMeta[writeOp];
    uint rangeStart = metaPacked >> 16;
    uint rangeEnd = metaPacked & 0xFFFFu;

    float4 colorLeft = srcTex.Load(int3(SourcePosition(idxLeft, gid, dir), 0));
    if (visualizeSortRange) {
      bool inRangeLeft = rangeEnd - rangeStart > 1u && xL >= rangeStart && xL <= rangeEnd;
      colorLeft = VisualizeSortRange(colorLeft, inRangeLeft);
    }

    sortTex[SourcePosition(xL, gid, dir)] = colorLeft;

    if (xR < size) {
      uint valB = groupCache[xR];
      uint idxRight = valB >> 16;

      float4 colorRight = srcTex.Load(int3(SourcePosition(idxRight, gid, dir), 0));
      if (visualizeSortRange) {
        bool inRangeRight = rangeEnd - rangeStart > 1u && xR >= rangeStart && xR <= rangeEnd;
        colorRight = VisualizeSortRange(colorRight, inRangeRight);
      }

      sortTex[SourcePosition(xR, gid, dir)] = colorRight;
    }
  }
}
