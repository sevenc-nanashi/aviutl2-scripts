--label:変形
--information:https://github.com/sevenc-nanashi/aviutl2-scripts/blob/main/scripts/%E3%83%89%E3%83%83%E3%83%88%E7%B5%B5%E5%A4%89%E5%BD%A2.anm2

---$include "./readme.lua"

---$track:目標幅
---min=0
---max=5000
---step=1
local target_width = 100
---$track:目標高さ
---min=0
---max=5000
---step=1
local target_height = 100

---$select:モード
---下限指定=0
---上限指定=1
---幅指定=2
---高さ指定=3
local mode = 0

--group:高度な設定,false
---$check:デバッグモード
local debug = false

---$value:PI
local PI = {}

-- PIからパラメータを取得
if type(PI.target_width) == "number" then
  target_width = PI.target_width
end
if type(PI.target_height) == "number" then
  target_height = PI.target_height
end
if type(PI.mode) == "number" then
  mode = PI.mode
end
if type(PI.debug) == "boolean" then
  debug = PI.debug
end

local current_width = obj.w * obj.sx
local current_height = obj.h * obj.sy
local aspect_ratio = current_width / current_height

local real_width, real_height

if mode == 0 then
  -- 下限指定
  if target_width / aspect_ratio >= target_height then
    real_width = target_width
    real_height = target_width / aspect_ratio
  else
    real_width = target_height * aspect_ratio
    real_height = target_height
  end
elseif mode == 1 then
  -- 上限指定
  if target_width / aspect_ratio <= target_height then
    real_width = target_width
    real_height = target_width / aspect_ratio
  else
    real_width = target_height * aspect_ratio
    real_height = target_height
  end
elseif mode == 2 then
  -- 幅指定
  real_width = target_width
  real_height = target_width / aspect_ratio
elseif mode == 3 then
  -- 高さ指定
  real_width = target_height * aspect_ratio
  real_height = target_height
end

if debug then
  debug_print(string.format("original: width=%.2f, height=%.2f", current_width, current_height))
  debug_print(string.format("target: width=%.2f, height=%.2f", target_width, target_height))
  debug_print(string.format("real: width=%.2f, height=%.2f", real_width, real_height))

  debug_print(string.format("sx: %.4f -> %.4f", obj.sx, obj.sx * (real_width / current_width)))
  debug_print(string.format("sy: %.4f -> %.4f", obj.sy, obj.sy * (real_height / current_height)))
end

obj.sx = obj.sx * (real_width / current_width)
obj.sy = obj.sy * (real_height / current_height)
--vim: set ft=lua:
