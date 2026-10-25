# Dokaben.anm2

Port of [Dokaben effect](https://www.nicovideo.jp/watch/sm30220788).

## Parameters

- Playback speed: Animation speed (%). 100 is normal speed; 0 disables the animation.
- Auto fall: Repeat the rising and falling animation. Disable to hold the raised position.
- Upright duration: Wait before falling, in frames. Used only when Auto fall is enabled; 0 starts falling immediately. Playback speed also affects the actual wait duration.
- Y offset: Adjust the vertical reference position of the deformation.
- Frame dropping: Advance the animation in steps for a choppy motion.

## PI

- `speed`: Playback speed (number, %)
- `auto_fall`: Auto fall (`true` / `false`)
- `upright`: Upright duration (number, non-negative frame count)
- `y_offset`: Y offset (number)
- `drop_frame`: Frame dropping (`true` / `false`)
- `divisions_override`: Horizontal subdivision count (integer, at least 1). Defaults to 1–32 subdivisions based on image width. Higher values reduce visible deformation artifacts but increase rendering cost.

# Changelog

## v1.0（2026/10/25）

- Initial release
