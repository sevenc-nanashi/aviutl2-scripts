# Niconico Comment.anm2

Port of [コメント自演スクリプト+使用例.aviutl](http://www.nicovideo.jp/watch/sm32355460).

## PI

- `position`: Position (1 = ue, 2 = naka, 3 = shita)
- `size`: Size (1 = small, 2 = medium, 3 = big)
- `commands`: Commands (string)
- `screen`: Screen size source (1 = screen, 2 = anchors)
- `pos`: Screen bounds ({left, top, right, bottom})
- `duration`： Display duration (0 for automatic)
- `row`: Row (1–16)
- `show_frame`: Show yellow frame (true / false)
- `frame_add`: Frame width adjustment in pixels (0–100)
- `line`: Text lines (0–64, 0 for automatic detection)
- `clip`: Clip to screen (true / false)

# Changelog

## v1.2（2026/11/12）

- Added fallback for automatic line count calculation

## v1.1（2026/11/11）

- Added ability to adjust display duration

## v1.0（2026/11/11）

- Initial release
