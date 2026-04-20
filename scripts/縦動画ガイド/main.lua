--label:画面効果
--information:https://aviutl2-scripts-download.sevenc7c.workers.dev/%E7%B8%A6%E5%8B%95%E7%94%BB%E3%82%AC%E3%82%A4%E3%83%89.obj2

---$include "./readme.lua"

---$select:デバイス
---iPhone 16（iOS 26）=1
---iPad mini（iPadOS 26）=2
local device = 1

---$color:色
local color = 0xff0000

---$check:ピン留め動画
local show_forward = true

---$check:タグ
local show_tags = true

---$track:投稿者名の幅
---min=64
---max=640
---step=1
local author_name_width = 160

---$track:左右線の幅
---min=0
---max=640
---step=1
local side_line_width = 64

---$check:出力時にも表示
local show_on_output = false

---$value:PI
local PI = {}

---@class Rectangle
---@field x number
---@field y number
---@field width number
---@field height number
---@field radius number

---@class Layout
---@field width number 画面幅
---@field height number 画面高さ
---@field footer_height number 下のバーの高さ
---@field screen_radius number 画面の角の半径
---@field padding_x number 画面の左右の余白
---@field comment_padding_y number コメント欄と下のバーの間隔
---@field comment_height number コメント欄の高さ
---@field tag_padding_y number タグ欄とコメント欄の間隔
---@field tag_height number タグ欄の高さ
---@field like_padding_y number いいねボタンとタグ欄の間隔
---@field like_size number いいねボタンのサイズ
---@field title_padding_y number タイトルとタグ欄の間隔
---@field title_height number タイトルの高さ
---@field author_padding_y number 投稿者アイコンとタイトルの間隔
---@field author_size number 投稿者アイコンのサイズ
---@field author_name_size number 投稿者名の高さ
---@field author_padding_x number 投稿者アイコンと投稿者名の間隔
---@field follow_width number フォローボタンの幅
---@field forward_width number ピン留め動画の幅
---@field forward_height number ピン留め動画の高さ
---@field forward_padding_y number ピン留め動画と投稿者アイコンの間隔
---@field forward_radius number ピン留め動画の角の半径
---@field toolbar_size number ツールバーのアイコンのサイズ
---@field toolbar_gap number ツールバーのアイコン同士の間隔
---@field toolbar_padding_y number ツールバーと画面上部の間隔
---@field notch Rectangle | nil ノッチの位置とサイズ。ノッチがない場合はnil

---@type table<integer, Layout>
local layouts = {
  -- NOTE: iPhone 16, iOS 26
  [1] = {
    width = 1179,
    height = 2556,
    footer_height = 273,
    screen_radius = 165,
    comment_padding_y = 47,
    padding_x = 47,
    comment_height = 100,
    tag_padding_y = 46,
    tag_height = 40,
    like_padding_y = 50,
    like_size = 165,
    author_size = 97,
    author_padding_x = 22,
    author_padding_y = 36,
    follow_width = 280,
    author_name_size = 40,
    title_height = 35,
    title_padding_y = 45,
    forward_width = 581,
    forward_height = 108,
    forward_padding_y = 36,
    forward_radius = 24,
    toolbar_size = 60,
    toolbar_gap = 90,
    toolbar_padding_y = 237,
    notch = {
      x = 1179 / 2 - 376 / 2,
      y = 34,
      width = 376,
      height = 110,
      radius = 55,
    },
  },
  [2] = {
    width = 1488,
    height = 2266,
    footer_height = 170,
    screen_radius = 20,
    padding_x = 31,
    comment_padding_y = 31,
    comment_height = 66,
    tag_padding_y = 31,
    tag_height = 24,
    like_padding_y = 35,
    like_size = 110,
    title_height = 26,
    title_padding_y = 31,
    author_size = 64,
    author_padding_x = 17,
    author_padding_y = 23,
    author_name_size = 25,
    follow_width = 184,
    forward_width = 381,
    forward_height = 72,
    forward_radius = 18,
    forward_padding_y = 24,
    toolbar_size = 40,
    toolbar_gap = 60,
    toolbar_padding_y = 104,
    notch = nil,
  },
}

if type(PI.device) == "number" then
  device = PI.device
end
if type(PI.color) == "number" then
  color = PI.color
end
if type(PI.show_forward) == "boolean" then
  show_forward = PI.show_forward
end
if type(PI.show_tags) == "boolean" then
  show_tags = PI.show_tags
end
if type(PI.author_name_width) == "number" then
  author_name_width = PI.author_name_width
end
if type(PI.side_line_width) == "number" then
  side_line_width = PI.side_line_width
end
if type(PI.show_on_output) == "boolean" then
  show_on_output = PI.show_on_output
end

if obj.getinfo("saving") and not show_on_output then
  return
end

---@param src table
---@return table
local function shallow_copy(src)
  local dst = {}
  for k, v in pairs(src) do
    dst[k] = v
  end
  return dst
end

---@type Layout
local layout = shallow_copy(layouts[device] or layouts[1])
if type(layout.notch) == "table" then
  layout.notch = shallow_copy(layout.notch)
end
if type(PI.layout) == "table" then
  for k, v in pairs(PI.layout) do
    layout[k] = v
  end
end

if not show_tags then
  layout.tag_height = 0
  layout.tag_padding_y = 0
end

---@type Rectangle[]
local rects = {}
if layout.notch then
  -- ノッチ
  table.insert(rects, layout.notch)
end

-- フッター
table.insert(rects, {
  x = 0,
  y = layout.height - layout.footer_height,
  width = layout.width,
  height = layout.footer_height,
  radius = 0,
})

-- コメント欄
table.insert(rects, {
  x = layout.padding_x,
  y = layout.height - layout.footer_height - layout.comment_padding_y - layout.comment_height,
  width = layout.width - layout.padding_x * 2,
  height = layout.comment_height,
  radius = layout.comment_height / 2,
})

if show_tags then
  -- タグ欄
  table.insert(rects, {
    x = layout.padding_x,
    y = layout.height
      - layout.footer_height
      - layout.comment_padding_y
      - layout.comment_height
      - layout.tag_padding_y
      - layout.tag_height,
    width = layout.width - layout.padding_x * 2,
    height = layout.tag_height,
    radius = layout.tag_height / 2,
  })
end

-- いいねボタン
table.insert(rects, {
  x = layout.width - layout.padding_x - layout.like_size,
  y = layout.height
    - layout.footer_height
    - layout.comment_padding_y
    - layout.comment_height
    - layout.tag_padding_y
    - layout.tag_height
    - layout.like_padding_y
    - layout.like_size,
  width = layout.like_size,
  height = layout.like_size,
  radius = layout.like_size / 2,
})

-- タイトル
table.insert(rects, {
  x = layout.padding_x,
  y = layout.height
    - layout.footer_height
    - layout.comment_padding_y
    - layout.comment_height
    - layout.tag_padding_y
    - layout.tag_height
    - layout.title_padding_y
    - layout.title_height,
  width = layout.width - layout.padding_x * 2 - layout.like_size - layout.padding_x,
  height = layout.title_height,
  radius = layout.title_height / 2,
})

-- 投稿者アイコン
table.insert(rects, {
  x = layout.padding_x,
  y = layout.height
    - layout.footer_height
    - layout.comment_padding_y
    - layout.comment_height
    - layout.tag_padding_y
    - layout.tag_height
    - layout.title_padding_y
    - layout.title_height
    - layout.author_padding_y
    - layout.author_size,
  width = layout.author_size,
  height = layout.author_size,
  radius = layout.author_size / 2,
})

-- 投稿者名
table.insert(rects, {
  x = layout.padding_x + layout.author_size + layout.author_padding_x,
  y = layout.height
    - layout.footer_height
    - layout.comment_padding_y
    - layout.comment_height
    - layout.tag_padding_y
    - layout.tag_height
    - layout.title_padding_y
    - layout.title_height
    - layout.author_padding_y
    - layout.author_size / 2
    - layout.author_name_size / 2,
  width = author_name_width,
  height = layout.author_name_size,
  radius = layout.author_name_size / 2,
})

-- フォローボタン
table.insert(rects, {
  x = layout.padding_x + layout.author_size + layout.author_padding_x + author_name_width + layout.author_padding_x,
  y = layout.height
    - layout.footer_height
    - layout.comment_padding_y
    - layout.comment_height
    - layout.tag_padding_y
    - layout.tag_height
    - layout.title_padding_y
    - layout.title_height
    - layout.author_padding_y
    - layout.author_size,
  width = layout.follow_width,
  height = layout.author_size,
  radius = layout.author_size / 2,
})

if show_forward then
  -- ピン留め動画
  table.insert(rects, {
    x = layout.padding_x,
    y = layout.height
      - layout.footer_height
      - layout.comment_padding_y
      - layout.comment_height
      - layout.tag_padding_y
      - layout.tag_height
      - layout.title_padding_y
      - layout.title_height
      - layout.author_padding_y
      - layout.author_size
      - layout.forward_padding_y
      - layout.forward_height,
    width = layout.forward_width,
    height = layout.forward_height,
    radius = layout.forward_radius,
  })
end

-- ツールバー
table.insert(rects, {
  x = layout.padding_x,
  y = layout.toolbar_padding_y,
  width = layout.toolbar_size,
  height = layout.toolbar_size,
  radius = layout.toolbar_size / 2,
})
for i = 0, 2 do
  table.insert(rects, {
    x = layout.width - layout.padding_x - layout.toolbar_size - (layout.toolbar_size + layout.toolbar_gap) * i,
    y = layout.toolbar_padding_y,
    width = layout.toolbar_size,
    height = layout.toolbar_size,
    radius = layout.toolbar_size / 2,
  })
end

obj.setoption("drawtarget", "tempbuffer", layout.width + side_line_width * 2, layout.height)
obj.clearbuffer("tempbuffer", color)

-- 画面分の消去
obj.setoption("blend", "alpha_sub")
obj.load("figure", "四角形", color, 100)
obj.effect(
  "リサイズ",
  "X",
  layout.width - layout.screen_radius * 2,
  "Y",
  layout.height,
  "ピクセル数でサイズ指定",
  1
)
obj.draw(0, 0)
obj.effect(
  "リサイズ",
  "X",
  layout.width,
  "Y",
  layout.height - layout.screen_radius * 2,
  "ピクセル数でサイズ指定",
  1
)
obj.draw(0, 0)
obj.load("figure", "円", color, layout.screen_radius * 2)
obj.draw(-layout.width / 2 + layout.screen_radius, -layout.height / 2 + layout.screen_radius)
obj.draw(layout.width / 2 - layout.screen_radius, -layout.height / 2 + layout.screen_radius)
obj.draw(-layout.width / 2 + layout.screen_radius, layout.height / 2 - layout.screen_radius)
obj.draw(layout.width / 2 - layout.screen_radius, layout.height / 2 - layout.screen_radius)

obj.setoption("blend", "none")

for _, rect in ipairs(rects) do
  if rect.radius > 0 then
    obj.load("figure", "四角形", color, 100)
    obj.effect(
      "リサイズ",
      "X",
      rect.width - rect.radius * 2,
      "Y",
      rect.height,
      "ピクセル数でサイズ指定",
      1
    )
    obj.draw(rect.x + rect.width / 2 - layout.width / 2, rect.y + rect.height / 2 - layout.height / 2)
    obj.effect(
      "リサイズ",
      "X",
      rect.width,
      "Y",
      rect.height - rect.radius * 2,
      "ピクセル数でサイズ指定",
      1
    )
    obj.draw(rect.x + rect.width / 2 - layout.width / 2, rect.y + rect.height / 2 - layout.height / 2)
    obj.load("figure", "円", color, rect.radius * 2)
    obj.draw(rect.x + rect.radius - layout.width / 2, rect.y + rect.radius - layout.height / 2)
    obj.draw(rect.x + rect.width - rect.radius - layout.width / 2, rect.y + rect.radius - layout.height / 2)
    obj.draw(rect.x + rect.radius - layout.width / 2, rect.y + rect.height - rect.radius - layout.height / 2)
    obj.draw(
      rect.x + rect.width - rect.radius - layout.width / 2,
      rect.y + rect.height - rect.radius - layout.height / 2
    )
  else
    obj.load("figure", "四角形", color, 100)
    obj.effect("リサイズ", "X", rect.width, "Y", rect.height, "ピクセル数でサイズ指定", 1)
    obj.draw(rect.x + rect.width / 2 - layout.width / 2, rect.y + rect.height / 2 - layout.height / 2)
  end
end

obj.setoption("drawtarget", "framebuffer")
obj.load("tempbuffer")
local screen_w, screen_h = obj.screen_w, obj.screen_h
local scale = screen_h / (layout.height - layout.footer_height)
obj.effect("リサイズ", "拡大率", scale * 100)
obj.cy = -(layout.footer_height * scale) / 2
