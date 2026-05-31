--label:画面効果
--information:https://github.com/sevenc-nanashi/aviutl2-scripts/blob/main/scripts/CRT%E3%83%87%E3%82%A3%E3%82%B9%E3%83%97%E3%83%AC%E3%82%A4.anm2
--filter

---$include "./readme.lua"

---$track:水平ブラー
---min=0
---max=1.0
---step=0.01
local horizontal_blur = 0.5

---$track:RGB%
---min=0
---max=100
---step=0.1
local rgb_percent = 100

---$track:ピクセルサイズ
---min=1.0
---max=50.0
---step=0.1
local pixel_size = 1.5

---$track:減衰
---min=0.01
---max=10.0
---step=0.01
local decay = 9.0

---$track:スローモーション
---min=0.1
---max=1000.0
---step=0.1
local slowmotion = 1.0

---$check:プログレッシブ
local use_progressive = false

---$value:PI
local PI = {}

--[[pixelshader@crt_display:
---$include "./crt_display.hlsl"
]]

-- PIからパラメータを取得
if type(PI.horizontal_blur) == "number" then
  horizontal_blur = PI.horizontal_blur
end
if type(PI.rgb_percent) == "number" then
  rgb_percent = PI.rgb_percent
end
if type(PI.pixel_size) == "number" then
  pixel_size = PI.pixel_size
end
if type(PI.decay) == "number" then
  decay = PI.decay
end
if type(PI.slowmotion) == "number" then
  slowmotion = PI.slowmotion
end
if type(PI.use_progressive) == "boolean" then
  use_progressive = PI.use_progressive
end

obj.pixelshader("crt_display", "object", "object", {
  obj.time,
  horizontal_blur,
  rgb_percent,
  pixel_size,
  decay,
  slowmotion,
  use_progressive and 1 or 0,
})
