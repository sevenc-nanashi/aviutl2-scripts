--label:変形
--information:https://github.com/sevenc-nanashi/aviutl2-scripts/blob/main/scripts/%E3%83%89%E3%83%83%E3%83%88%E7%B5%B5%E5%A4%89%E5%BD%A2.anm2

-- ========================================================================================================================
-- ニアレストネイバー法で拡大縮小・回転・中心移動を行うスクリプト。
-- 標準の回転と違い、回転でも中間色が発生しません。
--
-- PI:
-- - scale_x: X拡大率（1.0で等倍）
-- - scale_y: Y拡大率（1.0で等倍）
-- - center_x: 中心X（ピクセル単位）
-- - center_y: 中心Y（ピクセル単位）
-- - angle_deg: 回転（度）
-- - debug: デバッググリッドの表示（0で非表示、正の値でグリッドサイズ）
--
-- https://aviutl2-scripts-download.sevenc7c.workers.dev/%E3%83%89%E3%83%83%E3%83%88%E7%B5%B5%E5%A4%89%E5%BD%A2.anm2
-- ========================================================================================================================

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

--group:回転,true

---$track:回転（度）
---min=-360
---max=360
---default=0
---step=0.1
local angle_deg = 0

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

if type(PI.scale_x) == "number" then
  scale_x = PI.scale_x * 100
end
if type(PI.scale_y) == "number" then
  scale_y = PI.scale_y * 100
end
if type(PI.center_x) == "number" then
  center_x = PI.center_x
end
if type(PI.center_y) == "number" then
  center_y = PI.center_y
end
if type(PI.angle_deg) == "number" then
  angle_deg = PI.angle_deg
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
