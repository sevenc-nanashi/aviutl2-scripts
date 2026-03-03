--label:画面効果
--information:https://github.com/sevenc-nanashi/aviutl2-scripts/blob/main/scripts/%E3%83%89%E3%83%83%E3%83%88%E7%B5%B5%E5%A4%89%E5%BD%A2.anm2

---$include "./readme.lua"

---$track:幅
---min=0
---max=2048
---step=1
local width = 100

---$track:高さ
---min=0
---max=2048
---step=1
local height = 100

---$track:線の長さ
---min=0
---max=1000
---step=1
local line_length = 150

---$track:線の太さ
---min=1
---max=1000
---step=1
local line_thickness = 5

---$color:線の色
local line_color = 0xFFFFFF

---$select:サイズ指定
---余白指定=1
---絶対指定=2
local size_specifier = 1

---$check:デバッグモード
local debug = false

---$value:PI
local PI = {}

--[[pixelshader@frame:
---$include "./frame.hlsl"
]]

-- PIからパラメータを取得
if type(PI.width) == "number" then
  width = PI.width
end
if type(PI.height) == "number" then
  height = PI.height
end
if type(PI.line_length) == "number" then
  line_length = PI.line_size
end
if type(PI.line_color) == "number" then
  line_color = PI.line_color
end
if type(PI.size_specifier) == "number" then
  size_specifier = PI.size_specifier
end
if type(PI.debug) == "boolean" then
  debug = PI.debug
end

-- デバッグ用関数
local function debug_dump_internal(o)
  if type(o) == "table" then
    local s = "{ "
    local keys = {}
    local is_array = true
    local max_index = 0
    for k, _ in pairs(o) do
      table.insert(keys, k)
      if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
        is_array = false
      else
        if k > max_index then
          max_index = k
        end
      end
    end
    if is_array then
      table.sort(keys, function(a, b)
        return a < b
      end)
    else
      table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
      end)
    end
    for i, k in ipairs(keys) do
      local v = o[k]
      if i > 1 then
        s = s .. ", "
      end
      if is_array then
        s = s .. debug_dump_internal(v)
      else
        s = s .. tostring(k) .. " = " .. debug_dump_internal(v)
      end
    end

    return s .. " }"
  else
    return tostring(o)
  end
end
local function debug_dump(m, o)
  if debug then
    if o == nil then
      debug_print(debug_dump_internal(m))
    else
      debug_print(m .. ": " .. debug_dump_internal(o))
    end
  end
end

-- 図形オブジェクトでレンダリングするのはしんどいので、ピクセルシェーダーで描画する

local resolved_width, resolved_height
if size_specifier == 1 then
  -- 余白指定
  resolved_width = obj.screen_w - width * 2
  resolved_height = obj.screen_h - height * 2
else
  -- 絶対指定
  resolved_width = width
  resolved_height = height
end

local red, green, blue = RGB(line_color)

obj.setoption("drawtarget", "tempbuffer", resolved_width, resolved_height)
obj.pixelshader("frame", "tempbuffer", {}, {
  line_length,
  line_thickness,
  resolved_width,
  resolved_height,
  red / 255,
  green / 255,
  blue / 255,
})
obj.load("tempbuffer")


--vim: set ft=lua:
