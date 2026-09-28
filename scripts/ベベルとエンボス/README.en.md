# Bevel and Emboss.anm2

A script that creates bevel and emboss effects by adding highlights and shadows along edges.

## Acknowledgments

Ported to AviUtl2 based on gometh's "Bevel and Emboss" and Mr-Ojii's [Bevel_And_Emboss_M](https://github.com/Mr-Ojii/AviUtl-Bevel_And_Emboss_M-Script).

## Settings

- **Alpha threshold**: The opacity threshold used to detect edges. Range: 1–254; default: 206.
- **Width**: The bevel width. Emboss and pillow emboss use half the width on each side of the edge. Set to 0 to disable the effect.
- **Angle / Elevation**: The light direction and shading intensity. Shading disappears at an elevation of 90 degrees.
- **Shape**: Outer bevel, inner bevel, emboss, or pillow emboss.
- **Output**: Normal compositing, direct rendering, highlights only, or shadows only.
- **Blur**: Blurs the generated highlights and shadows.
- **Reference edge blur**: Blurs the image before extracting edges.
- **Highlights / Shadows**: Color, blending mode, and opacity. Opacity also applies to highlights-only and shadows-only output. Blending modes are used for normal compositing and direct rendering.
- **Background color**: Used for normal compositing with outer bevel, emboss, and pillow emboss.

## PI

- `threshold`: Alpha threshold (1–254)
- `width`: Width
- `angle`: Angle (degrees)
- `elevation`: Elevation (degrees)
- `shape`: Shape (0: outer bevel, 1: inner bevel, 2: emboss, 3: pillow emboss)
- `output`: Output (0: composite, 1: direct drawing, 2: highlights only, 3: shadows only)
- `blur`: Blur
- `preblur`: Reference edge blur
- `highlight_color`: Highlight color (0xRRGGBB)
- `highlight_blend`: Highlight blending mode (0–12, matching the menu)
- `highlight_opacity`: Highlight opacity (%)
- `shadow_color`: Shadow color (0xRRGGBB)
- `shadow_blend`: Shadow blending mode (0–12, matching the menu)
- `shadow_opacity`: Shadow opacity (%)
- `background_color`: Background color (0xRRGGBB)

# Changelog

## v1.0 (2026/9/28)

- Initial release
