# Targeted Scale.anm2

Scales an object to a target pixel size while preserving its aspect ratio.

## Modes

- Cover: Scales the object so the specified area is filled. (Equivalent to CSS `cover`.)
- Contain: Scales the object so it fits inside the specified area. (Equivalent to CSS `contain`.)
- Width: Scales the object so its width becomes the specified number of pixels.
- Height: Scales the object so its height becomes the specified number of pixels.

## PI

- `target_width`: Target width in pixels
- `target_height`: Target height in pixels
- `mode`: Mode (0 = cover, 1 = contain, 2 = width, 3 = height)
- `debug`: Debug mode

# Changelog

## v1.2 (2026/8/18)

- Added Tips

## v1.1 (2026/7/6)

- Added the English language file

## v1.0 (2026/01/25)

- Initial release
