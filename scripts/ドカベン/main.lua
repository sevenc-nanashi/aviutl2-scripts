--label:アニメーション効果

---$include "./readme.lua"

---$track:再生速度
---min=0
---max=800
---step=1
---zero_label=固定
local speed = 100

---$check:自動で倒れる
local auto_fall = false

---$track:直立時間
---min=0
---max=800
---step=1
local upright = -1
--hide@upright:auto_fall=0

---$track:Yオフセット
---min=0
---max=100
---step=0.1
local y_offset = 0

---$check:コマ落ち
local drop_frame = true

---$value:PI
local PI = {}

if type(PI.speed) == "number" then
  speed = PI.speed
end
if type(PI.auto_fall) == "boolean" then
  auto_fall = PI.auto_fall
end
if type(PI.upright) == "number" then
  upright = PI.upright
end
if type(PI.y_offset) == "number" then
  y_offset = PI.y_offset
end
if type(PI.drop_frame) == "boolean" then
  drop_frame = PI.drop_frame
end

local divisions_override = nil
if type(PI.divisions_override) == "number" then
  divisions_override = PI.divisions_override
end

local time
if speed == 0 then
  time = math.pi / 2
else
  time = obj.time * speed / 100
end
if drop_frame then
  time = time - time % 0.12
end
if auto_fall then
  time = time % (math.pi + upright / obj.framerate)
else
  time = math.min(time, math.pi / 2)
end
if time > math.pi / 2 then
  time = math.min(math.pi / 2, math.pi + upright / obj.framerate - time)
end

local s, c = 1 / 2 - math.sin(time), 1 / 2 - math.cos(time) / 8
local w, h = obj.getpixel()
obj.setoption("drawtarget", "tempbuffer", w, h)
local divisions = divisions_override or math.min(math.max(math.floor(obj.w / 32), 1), 32)

local polygons = {}
for i = 0, divisions - 1 do
  local left, right = i / divisions, (i + 1) / divisions
  table.insert(polygons, {
    (left * 2 - 1) * obj.w * c,
    (obj.h - y_offset) * s - y_offset / 2,
    0,
    (right * 2 - 1) * obj.w * c,
    (obj.h - y_offset) * s - y_offset / 2,
    0,
    (right - 1 / 2) * obj.w,
    obj.h / 2 - y_offset * (1 / 2 + s),
    0,
    (left - 1 / 2) * obj.w,
    obj.h / 2 - y_offset * (1 / 2 + s),
    0,
    left * obj.w,
    0,
    right * obj.w,
    0,
    right * obj.w,
    obj.h,
    left * obj.w,
    obj.h,
  })
end
obj.drawpoly(polygons)
obj.load("tempbuffer")
