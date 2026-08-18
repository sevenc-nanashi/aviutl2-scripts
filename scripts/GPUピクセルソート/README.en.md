# GPU Pixel Sort.anm2

Performs pixel sorting on the GPU.

> [!WARNING]
> The size along the sort direction must be 4096 pixels or less.

## PI

- `direction`: Direction (0 = horizontal, 1 = vertical, 2 = horizontal (reversed), 3 = vertical (reversed))
- `threshold_min`: Minimum threshold
- `threshold_max`: Maximum threshold
- `visualize_sort_range`: Whether to preview the sort range
- `visualize_color`: Sort range preview color (`0xRRGGBB`)
- `visualize_fill_opacity`: Fill opacity for the sort range preview
- `visualize_source_opacity`: Source image opacity while previewing the sort range

# Changelog

## v1.3 (2026/8/18)

- Added Tips

## v1.2 (2026/7/6)

- Added the English language file

## v1.1 (2026/6/8)

- Ported the single-pass sorting process from BitonicPixelSorter v1.2.0
- Increased the maximum sort direction size to 4096 pixels
- Moved sort range preview processing entirely into the compute shader

## v1.0 (2026/6/7)

- Initial release
