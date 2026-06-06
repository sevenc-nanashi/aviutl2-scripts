--filter
--label:加工

---$include "./readme.lua"

-- このスクリプトはBitonicPixelSorterをベースに作成しました。
-- BitonicPixelSorterの作者であるruccho様に感謝いたします。
-- 以下はBitonicPixelSorterのライセンス情報です。
-- ------------------------------------------------------------------------------------------------------------------------
-- MIT License
--
-- Copyright (c) 2020 ruccho
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
-- ------------------------------------------------------------------------------------------------------------------------

---$select:方向
---横方向=0
---縦方向=1
---横方向（反転）=2
---縦方向（反転）=3
local direction = 0

--group:しきい値
---$track:しきい値::最小
---min=0
---max=1
---step=0.001
local threshold_min = 0
---$track:しきい値::最大
---min=0
---max=1
---step=0.001
local threshold_max = 1
--group:ソート範囲可視化
---$check:ソート範囲可視化::可視化
local visualize_sort_range = false
---$color:ソート範囲可視化::色
local visualize_color = 0xff00ff
---$track:ソート範囲可視化::塗りの不透明度
---min=0
---max=1
---step=0.01
local visualize_fill_opacity = 0.5
---$track:ソート範囲可視化::元画像の不透明度
---min=0
---max=1
---step=0.01
local visualize_source_opacity = 0.5

---$value:PI
local PI = {}

--[[computeshader@bitonic_pixelsort_meta:
---$include "./shader.hlsl"
]]

--[[computeshader@bitonic_pixelsort_sort:
---$include "./shader.hlsl"
]]

--[[pixelshader@bitonic_pixelsort_visualize_sort_range:
---$include "./visualizer.hlsl"
]]

if type(PI.direction) == "number" then
  direction = PI.direction
end

if type(PI.threshold_min) == "number" then
  threshold_min = PI.threshold_min
end

if type(PI.threshold_max) == "number" then
  threshold_max = PI.threshold_max
end

if type(PI.visualize_sort_range) == "boolean" then
  visualize_sort_range = PI.visualize_sort_range
end

if type(PI.visualize_color) == "number" then
  visualize_color = PI.visualize_color
end

if type(PI.visualize_fill_opacity) == "number" then
  visualize_fill_opacity = PI.visualize_fill_opacity
end

if type(PI.visualize_source_opacity) == "number" then
  visualize_source_opacity = PI.visualize_source_opacity
end

local function log2(x)
  local n = 0
  while x > 1 do
    x = x / 2
    n = n + 1
  end
  return n
end

local size, lines
if direction == 0 or direction == 2 then
  size = obj.w
  lines = obj.h
else
  size = obj.h
  lines = obj.w
end

if size >= 2048 then
  error("too large! size=" .. size .. " must be less than 2048.")
end

local meta_width, meta_height
if direction == 0 or direction == 2 then
  meta_width = math.ceil(obj.w / 2)
  meta_height = obj.h
else
  meta_width = obj.w
  meta_height = math.ceil(obj.h / 2)
end

local prefix = "cache:bitonic_pixelsort__"

obj.clearbuffer(prefix .. "meta", meta_width, meta_height)
obj.clearbuffer(prefix .. "sorted", obj.w, obj.h)

-- NOTE: GetKernelThreadGroupSizes相当がないのでハードコード
local meta_group_x, meta_group_y, meta_group_z = 16, 1, 1
local meta_group_size = meta_group_x * meta_group_y * meta_group_z
local meta_dispatch_count = math.ceil(lines * 2 / meta_group_size)
local max_levels = math.ceil(log2(size))
local visualize_r_uint, visualize_g_uint, visualize_b_uint = RGB(visualize_color)
local visualize_r = visualize_r_uint / 255
local visualize_g = visualize_g_uint / 255
local visualize_b = visualize_b_uint / 255
local common_params = {
  threshold_min,
  threshold_max,
  max_levels,
  math.floor(direction / 2),
  (direction + 1) % 2,
}
local visualize_params = {
  threshold_min,
  threshold_max,
  max_levels,
  math.floor(direction / 2),
  (direction + 1) % 2,
  visualize_r,
  visualize_g,
  visualize_b,
  visualize_fill_opacity,
  visualize_source_opacity,
}
obj.computeshader(
  "bitonic_pixelsort_meta",
  { prefix .. "meta", prefix .. "sorted" },
  "object",
  common_params,
  meta_dispatch_count,
  1,
  1
)
obj.computeshader(
  "bitonic_pixelsort_sort",
  { prefix .. "meta", prefix .. "sorted" },
  "object",
  common_params,
  lines,
  1,
  1
)
if visualize_sort_range then
  obj.pixelshader(
    "bitonic_pixelsort_visualize_sort_range",
    prefix .. "sorted",
    { prefix .. "sorted", prefix .. "meta" },
    visualize_params
  )
end
obj.copybuffer("object", prefix .. "sorted")
