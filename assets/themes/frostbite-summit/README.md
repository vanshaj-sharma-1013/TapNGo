# Frostbite Summit — Godot 4.x Assets

## Import
1. Extract `frost_game_assets.zip` into your Godot project, or copy the `frost_game_assets/` folder into the project.
2. Select the PNGs in Godot and set **Texture Filter** to **Nearest**. Use Lossless compression and disable mipmaps for crisp pixel art.
3. Keep source dimensions unchanged. Apply the intended 40% scale in your scene/node transform rather than resampling PNGs.
4. All production art uses RGBA. `environment/ground_tile.png` is fully opaque.

## Frozen bar assembly
- Assemble left-to-right: `frozen_left.png`, one or more `frozen_mid.png` segments, then `frozen_right.png`.
- Place pieces at integer pixel coordinates. The cap/mid interface columns were compared pixel-for-pixel.
- Repeat the mid horizontally; its opposite edge columns are identical.

## Wall assembly
- Assemble `wall_left.png`, repeated `wall_mid.png` pieces, then `wall_right.png`.
- The cap/mid interface columns were compared pixel-for-pixel. The mid is edge-matched for horizontal tiling.

## Ground and cliff edges
- `environment/ground_tile.png` is a 720x720 opaque tile with matching opposite horizontal and vertical boundary pixels. Use a repeating `Texture2D`/`TextureRect` or a repeating polygon texture.
- Enable texture repeat where needed and set filtering to Nearest.
- `edge_left.png` and `edge_right.png` are transparent 200x720 cliff strips; the right strip is the horizontal mirror of the left. Repeat vertically along the lane boundaries.

## Hazards and level objects
- `hazards/frost_patch.png` is a static transparent floor patch; align its hitbox to the painted pixels.
- `hazards/debris.png` is a single transparent avalanche chunk.
- `level_objects/finish_gate.png` is a transparent ice arch with an open center.
- `checkpoint_off.png` and `checkpoint_on.png` share dimensions and alpha silhouette; use OFF for inactive and ON for active.

## Suggested import settings
- Texture Filter: **Nearest**
- Compression: **Lossless**
- Mipmaps: **Off**
- Avoid fractional positions/scales where possible to prevent uneven pixel widths.
