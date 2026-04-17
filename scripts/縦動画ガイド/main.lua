---$select:画面サイズ
---9:19.5（iPhone / Dynamic Island）=1
---9:16（iPhone）=2
---3:4（タブレット）=3
local aspect_ratio = 1

---$color:色
local color = 0xffffff

---$check:ピン留め動画
local show_pinned = true

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


---@class Layout
---@field width number
---@field height number
---@field footer_height number
---@field comment_padding_y number
---@field padding_x number
---@field comment_height number
---@field tag_padding_y number
---@field tag_height number
---@field tag_gap number
---@field like_padding_y number
---@field like_size number
---@field title_padding_y number
---@field title_height number
---@field author_padding_y number
---@field author_size number
---@field author_name_size number
---@field author_padding_x number
---@field follow_width number
---@field forward_width number
---@field forward_height number
---@field forward_padding_y number
---@field forward_radius number

---@type table<integer, Layout>
local layouts = {
  -- NOTE: iPhone 16, iOS 26
  [1] = {
    width = 1179,
    height = 2556,
    footer_height = 280,
    comment_padding_y = 32,
    padding_x = 44,
    comment_height = 100,
    tag_padding_y = 46,
    tag_height = 40,
    tag_gap = 32,
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
    forward_radius = 24
  },
}

---@type Layout
local layout = layouts[aspect_ratio] or layouts[1]

local rects = {}
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

if show_pinned then
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

if side_line_width > 0 then
  -- 左線
  table.insert(rects, {
    x = -side_line_width,
    y = 0,
    width = side_line_width,
    height = layout.height,
    radius = 0,
  })
  -- 右線
  table.insert(rects, {
    x = layout.width,
    y = 0,
    width = side_line_width,
    height = layout.height,
    radius = 0,
  })
end

obj.setoption("drawtarget", "tempbuffer", layout.width + side_line_width * 2, layout.height)
for _, rect in ipairs(rects) do
  if rect.radius > 0 then
    print(rect)
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
