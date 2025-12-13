--label:変形
--information:https://github.com/sevenc-nanashi/aviutl2-scripts/blob/main/scripts/%E3%83%89%E3%83%83%E3%83%88%E7%B5%B5%E5%A4%89%E5%BD%A2.anm2

---$include "./readme.lua"


-- このスクリプトはcleanEdgeをベースに作成しました。
-- cleanEdgeの作者であるtorcado様に感謝いたします。（Great Appreciation to torcado, the author of cleanEdge.）
-- 以下はcleanEdgeのライセンス情報です。
-- ------------------------------------------------------------------------------------------------------------------------
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
-- ------------------------------------------------------------------------------------------------------------------------

--group:中心移動,true

---$track:中心X
---min=-5000
---max=5000
---step=0.01
local center_x = 0
---$track:中心Y
---min=-5000
---max=5000
---step=0.01
local center_y = 0

--group:拡大縮小,true

---$track:X拡大率
---min=1
---max=10000
---step=0.001
local scale_x = 100

---$track:Y拡大率
---min=1
---max=10000
---step=0.001
local scale_y = 100

--group:回転,true

---$track:回転（度）
---min=-360
---max=360
---step=0.1
local angle_deg = 0

--group:発展補間設定,true

---$check:発展補間
local enable_cleanedge = false

---$track:線の太さ
---min=0
---max=4
---step=0.01
local line_width = 1

---$select:斜め補間
---1:1のみ=0
---1:1 + 1:2=1
---1:1 + 1:2（補正）=2
local slopes = 2

---$color:基準色
local highest_color = 0xffffff

---$track:補間閾値
---min=0
---max=255
---step=1
local similar_threshold = 16

--group:高度な設定,false
---$track:透明グリッド
---min=0
---max=1000
---step=1
local alpha_grid = 0

---$select:ピクセル補正
---中心移動式=1
---描画移動式=2
---サンプラー式=3
---オフ=0
local pixelsnap = 1

---$check:デバッグモード
local debug = false

---$value:PI
local PI = {}

--[[pixelshader@alpha_grid:
---$include "./alpha_grid.hlsl"
]]
--[[pixelshader@transform:
---$include "./transform.hlsl"
]]
--[[pixelshader@cleanedge_vanilla:
#define DEFINE_THIS_MACRO_IN_MAIN_LUA
#define ENTRYPOINT cleanedge_vanilla
---$include "./cleanedge.hlsl"
]]
--[[pixelshader@cleanedge_slope:
#define DEFINE_THIS_MACRO_IN_MAIN_LUA
#define ENABLE_SLOPE
#define ENTRYPOINT cleanedge_slope
---$include "./cleanedge.hlsl"
]]
--[[pixelshader@cleanedge_slope_cleanup:
#define DEFINE_THIS_MACRO_IN_MAIN_LUA
#define ENABLE_SLOPE
#define ENABLE_CLEANUP
#define ENTRYPOINT cleanedge_slope_cleanup
---$include "./cleanedge.hlsl"
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
if type(PI.angle_deg) == "number" then
  angle_deg = PI.angle_deg
end
if type(PI.enable_cleanedge) == "boolean" then
  enable_cleanedge = PI.enable_cleanedge
end
if type(PI.line_width) == "number" then
  line_width = PI.line_width
end
if type(PI.slopes) == "number" then
  slopes = PI.slopes
end
if type(PI.highest_color) == "number" then
  highest_color = PI.highest_color
end
if type(PI.similar_threshold) == "number" then
  similar_threshold = PI.similar_threshold
end
if type(PI.pixelsnap) == "number" then
  pixelsnap = PI.pixelsnap
end
if type(PI.debug) == "boolean" then
  debug = PI.debug
end
if type(PI.alpha_grid) == "boolean" then
  if PI.alpha_grid then
    alpha_grid = 10
  else
    alpha_grid = 0
  end
elseif type(PI.alpha_grid) == "number" then
  alpha_grid = PI.alpha_grid
end

local function debug_dump_internal(o)
  if type(o) == 'table' then
    local s = '{ '
    local keys = {}
    local is_array = true
    local max_index = 0
    for k, v in pairs(o) do
      table.insert(keys, k)
      if type(k) ~= 'number' or k < 1 or math.floor(k) ~= k then
        is_array = false
      else
        if k > max_index then
          max_index = k
        end
      end
    end
    if is_array then
      table.sort(keys, function(a, b) return a < b end)
    else
      table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    end
    for i, k in ipairs(keys) do
      local v = o[k]
      if i > 1 then
        s = s .. ', '
      end
      if is_array then
        s = s .. debug_dump_internal(v)
      else
        s = s .. tostring(k) .. ' = ' .. debug_dump_internal(v)
      end
    end

    return s .. ' }'
  else
    return tostring(o)
  end
end
local function debug_dump(m, o)
  if debug then
    if o == nil then
      debug_print(m)
    else
      debug_print(m .. ": " .. debug_dump_internal(o))
    end
  end
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
debug_dump("coords", {
  left_top = {x = left_top_x, y = left_top_y},
  right_top = {x = right_top_x, y = right_top_y},
  left_bottom = {x = left_bottom_x, y = left_bottom_y},
  right_bottom = {x = right_bottom_x, y = right_bottom_y},
})

local min_x = math.min(left_top_x, right_top_x, left_bottom_x, right_bottom_x)
local max_x = math.max(left_top_x, right_top_x, left_bottom_x, right_bottom_x)
local min_y = math.min(left_top_y, right_top_y, left_bottom_y, right_bottom_y)
local max_y = math.max(left_top_y, right_top_y, left_bottom_y, right_bottom_y)

local transform_source
if alpha_grid > 0 then
  obj.setoption("drawtarget", "tempbuffer", math.ceil(obj.w), math.ceil(obj.h))
  obj.pixelshader("alpha_grid", "tempbuffer", {}, {alpha_grid})
  obj.draw()
  obj.setoption("draw_state", false)
  obj.copybuffer("cache:alpha_grid", "tempbuffer")
  transform_source = "cache:alpha_grid"
else
  transform_source = "object"
end

local new_w = math.ceil(max_x) - math.floor(min_x)
local new_h = math.ceil(max_y) - math.floor(min_y)
obj.setoption("drawtarget", "tempbuffer", new_w, new_h)

if enable_cleanedge then
  highest_r, highest_g, highest_b = RGB(highest_color)
  local args = {
    math.floor(min_x),
    math.floor(min_y),
    obj.w,
    obj.h,
    cx,
    cy,
    rscale_x,
    rscale_y,
    angle_rad,
    new_w,
    new_h,
    highest_r / 255,
    highest_g / 255,
    highest_b / 255,
    similar_threshold / 255,
    line_width,
  }
  local shader_name
  if slopes == 0 then
    shader_name = "cleanedge_vanilla"
  elseif slopes == 1 then
    shader_name = "cleanedge_slope"
  else
    shader_name = "cleanedge_slope_cleanup"
  end
  debug_dump("shader_name", shader_name)
  debug_dump("cleanedge args", args)
  obj.pixelshader(shader_name, "tempbuffer", transform_source, args, "copy", "dot")
else
  local args = {
    math.floor(min_x),
    math.floor(min_y),
    obj.w,
    obj.h,
    cx,
    cy,
    rscale_x,
    rscale_y,
    angle_rad
  }
  debug_dump("transform args", args)
  obj.pixelshader("transform", "tempbuffer", transform_source, args, "copy", "dot")
end

local original_obj = {}
for k, v in pairs(obj) do
  original_obj[k] = v
end

obj.load("tempbuffer")

local new_cx, new_cy = rotate_point(center_x * rscale_x, center_y * rscale_y, angle_rad)
obj.ox = original_obj.ox
obj.oy = original_obj.oy
obj.cx = original_obj.cx + new_cx
obj.cy = original_obj.cy + new_cy

if pixelsnap == 1 or pixelsnap == 2 then
  local left_top_x = original_obj.screen_w / 2 + original_obj.x + original_obj.ox - (new_w / 2 + obj.cx)
  local left_top_y = original_obj.screen_h / 2 + original_obj.y + original_obj.oy - (new_h / 2 + obj.cy)
  local snapped_left_top_x = math.floor(left_top_x + 0.5)
  local snapped_left_top_y = math.floor(left_top_y + 0.5)

  debug_dump(("left_top_x: %.2f -> %d"):format(left_top_x, snapped_left_top_x))
  debug_dump(("left_top_y: %.2f -> %d"):format(left_top_y, snapped_left_top_y))
  if pixelsnap == 1 then
    obj.cx = obj.cx - (snapped_left_top_x - left_top_x)
    obj.cy = obj.cy - (snapped_left_top_y - left_top_y)
  elseif pixelsnap == 2 then
    obj.ox = obj.ox + (snapped_left_top_x - left_top_x)
    obj.oy = obj.oy + (snapped_left_top_y - left_top_y)
  end
elseif pixelsnap == 3 then
  obj.setoption("sampler", "dot")
end
