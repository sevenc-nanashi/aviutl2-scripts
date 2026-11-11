--label:配置

---$include "./readme.lua"
---$select:位置
---ue=1
---naka=2
---shita=3
local position = 2
---$select:大きさ
---small=1
---medium=2
---big=3
local size = 2

---$string:コマンド
local commands = ""

---$select:画面サイズ指定
---スクリーン=1
---アンカー=2
local screen = 1

---$value:画面サイズ
local pos = { -160, -120, 160, 120 }

--hide@pos:screen==1

---$track:表示秒数
---min=0
---max=20
---step=0.01
---zero_label=自動
local duration = 0

---$track:段
---min=1
---max=16
---step=1
local row = 1

---$check:黄枠表示
local show_frame = false

---$track:枠線補正px
---min=0
---max=100
---step=1
local frame_add = 0

---$track:テキスト行数
---min=0
---max=64
---step=1
---zero_label=自動
local line = 0

---$check:画面内クリッピング
local clip = false

---$value:PI
local PI = {}

if type(PI.position) == "number" then
  position = PI.position
end
if type(PI.size) == "number" then
  size = PI.size
end
if type(PI.screen) == "number" then
  screen = PI.screen
end
if type(PI.pos) == "table" then
  pos = PI.pos
end
if type(PI.row) == "number" then
  row = PI.row
end
if type(PI.show_frame) == "boolean" then
  show_frame = PI.show_frame
end
if type(PI.frame_add) == "number" then
  frame_add = PI.frame_add
end
if type(PI.commands) == "string" then
  commands = PI.commands
end
if type(PI.duration) == "number" then
  duration = PI.duration
end
if type(PI.line) == "number" then
  line = PI.line
end
if type(PI.clip) == "boolean" then
  clip = PI.clip
end

local w, h = obj.getpixel()

local cache_namespace = "cache:niconico_comment"

-- 表示時間オーバー
if duration == 0 then
  if position == 1 or position == 3 then
    duration = 3
  else
    duration = 5
  end
end
if obj.time > duration then
  obj.setoption("draw_state", true)
  return
end

-- コマンド判定

local comment_siz, comment_pos, comment_col
local cmd_siz = { small = 1, medium = 2, big = 3 }
local cmd_pos = { ue = 1, naka = 2, shita = 3 }
local cmd_col = {
  whilte = 0xffffff,
  red = 0xff0000,
  pink = 0xff8080,
  orange = 0xffcc00,
  yellow = 0xffff00,
  green = 0x00ff00,
  cyan = 0x00ffff,
  blue = 0x0000ff,
  purple = 0xc000ff,
  black = 0,
  niconicowhite = 0xcccc99,
  white2 = 0xcccc99,
  truered = 0xcc0033,
  red2 = 0xcc0033,
  pink2 = 0xff33cc,
  passionorange = 0xff6600,
  orange2 = 0xff6600,
  madyellow = 0x999900,
  yellow2 = 0x999900,
  elementalgreen = 0x00cc66,
  green2 = 0x00cc66,
  cyan2 = 0x00cccc,
  marineblue = 0x3399ff,
  blue2 = 0x3399ff,
  nobleviolet = 0x6633cc,
  purple2 = 0x6633cc,
  black2 = 0x666666,
}
local cmd_other = { full = 0, ender = 0 }
for word in string.gmatch(commands, "%S+") do
  if comment_pos == nil then
    comment_pos = cmd_pos[word]
  end
  if comment_siz == nil then
    comment_siz = cmd_siz[word]
  end
  if comment_col == nil then
    comment_col = cmd_col[word] or tonumber(string.match(word, "^#(%x%x%x%x%x%x)$") or "NIL", 16)
  end
  if cmd_other[word] then
    cmd_other[word] = 1
  end
end

if comment_pos == nil then
  comment_pos = position
end
if comment_siz == nil then
  comment_siz = size
end
if comment_col then
  obj.effect("単色化", "強さ", 100, "輝度を保持する", 0, "色", comment_col)
end

if line == 0 then
  local text = obj.getvalue("テキスト", "テキスト")
  if not text then
    error("テキストが取得できませんでした")
  end
  line = 1
  for _ in string.gmatch(text, "\\n") do
    line = line + 1
  end
end

-----------------------------------
-- 画面サイズ計算

local ofsx, ofsy = 0, 0
if screen == 2 then
  ofsx = ofsx - (pos[1] + pos[3]) / 2
  ofsy = ofsy - (pos[2] + pos[4]) / 2
  obj.setanchor("pos", 2, "offset", obj.cx, obj.cy)
end
local screen_size = { { obj.screen_w, obj.screen_h }, { math.abs(pos[1] - pos[3]), math.abs(pos[2] - pos[4]) } }
local screen_x, screen_y = screen_size[math.floor(screen)][1], screen_size[math.floor(screen)][2]
obj.setanchor({
  -screen_x / 2 - ofsx,
  -screen_y / 2 - ofsy,
  screen_x / 2 - ofsx,
  -screen_y / 2 - ofsy,
  screen_x / 2 - ofsx,
  screen_y / 2 - ofsy,
  -screen_x / 2 - ofsx,
  screen_y / 2 - ofsy,
}, 4, "loop", "offset", obj.cx, obj.cy)

-- コメント画像生成

--コメント1行分の高さ(px)
local row_size
if comment_siz == 1 then
  row_size = (line < 7 or cmd_other.ender == 1) and 30 or 18.8 --720p画面での実測値（ガバガバ）
elseif comment_siz == 2 then
  row_size = (line < 5 or cmd_other.ender == 1) and 52 or 28.2
elseif comment_siz == 3 then
  row_size = (line < 3 or cmd_other.ender == 1) and 82 or 44.6
end
row_size = row_size * line * screen_y / 720

if comment_pos ~= 2 and screen_y * (cmd_other.full == 0 and 4 / 3 or 16 / 9) * h < w * row_size * line then
  row_size = screen_y * (cmd_other.full == 0 and 4 / 3 or 16 / 9) * h / w
end

obj.effect("リサイズ", "拡大率", row_size * 100 / h)
obj.effect("領域拡張", "上", 5 * screen_y / 720, "下", 5 * screen_y / 720)
obj.copybuffer(cache_namespace .. "TEXT", "object")
w, h = obj.getpixel()
local frame = screen_y / 360 --黄枠の太さ（計算式は適当）
obj.setoption("drawtarget", "tempbuffer", w + math.ceil(frame), h + math.ceil(frame))

obj.effect("単色化", "強さ", 100, "輝度を保持する", 0, "色", comment_col == 0 and 0xffffff or 0)
obj.setoption("blend", "alpha_max")
obj.draw(-frame, -frame, 0, 1, 0.5)
obj.draw(-frame, frame, 0, 1, 0.5)
obj.draw(frame, frame, 0, 1, 0.5)
obj.draw(frame, -frame, 0, 1, 0.5)
obj.draw(-frame * 1.4, 0, 0, 1, 0.5)
obj.draw(0, frame * 1.4, 0, 1, 0.5)
obj.draw(frame * 1.4, 0, 0, 1, 0.5)
obj.draw(0, -frame * 1.4, 0, 1, 0.5)
obj.setoption("blend", "none")
obj.copybuffer("object", cache_namespace .. "TEXT")
obj.draw()

frame = frame + frame_add
if show_frame then
  obj.copybuffer(cache_namespace .. "TEXT", "tempbuffer")
  obj.setoption("drawtarget", "tempbuffer", w + math.ceil(frame), h + math.ceil(frame))
  obj.drawpoly({
    {
      -(w + frame) / 2,
      -(h + frame) / 2,
      0,
      -(w - frame) / 2,
      -(h + frame) / 2,
      0,
      -(w - frame) / 2,
      (h + frame) / 2,
      0,
      -(w + frame) / 2,
      (h + frame) / 2,
      0,
      1.0,
      1.0,
      0.0,
      1.0,
      1.0,
      1.0,
      0.0,
      1.0,
      1.0,
      1.0,
      0.0,
      1.0,
      1.0,
      1.0,
      0.0,
      1.0,
    },
    {
      (w + frame) / 2,
      -(h + frame) / 2,
      0,
      (w - frame) / 2,
      -(h + frame) / 2,
      0,
      (w - frame) / 2,
      (h + frame) / 2,
      0,
      (w + frame) / 2,
      (h + frame) / 2,
      0,
      1.0,
      1.0,
      0.0,
      1.0,
      1.0,
      1.0,
      0.0,
      1.0,
      1.0,
      1.0,
      0.0,
      1.0,
      1.0,
      1.0,
      0.0,
      1.0,
    },
    {
      -(w + frame) / 2,
      (h + frame) / 2,
      0,
      (w + frame) / 2,
      (h + frame) / 2,
      0,
      (w + frame) / 2,
      (h - frame) / 2,
      0,
      -(w + frame) / 2,
      (h - frame) / 2,
      0,
      1.0,
      1.0,
      0.0,
      1.0,
      1.0,
      1.0,
      0.0,
      1.0,
      1.0,
      1.0,
      0.0,
      1.0,
      1.0,
      1.0,
      0.0,
      1.0,
    },
    {
      -(w + frame) / 2,
      -(h + frame) / 2,
      0,
      (w + frame) / 2,
      -(h + frame) / 2,
      0,
      (w + frame) / 2,
      -(h - frame) / 2,
      0,
      -(w + frame) / 2,
      -(h - frame) / 2,
      0,
      1.0,
      1.0,
      0.0,
      1.0,
      1.0,
      1.0,
      0.0,
      1.0,
      1.0,
      1.0,
      0.0,
      1.0,
      1.0,
      1.0,
      0.0,
      1.0,
    },
  })
  obj.copybuffer("object", cache_namespace .. "TEXT")
  obj.draw()
end

-----------------------------------
-- コメント描画

obj.load("tempbuffer")
if comment_pos == 1 then
  obj.ox = obj.ox - ofsx
  obj.oy = obj.oy + (frame / 2 - screen_y + h) / 2 + h * math.floor(row - 1) / line - ofsy
elseif comment_pos == 2 then
  obj.ox = screen_x / 2 + w / 2 + obj.ox - ofsx - (w + screen_x) * obj.time / duration
  obj.oy = obj.oy + (frame / 2 - screen_y + h) / 2 + h * math.floor(row - 1) / line - ofsy
  if clip then
    obj.effect(
      "クリッピング",
      "中心の位置を変更",
      0,
      "右",
      math.max(0, math.floor(-screen_x / 2 + w / 2 + obj.ox + ofsx)),
      "左",
      math.max(0, math.floor(-screen_x / 2 + w / 2 - obj.ox - ofsx))
    )
  end
elseif comment_pos == 3 then
  obj.ox = obj.ox - ofsx
  obj.oy = -obj.oy - (frame / 2 - screen_y + h) / 2 - h * math.floor(row - 1) / line - ofsy
end
