# Character Animation Asset Pack — Godot 4.x

## Contents
- `idle/`: 4-frame idle loop
- `walk/`: 8-frame walk loop
- `run/`: 8-frame run loop
- `jump/`: 4-frame jump sequence
- `fall/`: 2-frame falling loop
- `hurt/`: 2-frame hurt reaction
- `death/`: 4-frame collapse sequence
- `sprite_sheets/contact_sheet.png`: inspection sheet (not an in-game sprite sheet)
- `sprite_sheets/animation_preview.gif`: quick motion preview
- `scripts/player_animation_controller.gd`: reusable CharacterBody2D controller

## Image specifications
- Each frame is an individual PNG with RGBA transparency.
- Canvas size: **160 × 220 px** for every frame.
- Crisp pixel edges; generated from a 40 × 55 logical-pixel drawing grid and enlarged 4× with nearest-neighbor scaling.
- Character feet and body are kept in a consistent canvas/anchor region for ordinary locomotion. Jump/fall/death intentionally change vertical position or pose.
- No floor, ground shadow, labels, or background is included in the individual frame PNGs.

## Import into Godot 4.x
1. Copy the `character_assets` folder into your Godot project's `res://` directory (or copy its contents into an equivalent folder).
2. Add an `AnimatedSprite2D` node to your player scene.
3. In the Inspector, set **Sprite Frames** → **New SpriteFrames**, then click the SpriteFrames resource to edit it.
4. Create animations named exactly: `idle`, `walk`, `run`, `jump`, `fall`, `hurt`, `death`.
5. For each animation, use **Add frames from a Sprite Sheet** only if you have a sheet. Here the PNGs are individual frames: use **Add frames from Files** and select that animation's files in numerical order. Multi-select `idle_00.png` through `idle_03.png`, etc.
6. Set animation FPS:
   - idle: **5 FPS**, looping on
   - walk: **10 FPS**, looping on
   - run: **14 FPS**, looping on
   - jump: **10 FPS**, looping off
   - fall: **8 FPS**, looping on
   - hurt: **8 FPS**, looping off
   - death: **7 FPS**, looping off
7. Ensure `AnimatedSprite2D` is positioned consistently (suggested local position `(0, -110)` if your player origin is at the feet). The PNG canvas is 160×220 and the feet sit near the lower part of the canvas; use the same node offset for every animation. Do not reposition the sprite node per frame.
8. If desired, enable texture filtering nearest in project settings or set the relevant CanvasItem texture filter to **Nearest** to preserve crisp edges. Use integer scaling where practical.

## Input Map for the sample controller
Add these actions in **Project → Project Settings → Input Map**:
- `move_left`: A and Left Arrow
- `move_right`: D and Right Arrow
- `jump`: Space
- `run`: Shift

Attach `scripts/player_animation_controller.gd` to a `CharacterBody2D` player with an `AnimatedSprite2D` child. Tune speed, gravity, and jump velocity for your game. This sample uses horizontal movement only; add vertical movement or platform-specific logic as needed.

## Alignment notes
All frames use the same 160×220 canvas and the same nominal centerline. Keep the `AnimatedSprite2D` node position fixed across state changes. For a foot-anchored character, place the node so the bottom of the canvas aligns with the player's foot/ground reference; fine-tune once in the editor. The death final frame intentionally lies down, so its visual silhouette changes by design.

## Commercial-use note
This pack was generated specifically for this request as original, simple pixel-art-style artwork. No third-party character or asset pack was intentionally copied. It is not legal advice, and no formal copyright, trademark, or provenance clearance has been performed. Review the assets before commercial release and retain your own records of their creation and any applicable tool/platform terms.
