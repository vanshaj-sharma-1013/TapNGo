# Tap N Go: Design (revised)

## Core loop
- Hold anywhere on screen to move **up** the portrait track. Release to freeze instantly.
- Two steering buttons sit in the bottom corners. They move the player left / right at any time, even while frozen, and work together with a second finger holding "forward". (Desktop: click = forward, A/D or arrows = steer, W/Up/Space = forward.)
- Hazards hurt on any overlap, moving or frozen. Freezing is for timing gaps, not for hiding.
- Reach the glowing finish line at the top to clear the level.
- Fixed 720x1280 portrait viewport. Single-finger input only.

## Track shape: straight lanes first
- Levels are a straight vertical lane. No curves, no path-following, no wall collisions.
- All difficulty comes from hazards, which sweep left/right across the lane.
- Hazards are deterministic (fixed speed and pattern, no random timing) so every death is the player's fault.
- Winding tracks are a post-launch idea, only if the straight-lane loop proves fun.

## Progression
- Level 1: eight sweeping bars, all one size (256px). Teaches hold = move, release = stop.
- Levels 2-5: sweeping bars in four sizes (96 / 160 / 208 / 256px), more bars and more speed each level.
- Levels 6-10: same bars plus 2 fire and 2 ice patches per level (rules below).
- Levels 8-10: some bars (3, 4, 5) stop sweeping and become fixed purple walls at the left, middle or right of the lane, so the player must steer around them.
- Length grows by about 300px per level: level 1 is the shortest (3600px), level 10 about 6300px. Bars get slightly closer together as levels get longer.
- Levels 11-15 (not built): rotating lasers, pendulums. Players pulse their taps.
- Level data lives in `level_data.gd`. Level 1 is hand-written; 2-10 are built from a fixed seed, so they are identical every run.
- Fairness rule: a bar must leave the player's lane clear for at least 0.5s each time it swings out (measured for a player standing in the middle of the lane). `level_data.gd` caps bar speed by width to guarantee it (the 256px bar is the slowest, 320 px/s), and `campaign.gd` warns in the Output panel if a generated bar ever drops below it. Level 1 is hand-tuned and exempt.

### Fire and ice patches (levels 6-10)
- Fixed and always on. Each patch is 300px wide in the 720px lane, sitting at the left, middle or right (fixed per level, picked from the level's seed), so the player steers around it with the side buttons.
- **Fire:** touching an active patch starts a 10-second burn that kills the player when it runs out. Touching an active ice patch puts the fire out. Reaching the finish line first also saves you.
- **Ice:** puts out a burn, freezes the player in place for 1s, then movement speed (forward and sideways) is 0.8x for 5s. The freeze and slow can't be re-applied while frozen or slowed, but the fire-extinguishing always works.
- Reviving clears all effects.
- Levels 16+: narrow corridors, collapsing floors, moving checkpoints.
- Consider a scored endless mode built from the same hazard patterns. It is cheaper than hand-making 15+ levels and gives a high-score hook.

## Checkpoints and revive
- Every level has checkpoints at roughly every third of its length.
- On a crash, the player gets **one revive per run**, offered every time, not only near the end of a hard level.
- Revive = watch a rewarded ad, respawn at the last checkpoint with ~2s of invulnerability.
- Declining, or having already used the revive, restarts the level instantly (under 1 second).

## Ads (rewarded-first)
- **Rewarded ad:** the revive above, and nothing else. Always opt-in.
- **Interstitial:** at most one every 4-5 cleared levels, only on the level-clear screen, never straight after a death, none before level 3.
- **No banner ads.** The screen is small and the controls are "tap anywhere", so banners cause accidental taps and policy penalties.
- Open question: if the game could appeal to under-13s, Google Play's Families policy limits ad networks and formats. Decide the target audience before configuring ads.

## Look and feel
- Dark neon: charcoal/black background, glowing cyan / hot pink / electric lime trails. Use a WorldEnvironment with glow.
- Juice: fading player trail, screen shake and vibration on crash, short sounds for start/stop/crash.
- Store the best scores and level progress locally.

## Open items
- Built (verify in the editor): menu with level select (levels 1-10, `campaign.gd`; all unlocked while `UNLOCK_ALL_LEVELS` is true in `game_data.gd`), endless mode (`endless.gd`), finish line, checkpoints, revive, camera bounds, deterministic hazards, neon glow (`neon_env.tres`), trail, screen shake, vibration, sounds (`sfx/`), local save (`game_data.gd`), portrait + `keep_width` stretch.
- Ads: `ads.gd` holds the rewarded-ad call and the interstitial rule (none before level 3, then one per 4 cleared levels). Both are stubs; the rewarded one grants the revive immediately. Install an ad plugin and fill in `_show_rewarded()` / `_show_interstitial()`.
- Endless mode has no interstitials (the design only allows them on a level-clear screen).
- Not built: more than one hand-built level / level select, a pause button, settings (mute, vibration off), tuning the difficulty ramp.
- Android export needs the VIBRATE permission ticked in the export preset, or vibration does nothing.
- Android export (templates, JDK, SDK, keystore, AAB) and Play Store closed-testing requirements: check current rules early.
