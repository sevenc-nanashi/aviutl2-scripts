# 自演コメント.anm2

[コメント自演スクリプト+使用例.aviutl](http://www.nicovideo.jp/watch/sm32355460)の移植。

## PI

- `position`：位置（1 = ue、2 = naka、3 = shita）
- `size`：大きさ（1 = small、2 = medium、3 = big）
- `commands`：コマンド（文字列）
- `screen`：画面サイズ指定（1 = スクリーン、2 = アンカー）
- `pos`：画面サイズ（{左, 上, 右, 下}）
- `duration`：表示時間（0で自動）
- `row`：段（1～16）
- `show_frame`：黄枠表示（true / false）
- `frame_add`：枠線補正px（0～100）
- `line`：テキスト行数（0～64、0で自動）
- `clip`：画面内クリッピング（true / false）

# 更新履歴

## v1.2（2026/11/12）

- 行数の自動計算にフォールバックを追加

## v1.1（2026/11/11）

- 表示時間を調整できるように

## v1.0（2026/11/11）

- 初版リリース
