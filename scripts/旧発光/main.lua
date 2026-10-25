--filter
--label:光効果

---$include "./readme.lua"

---$track:強さ
---min=0
---max=200
---step=0.1
local strength = 100
---$track:拡散
---min=10
---max=800
local diffusion = 250
---$track:しきい値
---min=0
---max=200
---step=0.1
local threshold = 80
---$track:拡散速度
---min=0
---max=60
local speed = 0
---$color:光色
local light_color = nil
---$check:サイズ固定
local fixed_size = false

---$value:PI
local PI = {}

--[[pixelshader@legacy_glow_extract:
---$include "./light.hlsl"
]]
--[[computeshader@legacy_glow_blur:
---$include "./light.hlsl"
]]
--[[pixelshader@legacy_glow_add:
---$include "./light.hlsl"
]]
--[[pixelshader@legacy_glow_finish:
---$include "./light.hlsl"
]]

if type(PI.strength) == "number" then
  strength = PI.strength
end
if type(PI.diffusion) == "number" then
  diffusion = PI.diffusion
end
if type(PI.threshold) == "number" then
  threshold = PI.threshold
end
if type(PI.speed) == "number" then
  speed = PI.speed
end
if type(PI.light_color) == "number" then
  light_color = PI.light_color
end
if PI.light_color == false then
  light_color = nil
end
if type(PI.fixed_size) == "boolean" then
  fixed_size = PI.fixed_size
end

if strength <= 0 or obj.w == 0 or obj.h == 0 then
  return
end

local is_filter = obj.getinfo("filter")
local radii = {}
local padding = 0
for i = 0, 5 do
  radii[i + 1] = math.floor(2 * (diffusion / 2) ^ (i / 5) + 0.5)
  padding = padding + radii[i + 1]
end
if fixed_size or is_filter then
  padding = 0
end
local width, height = obj.w + padding * 2, obj.h + padding * 2
assert(
  width <= 16384 and height <= 16384,
  "旧発光: 画像が大きすぎます。拡散を下げるかサイズ固定を有効にしてください。"
)
local prefix = "cache:legacy_glow_" .. obj.effect_id .. "_"
local seed, temporary, total = prefix .. "seed", prefix .. "temporary", prefix .. "total"
for _, buffer in ipairs({ seed, temporary, total }) do
  obj.clearbuffer(buffer, width, height)
end
local red, green, blue = 0, 0, 0
if light_color ~= nil then
  red, green, blue = RGB(light_color)
end
local params = {
  strength / 100,
  threshold / 100,
  256 * math.log(1 + speed / 1000) / math.log(2),
  padding,
  red / 255,
  green / 255,
  blue / 255,
  light_color ~= nil and 1 or 0,
  0,
  0,
  0,
  is_filter and 1 or 0,
}
obj.pixelshader("legacy_glow_extract", seed, "object", params)
for i, radius in ipairs(radii) do
  params[9] = math.max(0, math.min(radius, math.floor(height / 2) - 1))
  params[10] = 1
  obj.computeshader("legacy_glow_blur", temporary, seed, params, math.ceil(width / 64), 1, 1)
  params[9] = math.max(0, math.min(radius, math.floor(width / 2) - 1))
  params[10] = 0
  obj.computeshader("legacy_glow_blur", seed, temporary, params, math.ceil(height / 64), 1, 1)
  params[11] = i == 1 and 1 or 0
  obj.pixelshader("legacy_glow_add", total, { seed, total, "object" }, params)
end
obj.pixelshader("legacy_glow_finish", temporary, { total, "object" }, params)
obj.copybuffer("object", temporary)
