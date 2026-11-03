# Sun-Baked Pyramids — Godot 4.x Assets

## Import
1. Unzip `pyramids_game_assets.zip` into your Godot project's `res://` directory.
2. Select the imported PNG textures and set **Filter** to **Nearest** (or set the project/default CanvasItem texture filter to Nearest).
3. Keep the supplied native pixel dimensions; scale in-game using integer-friendly scaling where possible.

## Bar assembly
- Pillar: place `pillars/pillar_left.png`, repeat `pillars/pillar_mid.png` as needed, then `pillars/pillar_right.png`.
- Scarab blade: use the same left–mid–right assembly pattern from `scarabs/`.
- Fixed wall: assemble `walls/wall_left.png`, repeated `walls/wall_mid.png`, and `walls/wall_right.png`.
- The mid pieces are intended to repeat horizontally. Check joins visually in the target scene before release.

## Hazards
- `hazards/quicksand.png` is a static transparent floor patch.
- `trapdoor_on.png` and `trapdoor_off.png` are aligned state variants; swap the texture to change state. Both are intended to repeat horizontally.

## Ground and lane edges
- `environment/ground_tile.png` is designed to repeat horizontally and vertically as a floor texture.
- `environment/edge_left.png` and `edge_right.png` are vertical lane borders. Repeat them vertically; the right edge is the mirrored counterpart.
- Use a `TextureRect` with **Tile** enabled or a `Sprite2D`/custom draw path that repeats the texture.

## Level objects
- `level_objects/finish_gate.png` is a wide transparent gate overlay.
- `checkpoint_off.png` and `checkpoint_on.png` share dimensions and alignment; swap textures for inactive/active states.

## Notes
These are original procedural pixel-art assets created for this request. They are a first-pass game-art pack; inspect all joins, collision footprints, and visual readability at your actual in-game scale before commercial release.
