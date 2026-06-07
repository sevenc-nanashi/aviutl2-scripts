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
--separator:不透明度
---$track:ソート範囲可視化::塗り
---min=0
---max=1
---step=0.01
local visualize_fill_opacity = 0.5
---$track:ソート範囲可視化::元画像
---min=0
---max=1
---step=0.01
local visualize_source_opacity = 0.5
--group:その他

---$value:PI
local PI = {}

--[[computeshader@bitonic_pixelsort_2048:
#define ENTRYPOINT bitonic_pixelsort_2048
---$include "./shader.hlsl"
]]
--[[computeshader@bitonic_pixelsort_4096:
#define BPS_SIZE_4096
#define ENTRYPOINT bitonic_pixelsort_4096
---$include "./shader.hlsl"
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

local size, lines
if direction == 0 or direction == 2 then
  size = obj.w
  lines = obj.h
else
  size = obj.h
  lines = obj.w
end

if size > 4096 then
  error("too large! size=" .. size .. " must be 4096 or smaller.")
end

local prefix = "cache:bitonic_pixelsort__"

obj.clearbuffer(prefix .. "sorted", obj.w, obj.h)

local visualize_r_uint, visualize_g_uint, visualize_b_uint = RGB(visualize_color)
local visualize_r = visualize_r_uint / 255
local visualize_g = visualize_g_uint / 255
local visualize_b = visualize_b_uint / 255
local common_params = {
  threshold_min,
  threshold_max,
  visualize_sort_range and 1 or 0,
  math.floor(direction / 2),
  (direction + 1) % 2,
  visualize_r,
  visualize_g,
  visualize_b,
  visualize_fill_opacity,
  visualize_source_opacity,
}
local shader_name = size <= 2048 and "bitonic_pixelsort_2048" or "bitonic_pixelsort_4096"
obj.computeshader(shader_name, { prefix .. "sorted" }, "object", common_params, lines, 1, 1)
obj.copybuffer("object", prefix .. "sorted")
