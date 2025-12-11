--label:変形
--information:https://github.com/sevenc-nanashi/aviutl2-scripts/blob/main/scripts/%E3%83%89%E3%83%83%E3%83%88%E7%B5%B5%E5%A4%89%E5%BD%A2.anm2

-- ========================================================================================================================
-- cleanEdgeで拡大縮小・回転・中心移動を行うスクリプト。
-- ドット絵変形と違い、これはドット絵でも綺麗に変形されます。
--
-- cleanEdgeについてはこれを参照してください：https://torcado.com/cleanEdge/
--
-- 一部パラメーターの説明：
-- - 基準色：線の上書き判定に使う色。例えば#ffffffの場合は明るい色が優先されます。もしドット絵に外枠がある場合は、外枠を設定すると綺麗になります。
--           cleanEdgeのHighest Colorに相当します。
-- - 線の太さ：線の太さを指定します。ピクセルが何マス分に広がるかを指定します。45度の線を綺麗にしたい場合は0.707付近にしてください。
--             cleanEdgeのLine Widthに相当します。
-- - 斜め補間：拡大時に傾斜を滑らかにするかどうかを指定します。
--             cleanEdgeのSlopesに相当します。
--
--
-- PI:
-- - scale_x: X拡大率（1.0で等倍）
-- - scale_y: Y拡大率（1.0で等倍）
-- - center_x: 中心X（ピクセル単位）
-- - center_y: 中心Y（ピクセル単位）
-- - angle_deg: 回転（度）
-- - highest_color: 線の上書き判定に使う色。
-- - line_width: 線の太さ。
-- - slopes: 拡大時に傾斜を滑らかにするかどうか（0：しない、1：1:1のみ滑らかにする、2：1:1と1:2を滑らかにする）
-- - debug: デバッググリッドの表示（0で非表示、正の値でグリッドサイズ）
--
-- https://aviutl2-scripts-download.sevenc7c.workers.dev/%E6%BB%91%E3%82%89%E3%81%8B%E3%83%89%E3%83%83%E3%83%88%E7%B5%B5%E5%A4%89%E5%BD%A2.anm2
-- ========================================================================================================================


-- このスクリプトはcleanEdgeをベースに作成しました。
-- cleanEdgeの作者であるtorcado様に感謝いたします。（Great Appreciation to torcado, the author of cleanEdge.）
-- 以下はcleanEdgeのライセンス情報です。
-- --------------------------------------------------------------------------------
-- Copyright (c) 2022 torcado
-- Permission is hereby granted, free of charge, to any person
-- obtaining a copy of this software and associated documentation
-- files (the "Software"), to deal in the Software without
-- restriction, including without limitation the rights to use,
-- copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following
-- conditions:
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
-- OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
-- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
-- HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
-- WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
-- OTHER DEALINGS IN THE SOFTWARE.
-- --------------------------------------------------------------------------------

--group:中心移動,true

---$track:中心X
---min=-5000
---max=5000
---default=0
---step=0.01
local center_x = 0
---$track:中心Y
---min=-5000
---max=5000
---default=0
---step=0.01
local center_y = 0

--group:拡大縮小,true

---$track:X拡大率
---min=1
---max=10000
---default=100
---step=0.001
local scale_x = 100

---$track:Y拡大率
---min=1
---max=10000
---default=100
---step=0.001
local scale_y = 100

---$select:斜め補間
---しない=0
---1:1のみ=1
---1:1と1:2=2
local slopes = 0

--group:回転,true

---$track:回転（度）
---min=-360
---max=360
---default=0
---step=0.1
local angle_deg = 0

--group:補間設定,true

---$track:線の太さ
---min=0
---max=4
---default=1
---step=0.01
local line_width = 1

---$color:基準色
local highest_color = 0xffffff

--group:高度な設定,false
---$track:透明グリッド
---min=0
---max=1000
---default=0
---step=1
local debug = 0

---$value:PI
local PI = {}

--[[pixelshader@debug_grid:
---$include "./debug_grid.hlsl"
]]
--[[pixelshader@transform:
---$include "./transform.hlsl"
]]

if type(PI.center_x) == "number" then
  center_x = PI.center_x
end
if type(PI.center_y) == "number" then
  center_y = PI.center_y
end
if type(PI.scale_x) == "number" then
  scale_x = PI.scale_x * 100
end
if type(PI.scale_y) == "number" then
  scale_y = PI.scale_y * 100
end
if type(PI.slopes) == "number" then
  slopes = PI.slopes
end
if type(PI.angle_deg) == "number" then
  angle_deg = PI.angle_deg
end
if type(PI.highest_color) == "number" then
  highest_color = PI.highest_color
end
if type(PI.line_width) == "number" then
  line_width = PI.line_width
end
if type(PI.debug) == "boolean" then
  if PI.debug then
    debug = 10
  else
    debug = 0
  end
elseif type(PI.debug) == "number" then
  debug = PI.debug
end

local rscale_x = scale_x / 100
local rscale_y = scale_y / 100

local function rotate_point(x, y, angle_rad)
    -- ( cos theta, -sin theta ) ( x )
    -- ( sin theta,  cos theta ) ( y )
    local cos_a = math.cos(angle_rad)
    local sin_a = math.sin(angle_rad)
    local rx = cos_a * x - sin_a * y
    local ry = sin_a * x + cos_a * y
    return rx, ry
end

local original_cx = obj.cx
local original_cy = obj.cy
local original_sx = obj.sx
local original_sy = obj.sy

obj.setoption("sampler", "dot")

local vanilla_cx = obj.w / 2
local vanilla_cy = obj.h / 2

local cx = vanilla_cx + center_x
local cy = vanilla_cy + center_y

local angle_rad = math.rad(angle_deg)

local left_top_x, left_top_y = rotate_point(-cx * rscale_x, -cy * rscale_y, angle_rad)
local right_top_x, right_top_y = rotate_point((obj.w - cx) * rscale_x, -cy * rscale_y, angle_rad)
local left_bottom_x, left_bottom_y = rotate_point(-cx * rscale_x, (obj.h - cy) * rscale_y, angle_rad)
local right_bottom_x, right_bottom_y = rotate_point((obj.w - cx) * rscale_x, (obj.h - cy) * rscale_y, angle_rad)
left_top_x = left_top_x + cx
left_top_y = left_top_y + cy
right_top_x = right_top_x + cx
right_top_y = right_top_y + cy
left_bottom_x = left_bottom_x + cx
left_bottom_y = left_bottom_y + cy
right_bottom_x = right_bottom_x + cx
right_bottom_y = right_bottom_y + cy

local min_x = math.min(left_top_x, right_top_x, left_bottom_x, right_bottom_x)
local max_x = math.max(left_top_x, right_top_x, left_bottom_x, right_bottom_x)
local min_y = math.min(left_top_y, right_top_y, left_bottom_y, right_bottom_y)
local max_y = math.max(left_top_y, right_top_y, left_bottom_y, right_bottom_y)

local transform_source
if debug > 0 then
  obj.setoption("drawtarget", "tempbuffer", math.ceil(obj.w), math.ceil(obj.h))
  obj.pixelshader("debug_grid", "tempbuffer", {}, {debug})
  obj.draw()
  obj.setoption("draw_state", false)
  obj.copybuffer("cache:debug_grid", "tempbuffer")
  transform_source = "cache:debug_grid"
else
  transform_source = "object"
end
obj.setoption("drawtarget", "tempbuffer", math.ceil(max_x) - math.floor(min_x), math.ceil(max_y) - math.floor(min_y))
obj.pixelshader("transform", "tempbuffer", transform_source, {
  math.floor(min_x),
  math.floor(min_y),
  obj.w,
  obj.h,
  cx,
  cy,
  rscale_x,
  rscale_y,
  angle_rad
}, "copy", "dot")
obj.load("tempbuffer")

local new_cx, new_cy = rotate_point(center_x * rscale_x, center_y * rscale_y, angle_rad)
obj.cx = original_cx + new_cx
obj.cy = original_cy + new_cy
