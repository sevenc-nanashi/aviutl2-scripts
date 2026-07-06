# Pixel Art Transform.anm2

Scales and rotates pixel art.

Unlike the standard drawing behavior, this keeps pixel art looking pixelated while transforming it.\
When advanced interpolation is enabled, lines are interpolated more cleanly.\
(Advanced interpolation is still experimental. Its behavior may change in future versions.)

## Pixel Snap

When pixel art is transformed, the transformed image can become blurry if its position does not align to the pixel grid.\
(For example, when the top-left position of the image from the top-left of the scene is a decimal value such as (1.3, 2.7).)\
Enabling pixel snap adjusts the transformed image so it aligns to the pixel grid and prevents blur.

> [!TIP]
> sigma-axis's aviutl2_script_PixelSnap_S performs similar behavior: <https://github.com/sigma-axis/aviutl2_script_PixelSnap_S>

### Modes

- Move Center: Adjusts the center point so the top-left of the image aligns to the pixel grid.
- Move Drawing: Adjusts the drawing position so the top-left of the image aligns to the pixel grid.
- Sampler: Changes AviUtl2's pixel interpolation mode.\
  Adding another effect after this effect may disable pixel snap.
- Off: Does not apply pixel snap.

## Advanced Interpolation

When enabled, pixel art lines are interpolated so they are drawn over fills, making lines less likely to disappear.\
It also interpolates diagonal lines more cleanly when scaling up.\
This feature is based on cleanEdge. See this page for details about cleanEdge: <https://torcado.com/cleanEdge/>

### Parameters

- Highest Color: The color used to determine line overwrite priority. For example, `#ffffff` prioritizes brighter colors. If the pixel art has an outline, setting the outline color can produce cleaner results.\
  Corresponds to cleanEdge's Highest Color.
- Line Width: Specifies the line width. This controls how many cells a pixel expands across. Use a value around 0.707 to clean up 45-degree lines.\
  Corresponds to cleanEdge's Line Width.
- Slope Interpolation: Specifies which slopes are interpolated when scaling up.\
  Corresponds to cleanEdge's Slopes.
  - 1:1: Interpolates only 45-degree lines.
  - 1:1 + 1:2: Interpolates 45-degree and 26.565-degree (1:2 slope) lines.
  - 1:1 + 1:2 (Cleanup): Interpolates 45-degree and 26.565-degree (1:2 slope) lines, and further cleans up 1:2 lines.
- Similar Threshold: Specifies how similar colors must be to be treated as the same color during slope interpolation.\
  Higher values make transitions between similar colors smoother, but too high a value can cause artifacts.\
  Set this as low as possible.\
  Corresponds to cleanEdge's Similar Threshold.

## PI

- `scale`: Scale factor (1.0 = original size)
- `scale_x`: X scale factor (1.0 = original size)
- `scale_y`: Y scale factor (1.0 = original size)
- `center_x`: Center X in pixels
- `center_y`: Center Y in pixels
- `angle_deg`: Rotation in degrees
- `enable_cleanedge`: Advanced interpolation
- `highest_color`: Highest color
- `line_width`: Line width
- `slopes`: Slope interpolation (0 = "1:1 only", 1 = "1:1 + 1:2", 2 = "1:1 + 1:2 (cleanup)")
- `similar_threshold`: Similar threshold
- `alpha_grid`: Alpha grid
- `pixelsnap`: Pixel snap (1 = move center, 2 = move drawing, 3 = sampler, 0 = off)
- `debug`: Debug mode

# Changelog

## v3.4 (2026/7/6)

- Added the English language file

## v3.3 (2026/06/20)

- Added parameters for changing the X and Y scale factors at the same time

## v3.2 (2025/12/13)

- Completely resolved jitter during rotation

## v3.1 (2025/12/13) <!-- commit-override: a2445e8 -->

- Added pixel snap

## v3.0 (2025/12/12) <!-- commit-override: 5fcc2a7 -->

- Added a cleanEdge-based advanced interpolation option

## v2.1 (2025/12/11) <!-- commit-override: d31c227 -->

- Fixed pixel jitter during rotation

## v2.0 (2025/12/10) <!-- commit-override: 4f848b5 -->

- Completely rewrote the algorithm to improve pixel preservation during rotation

## v1.0 (2025/12/4) <!-- commit-override: 4a8d9bb -->

- Initial release
