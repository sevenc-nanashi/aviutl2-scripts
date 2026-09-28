--label:加工

---$include "./readme.lua"
---$include "./license.lua"

---$track:α閾値
---min=1
---max=254
---step=1
local threshold = 206

---$track:幅
---min=0
---max=150
---step=0.1
local width = 20

---$track:角度
---min=-360
---max=360
---step=0.1
local angle = 60

---$track:高度
---min=0
---max=90
---step=0.1
local elevation = 0

---$select:形状
---ベベル（外側）=0
---ベベル（内側）=1
---エンボス=2
---ピローエンボス=3
local shape = 1

---$select:出力
---通常合成=0
---直接描画=1
---ハイライトのみ=2
---シャドウのみ=3
local output = 0

---$track:ぼかし
---min=0
---max=100
---step=0.1
local blur = 0

---$track:参照輪郭ぼかし
---min=0
---max=100
---step=0.1
local preblur = 2

--group:ハイライト
---$color:ハイライト::色
local highlight_color = 0xFFFFFF

---$select:ハイライト::合成モード
---通常=0
---加算=1
---減算=2
---乗算=3
---スクリーン=4
---オーバーレイ=5
---比較（明）=6
---比較（暗）=7
---輝度=8
---色差=9
---陰影=10
---明暗=11
---差分=12
local highlight_blend = 4

---$track:ハイライト::不透明度
---min=0
---max=100
---step=0.1
local highlight_opacity = 100

--group:シャドウ
---$color:シャドウ::色
local shadow_color = 0x000000

---$select:シャドウ::合成モード
---通常=0
---加算=1
---減算=2
---乗算=3
---スクリーン=4
---オーバーレイ=5
---比較（明）=6
---比較（暗）=7
---輝度=8
---色差=9
---陰影=10
---明暗=11
---差分=12
local shadow_blend = 3

---$track:シャドウ::不透明度
---min=0
---max=100
---step=0.1
local shadow_opacity = 100

--group
---$color:背景色
local background_color = 0x808080

---$value:PI
local PI = {}

--[[pixelshader@bevel_seed:
---$include "./bevel.hlsl"
]]
--[[pixelshader@bevel_jump:
---$include "./bevel.hlsl"
]]
--[[pixelshader@bevel_shade:
---$include "./bevel.hlsl"
]]
--[[pixelshader@bevel_layer:
---$include "./bevel.hlsl"
]]
--[[pixelshader@bevel_base:
---$include "./bevel.hlsl"
]]
--[[pixelshader@bevel_finish:
---$include "./bevel.hlsl"
]]

-- PIからパラメータを取得
if type(PI.threshold) == "number" then
  threshold = PI.threshold
end
if type(PI.width) == "number" then
  width = PI.width
end
if type(PI.angle) == "number" then
  angle = PI.angle
end
if type(PI.elevation) == "number" then
  elevation = PI.elevation
end
if type(PI.shape) == "number" then
  shape = PI.shape
end
if type(PI.output) == "number" then
  output = PI.output
end
if type(PI.blur) == "number" then
  blur = PI.blur
end
if type(PI.preblur) == "number" then
  preblur = PI.preblur
end
if type(PI.highlight_color) == "number" then
  highlight_color = PI.highlight_color
end
if type(PI.highlight_blend) == "number" then
  highlight_blend = PI.highlight_blend
end
if type(PI.highlight_opacity) == "number" then
  highlight_opacity = PI.highlight_opacity
end
if type(PI.shadow_color) == "number" then
  shadow_color = PI.shadow_color
end
if type(PI.shadow_blend) == "number" then
  shadow_blend = PI.shadow_blend
end
if type(PI.shadow_opacity) == "number" then
  shadow_opacity = PI.shadow_opacity
end
if type(PI.background_color) == "number" then
  background_color = PI.background_color
end

if width <= 0 or obj.w == 0 or obj.h == 0 then
  return
end

local bevel_width = shape >= 2 and width / 2 or width
local margin = math.ceil(preblur + 1 + (shape == 1 and 0 or bevel_width) + blur)
obj.effect("領域拡張", "上", margin, "下", margin, "左", margin, "右", margin)

local w, h = obj.w, obj.h
local prefix = "cache:bevel:" .. obj.effect_id .. ":" .. obj.id .. ":" .. obj.index .. ":"
local original, contour = prefix .. "original", prefix .. "contour"
local first, second, field = prefix .. "first", prefix .. "second", prefix .. "field"
obj.copybuffer(original, "object")

local function apply_blur(amount)
  if amount > 0 then
    obj.effect("ぼかし", "範囲", amount, "サイズ固定", 1)
  end
end

apply_blur(preblur)
obj.copybuffer(contour, "object")
for _, buffer in ipairs({ first, second, field }) do
  obj.clearbuffer(buffer, w, h)
end

local params = {
  threshold / 255,
  bevel_width,
  0,
  shape,
  math.cos(math.rad(angle)),
  -math.sin(math.rad(angle)),
  math.cos(math.rad(elevation)),
  output,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
}
obj.pixelshader("bevel_seed", first, contour, params)

local step = 1
while step < bevel_width + 2 do
  step = step * 2
end
while step >= 1 do
  params[3] = step
  obj.pixelshader("bevel_jump", second, first, params)
  first, second = second, first
  step = step / 2
end
params[3] = 1
obj.pixelshader("bevel_jump", second, first, params)
obj.pixelshader("bevel_shade", field, { second, contour }, params)
-- Distance propagation is finished; reuse its two buffers for the output layers.
local highlight, shadow = first, second

local function set_color(color)
  local r, g, b = RGB(color)
  params[9], params[10], params[11] = r / 255, g / 255, b / 255
end

local function make_layer(buffer, color, is_shadow, opacity)
  set_color(color)
  params[12], params[13] = is_shadow, opacity / 100
  obj.pixelshader("bevel_layer", "object", { field, original }, params)
  apply_blur(blur)
  obj.copybuffer(buffer, "object")
end

if output ~= 3 then
  make_layer(highlight, highlight_color, 0, highlight_opacity)
end
if output ~= 2 then
  make_layer(shadow, shadow_color, 1, shadow_opacity)
end
if output >= 2 then
  return
end

local blend, target = obj.getoption("blend"), obj.getoption("drawtarget")
if output == 1 then
  local saved = {}
  for _, key in ipairs({ "ox", "oy", "oz", "rx", "ry", "rz", "cx", "cy", "cz", "sx", "sy", "sz", "alpha" }) do
    saved[key] = obj[key]
  end
  obj.setoption("drawtarget", "framebuffer")
  for _, layer in ipairs({ { original, blend }, { highlight, highlight_blend }, { shadow, shadow_blend } }) do
    for key, value in pairs(saved) do
      obj[key] = value
    end
    obj.copybuffer("object", layer[1])
    obj.setoption("blend", layer[2])
    obj.effect()
    obj.draw()
  end
  for key, value in pairs(saved) do
    obj[key] = value
  end
else
  set_color(background_color)
  obj.clearbuffer("tempbuffer", w, h)
  obj.pixelshader("bevel_base", "tempbuffer", original, params)
  obj.setoption("drawtarget", "tempbuffer")
  for _, layer in ipairs({ { highlight, highlight_blend }, { shadow, shadow_blend } }) do
    obj.copybuffer("object", layer[1])
    obj.setoption("blend", layer[2])
    obj.draw(0, 0, 0, 1, 1)
  end
  obj.pixelshader("bevel_finish", "object", { "tempbuffer", original, field }, params)
end
obj.setoption("blend", blend)
obj.setoption("drawtarget", target)
