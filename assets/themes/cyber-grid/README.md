# Cyber Grid — Godot 4.x Game Assets

## Import
1. Extract `cyber_game_assets.zip` into your project, or copy the `cyber_game_assets/` folder into your project.
2. In Godot's FileSystem dock, select the PNGs and set **Texture > Filter** to **Nearest** (or set the importing node/material texture filter to Nearest).
3. Keep the PNGs at their authored pixel dimensions. The game's 40% display scale should be applied in the scene/node transform, not by resampling the files.
4. All obstacle art except `environment/ground_tile.png` uses transparent RGBA pixels.

## Bar assembly
- Assemble each horizontal obstacle in this order: `*_left.png`, repeated `*_mid.png` segment(s), then `*_right.png`.
- Laser cap-to-mid interface columns are pixel-matched; wall cap-to-mid interface columns are pixel-matched.
- Use integer-position placement and avoid filtering other than Nearest. The mid pieces are authored for horizontal repetition.

## Ground and lane edges
- `environment/ground_tile.png` is a 720x720 opaque tile. Use a `TextureRect` with **Expand Mode** enabled and a `Texture2D` with repeat enabled, or a `Polygon2D`/shader with repeat sampling. Set texture repeat to enabled in the CanvasItem texture settings where applicable.
- `edge_left.png` and `edge_right.png` are transparent 200x720 rails. Place them along the lane boundaries and repeat vertically; the right rail is the horizontal mirror of the left.
- Keep the floor darker than the obstacles for readable collision silhouettes.

## Hazards and level objects
- `glitch.png` is a static transparent floor patch (750x300); align its collision shape to the visible patch pixels.
- `pulse_on.png` is deadly; `pulse_off.png` is the safe idle state. They share dimensions and alignment and repeat horizontally across the lane.
- `finish_gate.png` is a transparent arch; its central opening and outside region are transparent.
- `checkpoint_off.png` and `checkpoint_on.png` share a 1800x160 canvas and aligned gantry structure.

## Suggested Godot settings
- Texture Filter: **Nearest**
- Compression: Lossless for crisp pixel art
- Mipmaps: Off
- Avoid fractional scaling/positions when possible to prevent uneven pixel widths.
