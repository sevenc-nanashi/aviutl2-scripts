#define MAX_THREADS 256
#define MAX_SIZE 2048

#define MAX_OPS (MAX_SIZE / MAX_THREADS)

#define META_LINES_PER_GROUP 8
#define META_THREADS_PER_GROUP (META_LINES_PER_GROUP * 2)

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

  float maxLevelsF;
  float orderingF;

  float directionF;
};

Texture2D<float4> srcTex : register(t0);
RWTexture2D<float4> metaTex : register(u0);
RWTexture2D<float4> sortTex : register(u1);

groupshared uint metaGroupCache[MAX_SIZE * 4];
groupshared uint groupCache[MAX_SIZE];

float Brightness(float4 col) { return saturate(0.298912 * col.r + 0.586611 * col.g + 0.114478 * col.b); }

uint GetDirection() { return directionF >= 0.5 ? 1u : 0u; }

uint GetOrdering() { return orderingF >= 0.5 ? 1u : 0u; }

int GetMaxLevels() { return (int)round(maxLevelsF); }

uint2 SourcePosition(uint x, uint y, uint dir) { return dir != 0u ? uint2(x, y) : uint2(y, x); }

uint2 MetaPosition(uint xMeta, uint y, uint dir) { return dir != 0u ? uint2(xMeta, y) : uint2(y, xMeta); }

uint PackMetaGroupCache(bool left, bool right, int value, int brightnessA, int brightnessB) {
  // lrvvvvvv vvvvvvvv bbbbbbbb BBBBBBBB
  uint packed = left ? 0x80000000u : 0u;
  packed |= right ? 0x40000000u : 0u;

  packed |= (asuint(value) & 0x3FFFu) << 16;
  packed |= ((uint)brightnessA & 0xFFu) << 8;
  packed |= ((uint)brightnessB & 0xFFu);

  return packed;
}

void UnpackMetaGroupCache(uint packed, out bool left, out bool right, out int value, out int brightnessA,
                          out int brightnessB) {
  left = (packed & 0x80000000u) != 0u;
  right = (packed & 0x40000000u) != 0u;

  uint valueSeg = (packed >> 16) & 0x3FFFu;

  bool isNegative = (valueSeg & 0x2000u) != 0u;
  valueSeg |= isNegative ? 0xFFFFC000u : 0u;

  value = asint(valueSeg);

  brightnessA = (int)((packed >> 8) & 0xFFu);
  brightnessB = (int)(packed & 0xFFu);
}

[numthreads(META_THREADS_PER_GROUP, 1, 1)] void bitonic_pixelsort_meta(uint3 groupId : SV_GroupID,
                                                                       uint3 gtid : SV_GroupThreadID) {
  uint dir = GetDirection();

  uint width;
  uint height;
  srcTex.GetDimensions(width, height);

  uint size = dir != 0u ? width : height;

  uint id = groupId.x * META_THREADS_PER_GROUP + gtid.x;

  bool metaDirection = (id % 2u) == 0u;
  uint y = id / 2u;

  uint groupLocalY = gtid.x / 2u;

  int rangeStart = metaDirection ? (int)size : -1;

  uint halfSize = (uint)(round((float)size / 8.0) * 4.0);
  uint firstHalfSize = metaDirection ? halfSize : size - halfSize;

  uint cacheLineSize = (size + 1u) / 2u;

  for (uint firstPassPos = 0u; firstPassPos < firstHalfSize; firstPassPos += 2u) {
    uint x = metaDirection ? firstPassPos : size - firstPassPos - 1u;

    uint xMeta = x / 2u;
    uint xL = xMeta << 1;
    uint xR = xL + 1u;

    uint xFirst = metaDirection ? xL : xR;
    uint xSecond = metaDirection ? xR : xL;

    bool validFirst = xFirst < size;
    bool validSecond = xSecond < size;

    float bFirst = 0.0;
    float bSecond = 0.0;

    if (validFirst) {
      bFirst = Brightness(srcTex.Load(int3(SourcePosition(xFirst, y, dir), 0)));
    }

    if (validSecond) {
      bSecond = Brightness(srcTex.Load(int3(SourcePosition(xSecond, y, dir), 0)));
    }

    bool rangeFirst = validFirst && thresholdMin <= bFirst && bFirst <= thresholdMax;

    bool rangeSecond = validSecond && thresholdMin <= bSecond && bSecond <= thresholdMax;

    int rangeStartFirst = metaDirection ? (rangeFirst ? min(rangeStart, (int)xFirst) : (int)size)
                                        : (rangeFirst ? max(rangeStart, (int)xFirst) : -1);

    rangeStart = metaDirection ? (rangeSecond ? min(rangeStartFirst, (int)xSecond) : (int)size)
                               : (rangeSecond ? max(rangeStartFirst, (int)xSecond) : -1);

    int rangeStartAny = rangeFirst ? rangeStartFirst : rangeStart;

    uint cachePos = groupLocalY * cacheLineSize + xMeta;

    bool rangeLeft = metaDirection ? rangeFirst : rangeSecond;
    bool rangeRight = metaDirection ? rangeSecond : rangeFirst;

    uint bLeft = (uint)((metaDirection ? bFirst : bSecond) * 255.0);
    uint bRight = (uint)((metaDirection ? bSecond : bFirst) * 255.0);

    metaGroupCache[cachePos] = PackMetaGroupCache(rangeLeft, rangeRight, rangeStartAny, (int)bLeft, (int)bRight);
  }

  GroupMemoryBarrierWithGroupSync();

  for (uint secondPassPos = firstHalfSize; secondPassPos < size; secondPassPos += 2u) {
    uint x = metaDirection ? secondPassPos : size - secondPassPos - 1u;

    uint xMeta = x / 2u;
    uint xL = xMeta << 1;
    uint xR = xL + 1u;

    uint xFirst = metaDirection ? xL : xR;
    uint xSecond = metaDirection ? xR : xL;

    uint cachePos = groupLocalY * cacheLineSize + xMeta;
    uint packed = metaGroupCache[cachePos];

    bool rangeLeft;
    bool rangeRight;
    int otherStart;
    int bFirstPacked;
    int bSecondPacked;

    UnpackMetaGroupCache(packed, rangeLeft, rangeRight, otherStart, bFirstPacked, bSecondPacked);

    bool rangeFirst = metaDirection ? rangeLeft : rangeRight;
    bool rangeSecond = metaDirection ? rangeRight : rangeLeft;

    int rangeStartFirst = metaDirection ? (rangeFirst ? min(rangeStart, (int)xFirst) : (int)size)
                                        : (rangeFirst ? max(rangeStart, (int)xFirst) : -1);

    rangeStart = metaDirection ? (rangeSecond ? min(rangeStartFirst, (int)xSecond) : (int)size)
                               : (rangeSecond ? max(rangeStartFirst, (int)xSecond) : -1);

    int rangeStartAny = rangeFirst ? rangeStartFirst : rangeStart;

    int startL = metaDirection ? rangeStartAny : otherStart;
    int startR = metaDirection ? otherStart : rangeStartAny;

    uint2 pos = MetaPosition(xMeta, y, dir);

    metaTex[pos] = float4((float)startL, (float)startR, (float)bFirstPacked, (float)bSecondPacked);
  }
}

    [numthreads(MAX_THREADS, 1, 1)] void bitonic_pixelsort_sort(uint3 gid_l : SV_GroupID,
                                                                uint3 gtid_l : SV_GroupThreadID) {
  uint dir = GetDirection();
  uint ord = GetOrdering();
  int maxLv = GetMaxLevels();

  uint gid = gid_l.x;
  uint gtid = gtid_l.x;

  uint width;
  uint height;
  sortTex.GetDimensions(width, height);

  uint size = dir != 0u ? width : height;
  uint reducedSize = (size + 1u) / 2u;

  uint ops = (reducedSize + MAX_THREADS - 1u) / MAX_THREADS;

  uint preMeta[MAX_OPS];

  for (uint preOp = 0u; preOp < ops; preOp++) {
    uint xMeta = MAX_THREADS * preOp + gtid;

    if (xMeta >= reducedSize) {
      continue;
    }

    uint y = gid;

    uint xL = xMeta * 2u;
    uint xR = xL + 1u;

    uint2 metaPos = MetaPosition(xMeta, y, dir);

    float4 meta = metaTex[metaPos];

    int startL = (int)round(meta.x);
    int startR = (int)round(meta.y);

    bool useR = (startL & 1) != 0;
    uint x = useR ? xR : xL;

    bool isInRange = (startR - startL > 1) && ((int)x <= startR);

    startL = isInRange ? startL : (int)x;
    startR = isInRange ? startR : (int)x;

    preMeta[preOp] = ((uint)startL << 16) | ((uint)startR & 0xFFFFu);

    groupCache[xL] = (f32tof16(meta.z) & 0xFFFFu) | (xL << 16);

    if (xR < size) {
      groupCache[xR] = (f32tof16(meta.w) & 0xFFFFu) | (xR << 16);
    }
  }

  for (uint level = 0u; level < (uint)maxLv; level++) {
    for (int rank = (int)level; rank >= 0; rank--) {
      GroupMemoryBarrierWithGroupSync();

      for (uint sortOp = 0u; sortOp < ops; sortOp++) {
        uint xMeta = MAX_THREADS * sortOp + gtid;

        if (xMeta >= reducedSize) {
          continue;
        }

        uint metaPacked = preMeta[sortOp];

        int rangeStart = (int)(metaPacked >> 16);
        int rangeEnd = (int)(metaPacked & 0xFFFFu);

        int x = (int)(xMeta << 1);

        int useR = rangeStart & 1;
        int posInRange = x - rangeStart + useR;

        int swapIndex = posInRange >> 1;

        int comparatorSize = 1 << rank;

        int a = rangeStart + (swapIndex & (comparatorSize - 1)) + ((swapIndex >> rank) * (comparatorSize << 1));

        int b = a + comparatorSize;

        b = b <= rangeEnd ? b : a;

        int block = (posInRange >> 1) >> level;
        int n = rangeEnd - rangeStart + 1;
        int endBlock = n >> (level + 1);

        bool ascPattern = ((endBlock & 1) == 0) == (ord != 0u);
        bool asc = ((block & 1) == 0) == ascPattern;

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
    uint xMeta = MAX_THREADS * writeOp + gtid;

    if (xMeta >= reducedSize) {
      continue;
    }

    uint y = gid;

    uint xL = xMeta * 2u;
    uint xR = xL + 1u;

    uint valA = groupCache[xL];
    uint idxLeft = valA >> 16;

    uint2 dstA = SourcePosition(xL, y, dir);
    uint2 srcA = SourcePosition(idxLeft, y, dir);

    sortTex[dstA] = srcTex.Load(int3(srcA, 0));

    if (xR < size) {
      uint valB = groupCache[xR];
      uint idxRight = valB >> 16;

      uint2 dstB = SourcePosition(xR, y, dir);
      uint2 srcB = SourcePosition(idxRight, y, dir);

      sortTex[dstB] = srcTex.Load(int3(srcB, 0));
    }
  }
}
